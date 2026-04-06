use dynamicbrands;

delimiter $$

create procedure sp_registrarlogcarga(
    in pmodulo varchar(50),
    in ptablaobjetivo varchar(80),
    in ppaso varchar(120),
    in pestado varchar(20),
    in pfilasafectadas int,
    in pmensaje text
)
begin
    insert into logcargaproceso(modulo, tablaobjetivo, paso, estado, filasafectadas, mensaje)
    values (pmodulo, ptablaobjetivo, ppaso, pestado, pfilasafectadas, pmensaje);
end$$

create procedure sp_cargarpaisesbase()
begin
    declare exit handler for sqlexception
    begin
        rollback;
        call sp_registrarlogcarga('dynamicbrands', 'pais', 'carga paises', 'error', null, 'error durante carga de paises');
        resignal;
    end;

    start transaction;

    insert into pais(codigopaisiso, nombrepais, codigomoneda, monedaoficial)
    values
        ('NI', 'Nicaragua', 'NIO', 'Cordoba nicaraguense'),
        ('CO', 'Colombia', 'COP', 'Peso colombiano'),
        ('PE', 'Peru', 'PEN', 'Sol peruano'),
        ('CR', 'Costa Rica', 'CRC', 'Colon costarricense'),
        ('MX', 'Mexico', 'MXN', 'Peso mexicano')
    as nuevo
    on duplicate key update
        nombrepais = nuevo.nombrepais,
        codigomoneda = nuevo.codigomoneda,
        monedaoficial = nuevo.monedaoficial,
        activo = 1;

    call sp_registrarlogcarga('dynamicbrands', 'pais', 'carga paises', 'ok', row_count(), 'paises cargados correctamente');
    commit;
end$$

create procedure sp_cargarmarcasysitios()
begin
    declare exit handler for sqlexception
    begin
        rollback;
        call sp_registrarlogcarga('dynamicbrands', 'marcaia,sitioweb', 'carga marcas y sitios', 'error', null, 'error durante carga de marcas y sitios');
        resignal;
    end;

    start transaction;

    insert into marcaia(nombremarca, enfoqueprincipal, descripcionmarca, estado)
    values
        ('auraviva', 'bienestar integral', 'Marca con enfoque holistico y premium', 'activa'),
        ('nativaflux', 'energia natural', 'Marca orientada a rendimiento y vitalidad', 'activa'),
        ('dermaterra', 'piel sensible', 'Marca centrada en cuidado dermatologico', 'activa')
    as nuevo
    on duplicate key update
        enfoqueprincipal = nuevo.enfoqueprincipal,
        descripcionmarca = nuevo.descripcionmarca,
        estado = nuevo.estado;

    insert into sitioweb(codigositio, idmarcaia, idpais, dominioweb, idioma, monedaoperacion, estado, fechainicio, fechacierre)
    select
        datos.codigositio,
        m.idmarcaia,
        p.idpais,
        datos.dominioweb,
        'es',
        p.codigomoneda,
        'activo',
        current_date,
        null
    from (
        select 'sitioaura-ni' as codigositio, 'auraviva' as marca, 'NI' as pais, 'ni.auraviva.shop' as dominioweb union all
        select 'sitioaura-co', 'auraviva', 'CO', 'co.auraviva.shop' union all
        select 'sitioaura-pe', 'auraviva', 'PE', 'pe.auraviva.shop' union all
        select 'sitionativa-co', 'nativaflux', 'CO', 'co.nativaflux.shop' union all
        select 'sitionativa-mx', 'nativaflux', 'MX', 'mx.nativaflux.shop' union all
        select 'sitionativa-cr', 'nativaflux', 'CR', 'cr.nativaflux.shop' union all
        select 'sitioderma-pe', 'dermaterra', 'PE', 'pe.dermaterra.shop' union all
        select 'sitioderma-mx', 'dermaterra', 'MX', 'mx.dermaterra.shop' union all
        select 'sitioderma-ni', 'dermaterra', 'NI', 'ni.dermaterra.shop'
    ) datos
    inner join marcaia m on m.nombremarca = datos.marca
    inner join pais p on p.codigopaisiso = datos.pais
    on duplicate key update
        idmarcaia = values(idmarcaia),
        idpais = values(idpais),
        idioma = values(idioma),
        monedaoperacion = values(monedaoperacion),
        estado = values(estado),
        fechainicio = values(fechainicio),
        fechacierre = null;

    call sp_registrarlogcarga('dynamicbrands', 'marcaia,sitioweb', 'carga marcas y sitios', 'ok', row_count(), 'marcas y sitios cargados');
    commit;
end$$

