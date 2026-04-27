set search_path = public;

create or replace procedure etheria.sp_registrarmovimientoinventario(
    pidloteinventario bigint,
    ptipomovimiento varchar,
    porigenmovimiento varchar,
    pcantidad numeric,
    preferenciaexterna varchar,
    pobservacion text
)
language plpgsql
as $$
declare
    vsaldoactual numeric(14,2);
    vsaldofinal numeric(14,2);
begin
    if pcantidad <= 0 then
        raise exception 'La cantidad del movimiento debe ser mayor que cero';
    end if;

    if ptipomovimiento not in ('entrada', 'salida', 'ajuste') then
        raise exception 'Tipo de movimiento invalido: %', ptipomovimiento;
    end if;

    select cantidaddisponible
    into vsaldoactual
    from etheria.loteinventario
    where idloteinventario = pidloteinventario
    for update;

    if not found then
        raise exception 'No existe el lote %', pidloteinventario;
    end if;

    if ptipomovimiento = 'salida' and vsaldoactual < pcantidad then
        raise exception 'No hay inventario suficiente en el lote %', pidloteinventario;
    end if;

    vsaldofinal := case
        when ptipomovimiento = 'salida' then vsaldoactual - pcantidad
        else vsaldoactual + pcantidad
    end;

    update etheria.loteinventario
    set cantidaddisponible = vsaldofinal,
        estado = case
            when vsaldofinal = 0 then 'agotado'
            when vsaldofinal < cantidadinicial then 'reservado'
            else 'disponible'
        end
    where idloteinventario = pidloteinventario;

    insert into etheria.movimientosinventario(
        idloteinventario,
        tipomovimiento,
        origenmovimiento,
        cantidad,
        referenciaexterna,
        observacion,
        saldoresultante
    )
    values (
        pidloteinventario,
        ptipomovimiento,
        porigenmovimiento,
        pcantidad,
        preferenciaexterna,
        pobservacion,
        vsaldofinal
    )
    on conflict (idloteinventario, tipomovimiento, referenciaexterna) do update
    set cantidad = excluded.cantidad,
        observacion = excluded.observacion,
        saldoresultante = excluded.saldoresultante,
        fechamovimiento = now();
end;
$$;

create or replace procedure etheria.sp_registrarlogcarga(
    pmodulo varchar,
    ptablaobjetivo varchar,
    ppaso varchar,
    pestado varchar,
    pfilasafectadas integer,
    pmensaje text
)
language plpgsql
as $$
begin
    insert into etheria.logcargaproceso (
        modulo,
        tablaobjetivo,
        paso,
        estado,
        filasafectadas,
        mensaje
    )
    values (
        pmodulo,
        ptablaobjetivo,
        ppaso,
        pestado,
        pfilasafectadas,
        pmensaje
    );
end;
$$;

create or replace procedure etheria.sp_cargarpaisesbase()
language plpgsql
as $$
declare
    vfilas integer := 0;
begin
    insert into etheria.moneda(codigomoneda, nombremoneda, simbolomoneda)
    values
        ('NIO', 'Cordoba nicaraguense', 'C$'),
        ('COP', 'Peso colombiano', '$'),
        ('PEN', 'Sol peruano', 'S/'),
        ('CRC', 'Colon costarricense', '₡'),
        ('MXN', 'Peso mexicano', '$')
    on conflict (codigomoneda) do update
    set
        nombremoneda = excluded.nombremoneda,
        simbolomoneda = excluded.simbolomoneda,
        activa = true;

    insert into etheria.pais(codigopaisiso, nombrepais, codigomoneda, monedaoficial)
    values
        ('NI', 'Nicaragua', 'NIO', 'Cordoba nicaraguense'),
        ('CO', 'Colombia', 'COP', 'Peso colombiano'),
        ('PE', 'Peru', 'PEN', 'Sol peruano'),
        ('CR', 'Costa Rica', 'CRC', 'Colon costarricense'),
        ('MX', 'Mexico', 'MXN', 'Peso mexicano')
    on conflict (codigopaisiso) do update
    set
        nombrepais = excluded.nombrepais,
        codigomoneda = excluded.codigomoneda,
        monedaoficial = excluded.monedaoficial,
        activo = true;

    get diagnostics vfilas = row_count;
    call etheria.sp_registrarlogcarga('etheria', 'pais', 'carga paises', 'ok', vfilas, 'carga base de paises completada');
