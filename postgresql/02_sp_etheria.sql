SET search_path TO etheria;

-- ------------------------------------------------------------
-- SP: Registro de log de carga
-- Cambios: agrega duracionms e idreferencia, pmensaje varchar en lugar de text
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etheria.sp_registrarlogcarga(
    pmodulo          VARCHAR,
    ptablaobjetivo   VARCHAR,
    ppaso            VARCHAR,
    pestado          VARCHAR,
    pfilasafectadas  INTEGER,
    pmensaje         VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO etheria.logcargaproceso(modulo, tablaobjetivo, paso, estado, filasafectadas, duracionms, idreferencia, mensaje)
    VALUES (pmodulo, ptablaobjetivo, ppaso, pestado, pfilasafectadas, NULL, NULL, pmensaje);
END;
$$;

-- ------------------------------------------------------------
-- SP: Registro de movimiento de inventario
-- Cambios:
--   - ptipomovimiento ahora es FK a tipomovimientoinventario, se pasa el codigo
--   - eliminado saldoresultante — no existe en la tabla, el saldo se calcula
--   - eliminado cantidaddisponible y estado — no existen en loteinventario
--   - eliminado UPDATE a loteinventario — es inmutable, patron de transacciones
--   - pobservacion varchar en lugar de text
--   - validacion de saldo ahora calcula desde movimientosinventario
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etheria.sp_registrarmovimientoinventario(
    pidloteinventario   BIGINT,
    pcodigotipo         VARCHAR,  -- codigo del tipomovimientoinventario: entrada, salida, ajuste
    porigenmovimiento   VARCHAR,
    pcantidad           NUMERIC,
    preferenciaexterna  VARCHAR,
    pobservacion        VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    vidtipomovimiento   BIGINT;
    vsaldoactual        NUMERIC(14,2);
BEGIN
    IF pcantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad del movimiento debe ser mayor que cero';
    END IF;

    -- Resolver FK de tipo movimiento
    SELECT idtipomovimiento INTO vidtipomovimiento
    FROM etheria.tipomovimientoinventario
    WHERE codigo = pcodigotipo;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tipo de movimiento invalido: %', pcodigotipo;
    END IF;

    -- Verificar que el lote existe
    IF NOT EXISTS (SELECT 1 FROM etheria.loteinventario WHERE idloteinventario = pidloteinventario) THEN
        RAISE EXCEPTION 'No existe el lote %', pidloteinventario;
    END IF;

    -- Calcular saldo actual desde movimientos
    SELECT COALESCE(
        SUM(CASE WHEN tm.codigo = 'salida' THEN -m.cantidad ELSE m.cantidad END), 0
    )
    INTO vsaldoactual
    FROM etheria.movimientosinventario m
    INNER JOIN etheria.tipomovimientoinventario tm ON tm.idtipomovimiento = m.idtipomovimiento
    WHERE m.idloteinventario = pidloteinventario;

    -- Validar stock suficiente para salidas
    IF pcodigotipo = 'salida' AND vsaldoactual < pcantidad THEN
        RAISE EXCEPTION 'No hay inventario suficiente en el lote %. Saldo actual: %', pidloteinventario, vsaldoactual;
    END IF;

    -- Insert como log — nunca update
    INSERT INTO etheria.movimientosinventario(
        idloteinventario,
        idtipomovimiento,
        origenmovimiento,
        cantidad,
        referenciaexterna,
        observacion,
        fechamovimiento
    )
    VALUES (
        pidloteinventario,
        vidtipomovimiento,
        porigenmovimiento,
        pcantidad,
        preferenciaexterna,
        pobservacion,
        now()
    );
END;
$$;

-- ------------------------------------------------------------
-- SP: Carga de catalogos base (moneda, pais)
-- Cambios:
--   - moneda: codigomoneda → codigoisomoneda, simbolomoneda → simbolo, activa → activo
--   - pais: codigomoneda+monedaoficial → idmoneda FK resuelto por subquery
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etheria.sp_cargarpaisesbase()
LANGUAGE plpgsql
AS $$
DECLARE
    vfilas INTEGER := 0;
BEGIN
    INSERT INTO etheria.moneda(codigoisomoneda, nombremoneda, simbolo)
    VALUES
        ('NIO', 'Cordoba nicaraguense', 'C$'),
        ('COP', 'Peso colombiano',      '$'),
        ('PEN', 'Sol peruano',          'S/'),
        ('CRC', 'Colon costarricense',  '₡'),
        ('MXN', 'Peso mexicano',        '$')
    ON CONFLICT (codigoisomoneda) DO UPDATE
    SET
        nombremoneda = EXCLUDED.nombremoneda,
        simbolo      = EXCLUDED.simbolo,
        activo       = true;

    INSERT INTO etheria.pais(codigopaisiso, nombrepais, idmoneda)
    SELECT datos.codigopaisiso, datos.nombrepais, m.idmoneda
    FROM (
        VALUES
            ('NI', 'Nicaragua',   'NIO'),
            ('CO', 'Colombia',    'COP'),
            ('PE', 'Peru',        'PEN'),
            ('CR', 'Costa Rica',  'CRC'),
            ('MX', 'Mexico',      'MXN')
    ) AS datos(codigopaisiso, nombrepais, codigoiso)
    INNER JOIN etheria.moneda m ON m.codigoisomoneda = datos.codigoiso
    ON CONFLICT (codigopaisiso) DO UPDATE
    SET
        nombrepais = EXCLUDED.nombrepais,
        idmoneda   = EXCLUDED.idmoneda,
        activo     = true;

    GET DIAGNOSTICS vfilas = ROW_COUNT;
    CALL etheria.sp_registrarlogcarga('etheria', 'moneda,pais', 'carga paises', 'ok', vfilas, 'carga base de paises completada');
EXCEPTION
    WHEN OTHERS THEN
        CALL etheria.sp_registrarlogcarga('etheria', 'moneda,pais', 'carga paises', 'error', NULL, SQLERRM);
        RAISE;
END;
$$;

-- ------------------------------------------------------------
-- SP: Carga de catalogos operativos
-- Cambios:
--   - categoria: descripcion ahora varchar(500)
--   - proveedor: paisorigen → idpais FK resuelto por join
--   - requisitolegal: asociado a idpais FK, sin descripcion text, agrega urldocumento
--   - nuevos catalogos: tipousoproducto, tipoatributoproducto, estadoimportacion,
--                       tipomovimientoinventario, tipocostoimportacion
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etheria.sp_cargarcatalogosbase()
LANGUAGE plpgsql
AS $$
DECLARE
    vfilas INTEGER := 0;
BEGIN
    -- Categorias
    INSERT INTO etheria.categoria(nombrecategoria, descripcion)
    VALUES
        ('aceites',   'Aceites esenciales y terapeuticos'),
        ('bebidas',   'Bebidas funcionales y naturales'),
        ('alimentos', 'Alimentos nutraceuticos premium'),
        ('cosmetica', 'Cosmetica dermatologica y capilar'),
        ('jaboneria', 'Jabones artesanales y terapeuticos')
    ON CONFLICT (nombrecategoria) DO UPDATE SET descripcion = EXCLUDED.descripcion;

    GET DIAGNOSTICS vfilas = ROW_COUNT;
    CALL etheria.sp_registrarlogcarga('etheria', 'categoria', 'carga categorias', 'ok', vfilas, 'catalogo categoria listo');

    -- Tipos de uso de producto
    INSERT INTO etheria.tipousoproducto(nombretipousobase, descripcion)
    VALUES
        ('ingesta',      'Productos para consumo oral'),
        ('piel',         'Productos de aplicacion cutanea'),
        ('capilar',      'Productos para cabello y cuero cabelludo'),
        ('aromaterapia', 'Productos para uso aromaterapeutico'),
        ('mixto',        'Productos de uso multiple')
    ON CONFLICT (nombretipousobase) DO UPDATE SET descripcion = EXCLUDED.descripcion, activo = true;

    GET DIAGNOSTICS vfilas = ROW_COUNT;
    CALL etheria.sp_registrarlogcarga('etheria', 'tipousoproducto', 'carga tipos uso', 'ok', vfilas, 'catalogo tipo uso listo');

    -- Tipos de atributo de producto
    INSERT INTO etheria.tipoatributoproducto(nombreatributo, unidadmedida)
    VALUES
        ('ingrediente',       NULL),
        ('beneficio',         NULL),
        ('contraindicacion',  NULL),
        ('presentacion',      NULL),
        ('intensidad',        NULL)
    ON CONFLICT (nombreatributo) DO UPDATE SET activo = true;

    GET DIAGNOSTICS vfilas = ROW_COUNT;
    CALL etheria.sp_registrarlogcarga('etheria', 'tipoatributoproducto', 'carga tipos atributo', 'ok', vfilas, 'catalogo tipo atributo listo');

    -- Proveedores con idpais FK
    INSERT INTO etheria.proveedor(nombreproveedor, idpais, correocontacto, telefonocontacto)
    SELECT datos.nombreproveedor, p.idpais, datos.correo, datos.telefono
    FROM (
        VALUES
            ('Andes Botanical Supply', 'PE', 'contacto@andesbotanical.com',  '+51-1-5550001'),
            ('Caribe Natural Traders', 'NI', 'ventas@caribenatural.com',     '+505-22220001'),
            ('Pacifica Organics',      'MX', 'trade@pacificaorganics.mx',    '+52-55-11110001'),
            ('Sierra Viva Extracts',   'CO', 'global@sierraviva.co',         '+57-1-4440001'),
            ('Tico Wellness Import',   'CR', 'info@ticowellness.cr',         '+506-22220001')
    ) AS datos(nombreproveedor, codigopais, correo, telefono)
    INNER JOIN etheria.pais p ON p.codigopaisiso = datos.codigopais
    ON CONFLICT (nombreproveedor) DO UPDATE SET activo = true;

    GET DIAGNOSTICS vfilas = ROW_COUNT;
    CALL etheria.sp_registrarlogcarga('etheria', 'proveedor', 'carga proveedores', 'ok', vfilas, 'catalogo proveedor listo');

    -- Estados de importacion
    INSERT INTO etheria.estadoimportacion(codigo, descripcion)
    VALUES
        ('pedido',   'Pedido generado al proveedor'),
        ('transito', 'Mercaderia en transito'),
        ('recibido', 'Mercaderia recibida en hub'),
        ('cerrado',  'Importacion cerrada y liquidada')
    ON CONFLICT (codigo) DO UPDATE SET descripcion = EXCLUDED.descripcion, activo = true;

    GET DIAGNOSTICS vfilas = ROW_COUNT;
    CALL etheria.sp_registrarlogcarga('etheria', 'estadoimportacion', 'carga estados importacion', 'ok', vfilas, 'catalogo estado importacion listo');

    -- Tipos de movimiento de inventario
    INSERT INTO etheria.tipomovimientoinventario(codigo, descripcion)
    VALUES
        ('entrada', 'Entrada de mercaderia al inventario'),
        ('salida',  'Salida de mercaderia del inventario'),
        ('ajuste',  'Ajuste manual de inventario')
    ON CONFLICT (codigo) DO UPDATE SET descripcion = EXCLUDED.descripcion, activo = true;

    GET DIAGNOSTICS vfilas = ROW_COUNT;
    CALL etheria.sp_registrarlogcarga('etheria', 'tipomovimientoinventario', 'carga tipos movimiento', 'ok', vfilas, 'catalogo tipo movimiento listo');

    -- Tipos de costo de importacion con vigencia
    INSERT INTO etheria.tipocostoimportacion(nombrecosto, descripcion, esporcentaje, valor, fechadesde)
    VALUES
        ('flete',           'Costo de flete internacional',         false, 250,  current_date),
        ('seguro',          'Seguro de carga internacional',        false, 80,   current_date),
        ('arancel',         'Arancel de ingreso',                   true,  0.13, current_date),
        ('agenciaaduanal',  'Honorarios agencia aduanal',           false, 120,  current_date),
        ('almacenaje',      'Costo de almacenaje en puerto',        false, 60,   current_date)
    ON CONFLICT (nombrecosto, fechadesde) DO UPDATE
    SET
        descripcion  = EXCLUDED.descripcion,
        esporcentaje = EXCLUDED.esporcentaje,
        valor        = EXCLUDED.valor,
        activo       = true;

    GET DIAGNOSTICS vfilas = ROW_COUNT;
    CALL etheria.sp_registrarlogcarga('etheria', 'tipocostoimportacion', 'carga tipos costo', 'ok', vfilas, 'catalogo tipo costo listo');

    -- Requisitos legales con idpais FK
    INSERT INTO etheria.requisitolegal(idpais, nombrerequisito, entidadreguladora, urldocumento, obligatorio)
    SELECT p.idpais, datos.nombrerequisito, datos.entidadreguladora, NULL, true
    FROM (
        VALUES
            ('NI', 'registro sanitario',      'MINSA Nicaragua'),
            ('NI', 'certificado origen',       'Aduana Nicaragua'),
            ('CO', 'registro sanitario',      'INVIMA'),
            ('CO', 'declaracion ingredientes', 'INVIMA'),
            ('PE', 'registro sanitario',      'DIGEMID'),
            ('PE', 'ficha tecnica',            'DIGEMID'),
            ('CR', 'registro sanitario',      'MINSA Costa Rica'),
            ('CR', 'etiquetado nutricional',   'MINSA Costa Rica'),
            ('MX', 'registro sanitario',      'COFEPRIS'),
            ('MX', 'declaracion ingredientes', 'COFEPRIS')
    ) AS datos(codigopais, nombrerequisito, entidadreguladora)
    INNER JOIN etheria.pais p ON p.codigopaisiso = datos.codigopais
    ON CONFLICT (idpais, nombrerequisito) DO UPDATE SET obligatorio = EXCLUDED.obligatorio, activo = true;

    GET DIAGNOSTICS vfilas = ROW_COUNT;
    CALL etheria.sp_registrarlogcarga('etheria', 'requisitolegal', 'carga requisitos', 'ok', vfilas, 'catalogo requisito legal listo');

    -- Codigos aduanales por pais y categoria (necesarios para importacion)
    INSERT INTO etheria.codigoaduanal(idpais, idcategoria, codigo, descripcion)
    SELECT p.idpais, c.idcategoria,
           'HS-' || p.codigopaisiso || '-' || UPPER(LEFT(c.nombrecategoria, 3)),
           'Codigo arancelario ' || c.nombrecategoria || ' en ' || p.nombrepais
    FROM etheria.pais p
    CROSS JOIN etheria.categoria c
    ON CONFLICT (idpais, idcategoria) DO UPDATE
    SET descripcion = EXCLUDED.descripcion, activo = true;

    GET DIAGNOSTICS vfilas = ROW_COUNT;
    CALL etheria.sp_registrarlogcarga('etheria', 'codigoaduanal', 'carga codigos aduanales', 'ok', vfilas, 'codigos aduanales cargados');

EXCEPTION
    WHEN OTHERS THEN
        CALL etheria.sp_registrarlogcarga('etheria', 'catalogos', 'carga catalogos', 'error', NULL, SQLERRM);
        RAISE;
END;
$$;

-- ------------------------------------------------------------
-- SP: Carga de productos base
-- Cambios:
--   - tipouso texto → idtipousobase FK resuelto por join
--   - eliminados ingredientebase, beneficiosalud, atributosjsonb
--   - atributos ahora se insertan en atributoproductobase
--   - productopais y requisitoproductopais eliminados
--   - configuracion regulatoria ahora es por categoria, no por producto
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etheria.sp_cargarproductosbase(pproductos INTEGER DEFAULT 100)
LANGUAGE plpgsql
AS $$
DECLARE
    i               INTEGER;
    vcategoria      BIGINT;
    vnombrecategoria VARCHAR(80);
    vcodigotipousobase VARCHAR(80);
    vidproducto     BIGINT;
    vidtipousobase  BIGINT;
    vfilas          INTEGER := 0;
BEGIN
    IF pproductos < 1 THEN
        RAISE EXCEPTION 'La cantidad de productos debe ser mayor que cero';
    END IF;

    FOR i IN 1..pproductos LOOP

        -- Resolver categoria por nombre, no por posicion
        vnombrecategoria := CASE ((i - 1) % 5)
            WHEN 0 THEN 'aceites'
            WHEN 1 THEN 'bebidas'
            WHEN 2 THEN 'alimentos'
            WHEN 3 THEN 'cosmetica'
            ELSE         'jaboneria'
        END;

        SELECT idcategoria INTO vcategoria
        FROM etheria.categoria
        WHERE nombrecategoria = vnombrecategoria;

        vcodigotipousobase := CASE vnombrecategoria
            WHEN 'aceites'    THEN 'aromaterapia'
            WHEN 'bebidas'    THEN 'ingesta'
            WHEN 'alimentos'  THEN 'ingesta'
            WHEN 'cosmetica'  THEN 'piel'
            ELSE 'mixto'
        END;

        SELECT idtipousobase INTO vidtipousobase
        FROM etheria.tipousoproducto
        WHERE nombretipousobase = vcodigotipousobase;

        INSERT INTO etheria.productobase(codigoproducto, nombreproducto, idcategoria, idtipousobase, unidadmedida)
        VALUES (
            'PRD' || LPAD(i::TEXT, 4, '0'),
            'Producto terapeutico ' || i,
            vcategoria,
            vidtipousobase,
            'unidad'
        )
        ON CONFLICT (codigoproducto) DO UPDATE
        SET
            nombreproducto = EXCLUDED.nombreproducto,
            idcategoria    = EXCLUDED.idcategoria,
            idtipousobase  = EXCLUDED.idtipousobase,
            activo         = true
        RETURNING idproductobase INTO vidproducto;

        IF vidproducto IS NULL THEN
            SELECT idproductobase INTO vidproducto
            FROM etheria.productobase
            WHERE codigoproducto = 'PRD' || LPAD(i::TEXT, 4, '0');
        END IF;

        -- Atributos variables del producto
        INSERT INTO etheria.atributoproductobase(idproductobase, idtipoatributo, valor)
        SELECT
            vidproducto,
            ta.idtipoatributo,
            datos.valor
        FROM (
            VALUES
                ('ingrediente',  'Extracto natural lote ' || i),
                ('beneficio',    'Apoyo integral al bienestar con formulacion premium ' || i),
                ('presentacion', 'unidad'),
                ('intensidad',   CASE WHEN i % 3 = 0 THEN 'alta' WHEN i % 3 = 1 THEN 'media' ELSE 'baja' END)
        ) AS datos(nombreatributo, valor)
        INNER JOIN etheria.tipoatributoproducto ta ON ta.nombreatributo = datos.nombreatributo
        ON CONFLICT (idproductobase, idtipoatributo) DO UPDATE SET valor = EXCLUDED.valor;

    END LOOP;

    SELECT COUNT(*) INTO vfilas FROM etheria.productobase WHERE codigoproducto LIKE 'PRD%';
    CALL etheria.sp_registrarlogcarga('etheria', 'productobase', 'carga productos', 'ok', vfilas, 'carga de productos base finalizada');
EXCEPTION
    WHEN OTHERS THEN
        CALL etheria.sp_registrarlogcarga('etheria', 'productobase', 'carga productos', 'error', NULL, SQLERRM);
        RAISE;
END;
$$;

-- ------------------------------------------------------------
-- SP: Carga de tipo de cambio demo
-- Cambios:
--   - idpais + tasausdmonedalocal → idmonedabase + idmonedadestino + tasa
--   - fechatasa → fechadesde + fechahasta (NULL = vigente)
--   - UK ahora es (idmonedabase, idmonedadestino, fechadesde)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etheria.sp_cargartipocambiodemo()
LANGUAGE plpgsql
AS $$
DECLARE
    vrec    RECORD;
    vusd    BIGINT;
    vfilas  INTEGER := 0;
BEGIN
    SELECT idmoneda INTO vusd FROM etheria.moneda WHERE codigoisomoneda = 'USD';

    IF NOT FOUND THEN
        INSERT INTO etheria.moneda(codigoisomoneda, nombremoneda, simbolo)
        VALUES ('USD', 'Dolar estadounidense', '$')
        RETURNING idmoneda INTO vusd;
    END IF;

    FOR vrec IN
        SELECT m.idmoneda, m.codigoisomoneda
        FROM etheria.moneda m
        WHERE m.codigoisomoneda IN ('NIO', 'COP', 'PEN', 'CRC', 'MXN')
    LOOP
        INSERT INTO etheria.tipocambio(idmonedabase, idmonedadestino, tasa, fuente, fechadesde, fechahasta)
        VALUES
            (vusd, vrec.idmoneda,
             CASE vrec.codigoisomoneda WHEN 'COP' THEN 3980 WHEN 'PEN' THEN 3.72 WHEN 'CRC' THEN 510 WHEN 'MXN' THEN 16.9 ELSE 36.5 END,
             'bcn_referencia', current_date - 2, current_date - 1),
            (vusd, vrec.idmoneda,
             CASE vrec.codigoisomoneda WHEN 'COP' THEN 4010 WHEN 'PEN' THEN 3.75 WHEN 'CRC' THEN 512 WHEN 'MXN' THEN 17.1 ELSE 36.7 END,
             'bcn_referencia', current_date - 1, current_date),
            (vusd, vrec.idmoneda,
             CASE vrec.codigoisomoneda WHEN 'COP' THEN 4000 WHEN 'PEN' THEN 3.74 WHEN 'CRC' THEN 511 WHEN 'MXN' THEN 17.0 ELSE 36.6 END,
             'bcn_referencia', current_date, NULL)  -- NULL = tasa vigente
        ON CONFLICT (idmonedabase, idmonedadestino, fechadesde) DO UPDATE
        SET tasa   = EXCLUDED.tasa,
            fuente = EXCLUDED.fuente,
            fechahasta = EXCLUDED.fechahasta;
    END LOOP;

    SELECT COUNT(*) INTO vfilas FROM etheria.tipocambio WHERE fechadesde >= current_date - 2;
    CALL etheria.sp_registrarlogcarga('etheria', 'tipocambio', 'carga tipo cambio', 'ok', vfilas, 'tipo de cambio actualizado');
EXCEPTION
    WHEN OTHERS THEN
        CALL etheria.sp_registrarlogcarga('etheria', 'tipocambio', 'carga tipo cambio', 'error', NULL, SQLERRM);
        RAISE;
END;
$$;

-- ------------------------------------------------------------
-- SP: Carga de importaciones demo
-- Cambios:
--   - codigoimportacion eliminado — idimportacion es el PK
--   - estadoimportacion texto → idestadoimportacion FK
--   - importaciondetalle: idproductobase → idloteinventario, agrega tipocambio y costos
--   - loteinventario: sin cantidaddisponible ni estado, asociado a importaciondetalle
--   - costosimportacion: tipocosto texto → idtipocosto FK, sin montousd
--   - movimientos: solo inserts via sp_registrarmovimientoinventario
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etheria.sp_cargarimportacionesdemo(pimportaciones INTEGER DEFAULT 20)
LANGUAGE plpgsql
AS $$
DECLARE
    i                   INTEGER;
    vidimportacion      BIGINT;
    vidproveedor        BIGINT;
    videstado           BIGINT;
    vidcodigoaduanal    BIGINT;
    vidtipocambio       BIGINT;
    vidlote             BIGINT;
    vidimportdet        BIGINT;
    vcantidadinicial    NUMERIC;
    vcodigolote         VARCHAR;
    vtasacambio         NUMERIC(14,6);
    vfilas              INTEGER := 0;
    vrec                RECORD;
BEGIN
    -- IDs de catalogos reutilizados
    SELECT idestadoimportacion INTO videstado
    FROM etheria.estadoimportacion WHERE codigo = 'recibido';

    FOR i IN 1..pimportaciones LOOP

        SELECT idproveedor INTO vidproveedor
        FROM etheria.proveedor
        ORDER BY idproveedor
        OFFSET ((i - 1) % 5) LIMIT 1;

        -- Codigo aduanal resuelto por pais del proveedor y primera categoria disponible
        SELECT ca.idcodigoaduanal INTO vidcodigoaduanal
        FROM etheria.codigoaduanal ca
        INNER JOIN etheria.proveedor pr ON pr.idpais = ca.idpais
        WHERE pr.idproveedor = vidproveedor
        LIMIT 1;

        -- Si no hay codigo aduanal aun, usar el primero disponible
        IF vidcodigoaduanal IS NULL THEN
            SELECT idcodigoaduanal INTO vidcodigoaduanal
            FROM etheria.codigoaduanal LIMIT 1;
        END IF;

        INSERT INTO etheria.importacion(idproveedor, idestadoimportacion, idcodigoaduanal, fechapedido, fechallegadacaribe, observaciones)
        VALUES (
            vidproveedor,
            videstado,
            vidcodigoaduanal,
            current_date - ((i * 3) || ' days')::INTERVAL,
            current_date - ((i * 2) || ' days')::INTERVAL,
            'Importacion demo para simulacion academica'
        )
        RETURNING idimportacion INTO vidimportacion;

        -- Tasa de cambio vigente para USD → moneda del pais del proveedor
        SELECT tc.idtipocambio, tc.tasa INTO vidtipocambio, vtasacambio
        FROM etheria.tipocambio tc
        INNER JOIN etheria.moneda mb ON mb.idmoneda = tc.idmonedabase AND mb.codigoisomoneda = 'USD'
        INNER JOIN etheria.pais p ON p.idmoneda = tc.idmonedadestino
        INNER JOIN etheria.proveedor pr ON pr.idpais = p.idpais AND pr.idproveedor = vidproveedor
        WHERE tc.fechahasta IS NULL
        LIMIT 1;

        -- Crear lotes y detalles de importacion
        FOR vrec IN
            SELECT pb.idproductobase, pb.codigoproducto
            FROM etheria.productobase pb
            WHERE pb.idproductobase BETWEEN ((i - 1) * 5 + 1) AND ((i - 1) * 5 + 5)
        LOOP
            vcodigolote := 'LTP' || LPAD(i::TEXT, 4, '0') || LPAD(vrec.idproductobase::TEXT, 4, '0');
            vcantidadinicial := 100 + (i * 2);

            -- Lote asociado al producto
            INSERT INTO etheria.loteinventario(codigolote, idproductobase, cantidadinicial, fechavencimiento)
            VALUES (
                vcodigolote,
                vrec.idproductobase,
                vcantidadinicial,
                current_date + INTERVAL '365 days'
            )
            ON CONFLICT (codigolote) DO NOTHING
            RETURNING idloteinventario INTO vidlote;

            IF vidlote IS NULL THEN
                SELECT idloteinventario INTO vidlote
                FROM etheria.loteinventario WHERE codigolote = vcodigolote;
            END IF;

            -- Detalle de importacion apuntando al lote
            INSERT INTO etheria.importaciondetalle(
                idimportacion,
                idloteinventario,
                idtipocambio,
                tasacambio,
                costounitariobase,
                subtotalbase,
                costounitariolocal,
                subtotallocal
            )
            VALUES (
                vidimportacion,
                vidlote,
                vidtipocambio,
                vtasacambio,
                8 + ((vrec.idproductobase % 7) * 0.85),
                vcantidadinicial * (8 + ((vrec.idproductobase % 7) * 0.85)),
                (8 + ((vrec.idproductobase % 7) * 0.85)) * vtasacambio,
                vcantidadinicial * ((8 + ((vrec.idproductobase % 7) * 0.85)) * vtasacambio)
            )
            ON CONFLICT (idimportacion, idloteinventario) DO NOTHING
            RETURNING idimportaciondetalle INTO vidimportdet;

            -- Movimiento de entrada inicial del lote
            IF NOT EXISTS (
                SELECT 1 FROM etheria.movimientosinventario m
                INNER JOIN etheria.tipomovimientoinventario tm ON tm.idtipomovimiento = m.idtipomovimiento
                WHERE m.idloteinventario = vidlote AND tm.codigo = 'entrada'
            ) THEN
                CALL etheria.sp_registrarmovimientoinventario(
                    vidlote,
                    'entrada',
                    'importacion',
                    vcantidadinicial,
                    vcodigolote,
                    'Entrada inicial por recepcion de importacion'
                );
            END IF;

        END LOOP;

        -- Costos de la importacion usando FK a tipocostoimportacion
        INSERT INTO etheria.costosimportacion(idimportacion, idtipocosto, idtipocambio, tasacambio, valorlocal)
        SELECT
            vidimportacion,
            tc.idtipocosto,
            vidtipocambio,
            vtasacambio,
            CASE tc.esporcentaje
                WHEN true  THEN tc.valor * 100 * vtasacambio  -- % aplicado sobre base referencial
                WHEN false THEN tc.valor * vtasacambio
            END
        FROM etheria.tipocostoimportacion tc
        WHERE tc.nombrecosto IN ('flete', 'seguro', 'arancel')
          AND tc.fechahasta IS NULL
        ON CONFLICT DO NOTHING;

    END LOOP;

    SELECT COUNT(*) INTO vfilas FROM etheria.importacion;
    CALL etheria.sp_registrarlogcarga('etheria', 'importacion', 'carga importaciones', 'ok', vfilas, 'importaciones demo generadas');
EXCEPTION
    WHEN OTHERS THEN
        CALL etheria.sp_registrarlogcarga('etheria', 'importacion', 'carga importaciones', 'error', NULL, SQLERRM);
        RAISE;
END;
$$;