create procedure sp_cargarclientesyordenesdemo(in pordenes int)
begin
    declare i int default 1;
    declare vidx int;
    declare vsitio bigint;
    declare vcliente bigint;
    declare vorden bigint;
    declare vcodigositio varchar(40);
    declare vcodigopais char(2);
    declare vcantidad decimal(14,2);
    declare vprecio decimal(16,4);

    declare exit handler for sqlexception
    begin
        rollback;
        call sp_registrarlogcarga('dynamicbrands', 'ordenventa', 'carga ordenes demo', 'error', null, 'error durante generacion de ordenes demo');
        resignal;
    end;

    start transaction;

    insert into courierexterno(nombrecourier, paisoperacion, nivelservicio, activo)
    values
        ('caribexpress', 'Nicaragua', 'estandar', 1),
        ('latamrapid', 'Colombia', 'premium', 1),
        ('andesdelivery', 'Peru', 'estandar', 1),
        ('mesopack', 'Mexico', 'premium', 1),
        ('ticocourier', 'Costa Rica', 'estandar', 1)
    as nuevo
    on duplicate key update
        nivelservicio = nuevo.nivelservicio,
        activo = 1;

    while i <= pordenes do
        set vidx = (i - 1) mod 9;

        select idsitioweb, codigositio into vsitio, vcodigositio
        from sitioweb
        order by idsitioweb
        limit vidx, 1;

        select p.codigopaisiso into vcodigopais
        from sitioweb s
        inner join pais p on p.idpais = s.idpais
        where s.idsitioweb = vsitio;

        insert into clientefinal(nombrecompleto, correo, telefono, direccionentrega, idpais)
        select
            concat('cliente demo ', i),
            concat('cliente', lpad(i, 4, '0'), '@correo.demo'),
            concat('+50', i),
            concat('direccion demo ', i),
            s.idpais
        from sitioweb s
        where s.idsitioweb = vsitio
        on duplicate key update
            nombrecompleto = values(nombrecompleto),
            telefono = values(telefono),
            direccionentrega = values(direccionentrega);

        select idclientefinal into vcliente
        from clientefinal
        where correo = concat('cliente', lpad(i, 4, '0'), '@correo.demo');

        set vcantidad = 1 + (i mod 4);
        set vprecio = 45 + ((i mod 10) * 3.5);

        insert into ordenventa(
            codigoordenventa,
            idsitioweb,
            idclientefinal,
            fechaorden,
            estadoorden,
            totalmonedalocal,
            totalimpuesto,
            costoshipping,
            permisosanitario,
            observaciones
        )
        values (
            concat('OV', date_format(current_date, '%Y%m'), lpad(i, 5, '0')),
            vsitio,
            vcliente,
            now() - interval (i mod 7) day,
            'entregada',
            round(vcantidad * vprecio, 4),
            round((vcantidad * vprecio) * 0.13, 4),
            round(6 + (i mod 5), 4),
            round(2 + (i mod 3), 4),
            concat('orden demo para sitio ', vcodigositio)
        )
        on duplicate key update
            estadoorden = 'entregada',
            totalmonedalocal = values(totalmonedalocal),
            totalimpuesto = values(totalimpuesto),
            costoshipping = values(costoshipping),
            permisosanitario = values(permisosanitario),
            observaciones = values(observaciones);

        select idordenventa into vorden
        from ordenventa
        where codigoordenventa = concat('OV', date_format(current_date, '%Y%m'), lpad(i, 5, '0'));

        insert into ordenventadetalle(idordenventa, codigoproductoetheria, nombreproductomarca, cantidad, preciounitariolocal, subtotal)
        values
            (vorden, concat('PRD', lpad(((i - 1) mod 100) + 1, 4, '0')), concat('producto marca ', i), vcantidad, vprecio, round(vcantidad * vprecio, 4)),
            (vorden, concat('PRD', lpad(((i + 17) mod 100) + 1, 4, '0')), concat('producto marca adicional ', i), 1, vprecio * 0.85, round(vprecio * 0.85, 4))
        on duplicate key update
            nombreproductomarca = values(nombreproductomarca),
            cantidad = values(cantidad),
            preciounitariolocal = values(preciounitariolocal),
            subtotal = values(subtotal);

        insert into despacho(
            idordenventa,
            idcourierexterno,
            codigoguia,
            fechasalida,
            fechallegadapais,
            fechaentrega,
            estadodespacho,
            costocourierlocal,
            observacion
        )
        select
            vorden,
            c.idcourierexterno,
            concat('GUIA', date_format(current_date, '%Y%m'), lpad(i, 6, '0')),
            now() - interval 4 day,
            now() - interval 2 day,
            now() - interval 1 day,
            'entregado',
            round(4 + (i mod 4), 4),
            concat('despacho entregado en pais ', vcodigopais)
        from courierexterno c
        where c.activo = 1
        order by c.idcourierexterno
        limit 1
        on duplicate key update
            estadodespacho = 'entregado',
            costocourierlocal = values(costocourierlocal),
            observacion = values(observacion);

        set i = i + 1;
    end while;

    call sp_registrarlogcarga('dynamicbrands', 'ordenventa,ordenventadetalle,despacho', 'carga ordenes demo', 'ok', pordenes, 'ordenes demo cargadas correctamente');
    commit;
end$$

delimiter ;