exception
    when others then
        call etheria.sp_registrarlogcarga('etheria', 'pais', 'carga paises', 'error', null, sqlerrm);
        raise;
end;
$$;

create or replace procedure etheria.sp_cargarcatalogosbase()
language plpgsql
as $$
declare
    vfilas integer := 0;
begin
    insert into etheria.categoria(nombrecategoria, descripcion)
    values
        ('aceites', 'Aceites esenciales y terapeuticos'),
        ('bebidas', 'Bebidas funcionales y naturales'),
        ('alimentos', 'Alimentos nutraceuticos premium'),
        ('cosmetica', 'Cosmetica dermatologica y capilar'),
        ('jaboneria', 'Jabones artesanales y terapeuticos')
    on conflict (nombrecategoria) do update set descripcion = excluded.descripcion;

    get diagnostics vfilas = row_count;
    call etheria.sp_registrarlogcarga('etheria', 'categoria', 'carga categorias', 'ok', vfilas, 'catalogo categoria listo');

    insert into etheria.proveedor(nombreproveedor, paisorigen, correocontacto, telefonocontacto)
    values
        ('Andes Botanical Supply', 'Peru', 'contacto@andesbotanical.com', '+51-1-5550001'),
        ('Caribe Natural Traders', 'Nicaragua', 'ventas@caribenatural.com', '+505-22220001'),
        ('Pacifica Organics', 'Mexico', 'trade@pacificaorganics.mx', '+52-55-11110001'),
        ('Sierra Viva Extracts', 'Colombia', 'global@sierraviva.co', '+57-1-4440001'),
        ('Tico Wellness Import', 'Costa Rica', 'info@ticowellness.cr', '+506-22220001')
    on conflict (nombreproveedor, paisorigen) do update set activo = true;

    get diagnostics vfilas = row_count;
    call etheria.sp_registrarlogcarga('etheria', 'proveedor', 'carga proveedores', 'ok', vfilas, 'catalogo proveedor listo');

    insert into etheria.requisitolegal(nombrerequisito, entidadreguladora, descripcion, obligatorio)
    values
        ('registro sanitario', 'ministerio de salud', 'Registro sanitario vigente por pais', true),
        ('etiquetado nutricional', 'autoridad de consumo', 'Etiquetado en idioma local', true),
        ('declaracion ingredientes', 'ministerio de salud', 'Detalle completo de ingredientes', true),
        ('certificado origen', 'aduana nacional', 'Certificacion de origen de materia prima', true),
        ('ficha tecnica', 'autoridad sanitaria', 'Ficha tecnica con propiedades y contraindicaciones', true)
    on conflict (nombrerequisito, entidadreguladora) do update set obligatorio = excluded.obligatorio;

    get diagnostics vfilas = row_count;
    call etheria.sp_registrarlogcarga('etheria', 'requisitolegal', 'carga requisitos', 'ok', vfilas, 'catalogo requisito legal listo');
exception
    when others then
        call etheria.sp_registrarlogcarga('etheria', 'catalogos', 'carga catalogos', 'error', null, sqlerrm);
        raise;
end;
$$;

create or replace procedure etheria.sp_cargarproductosbase(pproductos integer default 100)
language plpgsql
as $$
declare
    i integer;
    vcategoria integer;
    vtipouso varchar(30);
    vidproducto bigint;
    vpais record;
    vfilas integer := 0;
begin
    if pproductos < 1 then
        raise exception 'La cantidad de productos debe ser mayor que cero';
    end if;

    for i in 1..pproductos loop
        vcategoria := ((i - 1) % 5) + 1;
        vtipouso := case
            when vcategoria = 1 then 'aromaterapia'
            when vcategoria = 2 then 'ingesta'
            when vcategoria = 3 then 'ingesta'
            when vcategoria = 4 then 'piel'
            else 'mixto'
        end;

        insert into etheria.productobase(
            codigoproducto,
            nombreproducto,
            idcategoria,
            tipouso,
            unidadmedida,
            ingredientebase,
            beneficiosalud,
            atributosjsonb
        )
        values (
            'PRD' || lpad(i::text, 4, '0'),
            'Producto terapeutico ' || i,
            vcategoria,
            vtipouso,
            'unidad',
            'Extracto natural lote ' || i,
            'Apoyo integral al bienestar con formulacion premium ' || i,
            jsonb_build_object(
                'presentacion', 'unidad',
                'origen', 'natural',
                'intensidad', case when i % 3 = 0 then 'alta' when i % 3 = 1 then 'media' else 'baja' end,
                'variacion', i
            )
        )
        on conflict (codigoproducto) do update
        set
            nombreproducto = excluded.nombreproducto,
            idcategoria = excluded.idcategoria,
            tipouso = excluded.tipouso,
            atributosjsonb = excluded.atributosjsonb,
            activo = true
        returning idproductobase into vidproducto;

        if vidproducto is null then
            select idproductobase into vidproducto
            from etheria.productobase
            where codigoproducto = 'PRD' || lpad(i::text, 4, '0');
        end if;

        for vpais in select idpais from etheria.pais where codigopaisiso in ('CO', 'PE', 'CR', 'MX', 'NI') loop
            insert into etheria.productopais(
                idproductobase,
                idpaisdestino,
                codigosanitario,
                requierepermiso,
                restricciones,
                fechavigencia,
                activo
            )
            values (
                vidproducto,
                vpais.idpais,
                'RS-' || vpais.idpais || '-' || lpad(i::text, 4, '0'),
                true,
                'Requiere control de temperatura y etiqueta local',
                current_date,
                true
            )
            on conflict (idproductobase, idpaisdestino) do update
            set
                codigosanitario = excluded.codigosanitario,
                requierepermiso = excluded.requierepermiso,
                restricciones = excluded.restricciones,
                activo = true;

            insert into etheria.requisitoproductopais(idproductopais, idrequisitolegal, detalleaplicacion)
            select pp.idproductopais, rl.idrequisitolegal, 'Aplica segun categoria y pais destino'
            from etheria.productopais pp
            cross join etheria.requisitolegal rl
            where pp.idproductobase = vidproducto
              and pp.idpaisdestino = vpais.idpais
              and rl.nombrerequisito in ('registro sanitario', 'declaracion ingredientes')
            on conflict (idproductopais, idrequisitolegal) do nothing;
        end loop;
    end loop;

    select count(*) into vfilas from etheria.productobase where codigoproducto like 'PRD%';
    call etheria.sp_registrarlogcarga('etheria', 'productobase', 'carga productos', 'ok', vfilas, 'carga de productos base finalizada');
exception
    when others then
        call etheria.sp_registrarlogcarga('etheria', 'productobase', 'carga productos', 'error', null, sqlerrm);
        raise;
end;
$$;

create or replace procedure etheria.sp_cargarimportacionesdemo(pimportaciones integer default 20)
language plpgsql
as $$
declare
    i integer;
    vidimportacion bigint;
    vidproveedor bigint;
    vfilas integer := 0;
begin
    for i in 1..pimportaciones loop
        select idproveedor into vidproveedor
        from etheria.proveedor
        order by idproveedor
        offset ((i - 1) % 5)
        limit 1;

        insert into etheria.importacion(codigoimportacion, idproveedor, estadoimportacion, fechapedido, fechallegadacaribe, observaciones)
        values (
            'IMP' || to_char(current_date, 'YYYYMM') || lpad(i::text, 4, '0'),
            vidproveedor,
            'recibido',
            current_date - ((i * 3) || ' days')::interval,
            current_date - ((i * 2) || ' days')::interval,
            'Importacion demo para simulacion academica'
        )
        on conflict (codigoimportacion) do update
        set
            idproveedor = excluded.idproveedor,
            estadoimportacion = excluded.estadoimportacion,
            fechallegadacaribe = excluded.fechallegadacaribe
        returning idimportacion into vidimportacion;

        insert into etheria.importaciondetalle(idimportacion, idproductobase, cantidadbulk, costounitariousd)
        select
            vidimportacion,
            pb.idproductobase,
            100 + (i * 2),
            8 + ((pb.idproductobase % 7) * 0.85)
        from etheria.productobase pb
        where pb.idproductobase between ((i - 1) * 5 + 1) and ((i - 1) * 5 + 5)
        on conflict (idimportacion, idproductobase) do update
        set
            cantidadbulk = excluded.cantidadbulk,
            costounitariousd = excluded.costounitariousd;

        insert into etheria.costosimportacion(idimportacion, tipocosto, tipovalor, valorreferencia, basecalculo, montousd, descripcion)
        values
            (vidimportacion, 'flete', 'monto', 250 + i * 4, 0, 250 + i * 4, 'Costo de flete internacional'),
            (vidimportacion, 'seguro', 'monto', 80 + i * 1.2, 0, 80 + i * 1.2, 'Seguro de carga internacional'),
            (vidimportacion, 'arancel', 'monto', 120 + i * 2.5, 0, 120 + i * 2.5, 'Arancel de ingreso')
        on conflict do nothing;
    end loop;

    insert into etheria.loteinventario(codigolote, idimportaciondetalle, cantidadinicial, cantidaddisponible, fechavencimiento, estado)
    select
        'LTP' || lpad(idet.idimportaciondetalle::text, 8, '0'),
        idet.idimportaciondetalle,
        idet.cantidadbulk,
            0,
        current_date + interval '365 days',
        'disponible'
    from etheria.importaciondetalle idet
    on conflict (codigolote) do update
        set estado = 'disponible';

    for vidimportacion in
        select li.idloteinventario
        from etheria.loteinventario li
        where not exists (
            select 1
            from etheria.movimientosinventario mi
            where mi.idloteinventario = li.idloteinventario
              and mi.tipomovimiento = 'entrada'
              and mi.referenciaexterna = li.codigolote
        )
    loop
        call etheria.sp_registrarmovimientoinventario(
            vidimportacion,
            'entrada',
            'importacion',
            (select cantidadinicial from etheria.loteinventario where idloteinventario = vidimportacion),
            (select codigolote from etheria.loteinventario where idloteinventario = vidimportacion),
            'Entrada inicial por recepcion de importacion'
        );
    end loop;

    select count(*) into vfilas from etheria.importacion;
    call etheria.sp_registrarlogcarga('etheria', 'importacion', 'carga importaciones', 'ok', vfilas, 'importaciones demo generadas');
exception
    when others then
        call etheria.sp_registrarlogcarga('etheria', 'importacion', 'carga importaciones', 'error', null, sqlerrm);
        raise;
end;
$$;

create or replace procedure etheria.sp_cargartipocambiodemo()
language plpgsql
as $$
declare
    vpais record;
    vfilas integer := 0;
begin
    for vpais in select idpais, codigopaisiso from etheria.pais loop
        insert into etheria.tipocambio(idpais, fechatasa, tasausdmonedalocal, fuente)
        values
            (vpais.idpais, current_date - 2, case vpais.codigopaisiso when 'CO' then 3980 when 'PE' then 3.72 when 'CR' then 510 when 'MX' then 16.9 else 36.5 end, 'bcn_referencia'),
            (vpais.idpais, current_date - 1, case vpais.codigopaisiso when 'CO' then 4010 when 'PE' then 3.75 when 'CR' then 512 when 'MX' then 17.1 else 36.7 end, 'bcn_referencia'),
            (vpais.idpais, current_date,     case vpais.codigopaisiso when 'CO' then 4000 when 'PE' then 3.74 when 'CR' then 511 when 'MX' then 17.0 else 36.6 end, 'bcn_referencia')
        on conflict (idpais, fechatasa) do update
        set
            tasausdmonedalocal = excluded.tasausdmonedalocal,
            fuente = excluded.fuente;
    end loop;

    select count(*) into vfilas from etheria.tipocambio where fechatasa between current_date - 2 and current_date;
    call etheria.sp_registrarlogcarga('etheria', 'tipocambio', 'carga tipo cambio', 'ok', vfilas, 'tipo de cambio actualizado');
exception
    when others then
        call etheria.sp_registrarlogcarga('etheria', 'tipocambio', 'carga tipo cambio', 'error', null, sqlerrm);
        raise;
end;
$$;
