USE dynamicbrands;

DELIMITER $$

-- ------------------------------------------------------------
-- SP: Registro de log de carga
-- Agrega duracionms e idreferencia alineados al nuevo esquema
-- ------------------------------------------------------------
CREATE PROCEDURE sp_registrarlogcarga(
    IN pmodulo        VARCHAR(50),
    IN ptablaobjetivo VARCHAR(80),
    IN ppaso          VARCHAR(120),
    IN pestado        VARCHAR(20),
    IN pfilasafectadas INT,
    IN pmensaje       VARCHAR(500)
)
BEGIN
    INSERT INTO logcargaproceso(modulo, tablaobjetivo, paso, estado, filasafectadas, duracionms, idreferencia, mensaje)
    VALUES (pmodulo, ptablaobjetivo, ppaso, pestado, pfilasafectadas, NULL, NULL, pmensaje);
END$$

-- ------------------------------------------------------------
-- SP: Carga de catálogos base (moneda, pais, idioma)
-- Cambios:
--   - moneda: columnas renombradas a codigoisomoneda/nombremoneda/simbolo
--   - pais: codigomoneda+monedaoficial reemplazados por idmoneda FK
--   - idioma: tabla nueva, se carga aqui como catalogo base
-- ------------------------------------------------------------
CREATE PROCEDURE sp_cargarpaisesbase()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL sp_registrarlogcarga('dynamicbrands', 'moneda,pais,idioma', 'carga catalogos base', 'error', NULL, 'error durante carga de catalogos base');
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Monedas
    INSERT INTO moneda(codigoisomoneda, nombremoneda, simbolo)
    VALUES
        ('NIO', 'Cordoba nicaraguense', 'C$'),
        ('COP', 'Peso colombiano',      '$'),
        ('PEN', 'Sol peruano',          'S/'),
        ('CRC', 'Colon costarricense',  '₡'),
        ('MXN', 'Peso mexicano',        '$')
    AS nuevo
    ON DUPLICATE KEY UPDATE
        nombremoneda = nuevo.nombremoneda,
        simbolo      = nuevo.simbolo,
        activo       = 1;

    -- Idiomas
    INSERT INTO idioma(codigoidioma, nombreidioma)
    VALUES
        ('es-NI', 'Español Nicaragua'),
        ('es-CO', 'Español Colombia'),
        ('es-PE', 'Español Peru'),
        ('es-CR', 'Español Costa Rica'),
        ('es-MX', 'Español Mexico')
    AS nuevo
    ON DUPLICATE KEY UPDATE
        nombreidioma = nuevo.nombreidioma,
        activo       = 1;

    -- Paises: FK a moneda en lugar de columnas de texto
    INSERT INTO pais(codigopaisiso, nombrepais, idmoneda)
    SELECT datos.codigopaisiso, datos.nombrepais, m.idmoneda
    FROM (
        SELECT 'NI' AS codigopaisiso, 'Nicaragua'    AS nombrepais, 'NIO' AS codigoiso UNION ALL
        SELECT 'CO',                  'Colombia',                   'COP'              UNION ALL
        SELECT 'PE',                  'Peru',                       'PEN'              UNION ALL
        SELECT 'CR',                  'Costa Rica',                 'CRC'              UNION ALL
        SELECT 'MX',                  'Mexico',                     'MXN'
    ) datos
    INNER JOIN moneda m ON m.codigoisomoneda = datos.codigoiso
    AS nuevo(codigopaisiso, nombrepais, idmoneda)
    ON DUPLICATE KEY UPDATE
        nombrepais = nuevo.nombrepais,
        idmoneda   = nuevo.idmoneda,
        activo     = 1;

    CALL sp_registrarlogcarga('dynamicbrands', 'moneda,pais,idioma', 'carga catalogos base', 'ok', ROW_COUNT(), 'catalogos base cargados correctamente');
    COMMIT;
END$$

-- ------------------------------------------------------------
-- SP: Carga de marcas, nivel servicio courier y sitios web
-- Cambios:
--   - marcaia: sin enfoqueprincipal ni descripcionmarca
--   - sitioweb: idmoneda FK, ididioma FK, urllogo, urlbrand
--               sin idioma texto, sin monedaoperacion texto, sin fechacierre
--   - nivelserviciocourier: tabla nueva, se carga aqui
-- ------------------------------------------------------------
CREATE PROCEDURE sp_cargarmarcasysitios()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL sp_registrarlogcarga('dynamicbrands', 'marcaia,sitioweb', 'carga marcas y sitios', 'error', NULL, 'error durante carga de marcas y sitios');
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Marcas (simplificadas, sin campos del sistema generador)
    INSERT INTO marcaia(nombremarca, estado)
    VALUES
        ('auraviva',   'activa'),
        ('nativaflux', 'activa'),
        ('dermaterra', 'activa')
    AS nuevo
    ON DUPLICATE KEY UPDATE
        estado = nuevo.estado;

    -- Niveles de servicio courier
    INSERT INTO nivelserviciocourier(nombrenivelservicio, descripcion)
    VALUES
        ('estandar', 'Entrega en 5 a 7 dias habiles'),
        ('premium',  'Entrega en 2 a 3 dias habiles'),
        ('express',  'Entrega en 24 horas')
    AS nuevo
    ON DUPLICATE KEY UPDATE
        descripcion = nuevo.descripcion,
        activo      = 1;

    -- Sitios web: idmoneda e ididioma por FK, urllogo y urlbrand como columnas
    INSERT INTO sitioweb(codigositio, idmarcaia, idpais, idmoneda, ididioma, dominioweb, urllogo, urlbrand, configjson, estado, fechainicio)
    SELECT
        datos.codigositio,
        m.idmarcaia,
        p.idpais,
        p.idmoneda,
        i.ididioma,
        datos.dominioweb,
        CONCAT('https://cdn.dynamicbrands.local/', m.nombremarca, '/logo.png'),
        CONCAT('https://cdn.dynamicbrands.local/', m.nombremarca, '/brand.png'),
        JSON_OBJECT('tema', 'premium-natural'),
        'activo',
        CURRENT_DATE
    FROM (
        SELECT 'sitioaura-ni'   AS codigositio, 'auraviva'   AS marca, 'NI' AS pais, 'ni.auraviva.shop'    AS dominioweb UNION ALL
        SELECT 'sitioaura-co',                   'auraviva',            'CO',         'co.auraviva.shop'               UNION ALL
        SELECT 'sitioaura-pe',                   'auraviva',            'PE',         'pe.auraviva.shop'               UNION ALL
        SELECT 'sitionativa-co',                 'nativaflux',          'CO',         'co.nativaflux.shop'             UNION ALL
        SELECT 'sitionativa-mx',                 'nativaflux',          'MX',         'mx.nativaflux.shop'             UNION ALL
        SELECT 'sitionativa-cr',                 'nativaflux',          'CR',         'cr.nativaflux.shop'             UNION ALL
        SELECT 'sitioderma-pe',                  'dermaterra',          'PE',         'pe.dermaterra.shop'             UNION ALL
        SELECT 'sitioderma-mx',                  'dermaterra',          'MX',         'mx.dermaterra.shop'             UNION ALL
        SELECT 'sitioderma-ni',                  'dermaterra',          'NI',         'ni.dermaterra.shop'
    ) datos
    INNER JOIN marcaia m ON m.nombremarca = datos.marca
    INNER JOIN pais    p ON p.codigopaisiso = datos.pais
    INNER JOIN idioma  i ON i.codigoidioma = CONCAT('es-', datos.pais)
    AS nuevo(codigositio, idmarcaia, idpais, idmoneda, ididioma, dominioweb, urllogo, urlbrand, configjson, estado, fechainicio)
    ON DUPLICATE KEY UPDATE
        idmarcaia   = nuevo.idmarcaia,
        idpais      = nuevo.idpais,
        idmoneda    = nuevo.idmoneda,
        ididioma    = nuevo.ididioma,
        urllogo     = nuevo.urllogo,
        urlbrand    = nuevo.urlbrand,
        configjson  = nuevo.configjson,
        estado      = nuevo.estado,
        fechainicio = nuevo.fechainicio;

    CALL sp_registrarlogcarga('dynamicbrands', 'marcaia,sitioweb', 'carga marcas y sitios', 'ok', ROW_COUNT(), 'marcas y sitios cargados');
    COMMIT;
END$$

-- ------------------------------------------------------------
-- SP: Carga de catalogos de estados y costos
-- Tablas nuevas: estadoorden, estadodespacho, tipocostoorden, tipoimpuesto
-- ------------------------------------------------------------
CREATE PROCEDURE sp_cargarcatalogosoperacion()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL sp_registrarlogcarga('dynamicbrands', 'estadoorden,estadodespacho,tipocostoorden,tipoimpuesto', 'carga catalogos operacion', 'error', NULL, 'error durante carga de catalogos operacion');
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO estadoorden(codigo, descripcion)
    VALUES
        ('creada',      'Orden registrada en el sistema'),
        ('pagada',      'Pago confirmado'),
        ('preparando',  'Orden en preparacion'),
        ('despachada',  'Orden enviada al courier'),
        ('entregada',   'Orden recibida por el cliente'),
        ('cancelada',   'Orden cancelada')
    AS nuevo
    ON DUPLICATE KEY UPDATE
        descripcion = nuevo.descripcion,
        activo      = 1;

    INSERT INTO estadodespacho(codigo, descripcion)
    VALUES
        ('saliohub',   'Salio del hub de distribucion'),
        ('enaduana',   'Retenido en aduana'),
        ('entransito', 'En transito hacia destino'),
        ('entregado',  'Entregado al destinatario'),
        ('incidencia', 'Incidencia reportada')
    AS nuevo
    ON DUPLICATE KEY UPDATE
        descripcion = nuevo.descripcion,
        activo      = 1;

    INSERT INTO tipocostoorden(nombrecosto, descripcion)
    VALUES
        ('shipping',          'Costo de envio internacional'),
        ('permisosanitario',  'Permiso sanitario por pais')
    AS nuevo
    ON DUPLICATE KEY UPDATE
        descripcion = nuevo.descripcion,
        activo      = 1;

    -- Impuestos por pais
    INSERT INTO tipoimpuesto(idpais, nombreimpuesto, porcentaje)
    SELECT p.idpais, datos.nombreimpuesto, datos.porcentaje
    FROM (
        SELECT 'NI' AS pais, 'IVA' AS nombreimpuesto, 0.1500 AS porcentaje UNION ALL
        SELECT 'CO',         'IVA',                   0.1900             UNION ALL
        SELECT 'PE',         'IGV',                   0.1800             UNION ALL
        SELECT 'CR',         'IVA',                   0.1300             UNION ALL
        SELECT 'MX',         'IVA',                   0.1600
    ) datos
    INNER JOIN pais p ON p.codigopaisiso = datos.pais
    AS nuevo(idpais, nombreimpuesto, porcentaje)
    ON DUPLICATE KEY UPDATE
        porcentaje = nuevo.porcentaje,
        activo     = 1;

    CALL sp_registrarlogcarga('dynamicbrands', 'estadoorden,estadodespacho,tipocostoorden,tipoimpuesto', 'carga catalogos operacion', 'ok', ROW_COUNT(), 'catalogos operacion cargados correctamente');
    COMMIT;
END$$

-- ------------------------------------------------------------
-- SP: Carga de clientes, productos y ordenes demo
-- Cambios:
--   - clientefinal: sin direccionentrega ni idpais
--   - direccioncliente: tabla nueva por cliente
--   - courierexterno: idpais FK, idnivelservicio FK
--   - ordenventa: idestadoorden FK, idmoneda FK, iddireccioncliente FK
--                 sin estadoorden texto, sin codigomoneda texto
--                 totalbruto/totalcostos/totalneto en lugar de campos sueltos
--   - costoorden: tabla hija para costos de la orden
--   - ordenventadetalle: idproductositio FK, idpreciohistorico FK
--                        sin codigoproductoetheria ni nombreproductomarca
--   - despacho: sin fechasalida/fechallegada/fechaentrega/estadodespacho
--   - trackingdespacho: reemplaza despachoseguimiento con idestadodespacho FK
-- ------------------------------------------------------------
CREATE PROCEDURE sp_cargarclientesyordenesdemo(IN pordenes INT)
BEGIN
    DECLARE i               INT DEFAULT 1;
    DECLARE vidx            INT;
    DECLARE vsitio          BIGINT;
    DECLARE vcliente        BIGINT;
    DECLARE vdireccion      BIGINT;
    DECLARE vorden          BIGINT;
    DECLARE vdespacho       BIGINT;
    DECLARE vproductositio1 BIGINT;
    DECLARE vproductositio2 BIGINT;
    DECLARE vprecio1        BIGINT;
    DECLARE vprecio2        BIGINT;
    DECLARE vcodigositio    VARCHAR(40);
    DECLARE vcodigopais     CHAR(2);
    DECLARE vidpais         BIGINT;
    DECLARE vidmoneda       BIGINT;
    DECLARE videstadoentregada BIGINT;
    DECLARE videstadodespacho  BIGINT;
    DECLARE vidcourier      BIGINT;
    DECLARE vidtiposhipping BIGINT;
    DECLARE vidtipopermiso  BIGINT;
    DECLARE vcantidad       DECIMAL(14,2);
    DECLARE vprecio         DECIMAL(16,4);
    DECLARE vbruto          DECIMAL(16,4);
    DECLARE vimpuesto       DECIMAL(16,4);
    DECLARE vcostoshipping  DECIMAL(16,4);
    DECLARE vcostopermiso   DECIMAL(16,4);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL sp_registrarlogcarga('dynamicbrands', 'ordenventa', 'carga ordenes demo', 'error', NULL, 'error durante generacion de ordenes demo');
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Couriers con FK a pais y nivelservicio
    INSERT INTO courierexterno(nombrecourier, idpais, idnivelservicio)
    SELECT datos.nombrecourier, p.idpais, n.idnivelservicio
    FROM (
        SELECT 'caribexpress'   AS nombrecourier, 'NI' AS pais, 'estandar' AS nivel UNION ALL
        SELECT 'latamrapid',                      'CO',         'premium'            UNION ALL
        SELECT 'andesdelivery',                   'PE',         'estandar'           UNION ALL
        SELECT 'mesopack',                        'MX',         'premium'            UNION ALL
        SELECT 'ticocourier',                     'CR',         'estandar'
    ) datos
    INNER JOIN pais                p ON p.codigopaisiso        = datos.pais
    INNER JOIN nivelserviciocourier n ON n.nombrenivelservicio = datos.nivel
    AS nuevo(nombrecourier, idpais, idnivelservicio)
    ON DUPLICATE KEY UPDATE
        idpais          = nuevo.idpais,
        idnivelservicio = nuevo.idnivelservicio,
        activo          = 1;

    -- IDs de catalogos reutilizados en el loop
    SELECT idestadoorden    INTO videstadoentregada FROM estadoorden    WHERE codigo = 'entregada' LIMIT 1;
    SELECT idestadodespacho INTO videstadodespacho  FROM estadodespacho WHERE codigo = 'entregado' LIMIT 1;
    SELECT idtipocostoorden INTO vidtiposhipping    FROM tipocostoorden WHERE nombrecosto = 'shipping'         LIMIT 1;
    SELECT idtipocostoorden INTO vidtipopermiso     FROM tipocostoorden WHERE nombrecosto = 'permisosanitario' LIMIT 1;

    WHILE i <= pordenes DO
        SET vidx = (i - 1) MOD 9;

        SELECT idsitioweb, codigositio INTO vsitio, vcodigositio
        FROM sitioweb ORDER BY idsitioweb LIMIT vidx, 1;

        SELECT p.codigopaisiso, p.idpais, p.idmoneda
        INTO vcodigopais, vidpais, vidmoneda
        FROM sitioweb s
        INNER JOIN pais p ON p.idpais = s.idpais
        WHERE s.idsitioweb = vsitio;

        -- Cliente
        INSERT INTO clientefinal(nombrecompleto, correo, telefono)
        VALUES (
            CONCAT('cliente demo ', i),
            CONCAT('cliente', LPAD(i, 4, '0'), '@correo.demo'),
            CONCAT('+50', i)
        )
        AS nuevo
        ON DUPLICATE KEY UPDATE
            nombrecompleto = nuevo.nombrecompleto,
            telefono       = nuevo.telefono;

        SELECT idclientefinal INTO vcliente
        FROM clientefinal
        WHERE correo = CONCAT('cliente', LPAD(i, 4, '0'), '@correo.demo');

        -- Direccion del cliente
        INSERT INTO direccioncliente(idclientefinal, idpais, alias, nombrecompleto, lineadireccion1, ciudad, estadoprovincia, predeterminada)
        VALUES (
            vcliente,
            vidpais,
            'principal',
            CONCAT('cliente demo ', i),
            CONCAT('calle demo ', i, ' #', i),
            'ciudad demo',
            'provincia demo',
            1
        )
        AS nuevo
        ON DUPLICATE KEY UPDATE
            lineadireccion1 = nuevo.lineadireccion1,
            ciudad          = nuevo.ciudad;

        SELECT iddireccioncliente INTO vdireccion
        FROM direccioncliente
        WHERE idclientefinal = vcliente AND alias = 'principal'
        LIMIT 1;

        SET vcantidad = 1 + (i MOD 4);
        SET vprecio   = 45 + ((i MOD 10) * 3.5);
        SET vbruto    = ROUND(vcantidad * vprecio, 4);
        SET vimpuesto = ROUND(vbruto * 0.13, 4);
        SET vcostoshipping = ROUND(6 + (i MOD 5), 4);
        SET vcostopermiso  = ROUND(2 + (i MOD 3), 4);

        -- Producto base en el sitio
        INSERT INTO producto(nombreproducto, descripcion)
        VALUES (CONCAT('producto base ', ((i - 1) MOD 10) + 1), 'producto generado para demo')
        AS nuevo
        ON DUPLICATE KEY UPDATE descripcion = nuevo.descripcion;

        INSERT INTO productositio(idproducto, idsitioweb, idmarcaia, nombrecomercial)
        SELECT p.idproducto, vsitio, s.idmarcaia, CONCAT('producto marca ', i)
        FROM producto p, sitioweb s
        WHERE p.nombreproducto = CONCAT('producto base ', ((i - 1) MOD 10) + 1)
          AND s.idsitioweb = vsitio
        AS nuevo
        ON DUPLICATE KEY UPDATE nombrecomercial = nuevo.nombrecomercial;

        SELECT ps.idproductositio INTO vproductositio1
        FROM productositio ps
        INNER JOIN producto p ON p.idproducto = ps.idproducto
        WHERE p.nombreproducto = CONCAT('producto base ', ((i - 1) MOD 10) + 1)
          AND ps.idsitioweb = vsitio
        LIMIT 1;

        INSERT INTO preciohistoricoproducto(idproductositio, idmoneda, precio, fechadesde)
        VALUES (vproductositio1, vidmoneda, vprecio, CURRENT_DATE)
        AS nuevo
        ON DUPLICATE KEY UPDATE precio = nuevo.precio;

        SELECT idpreciohistorico INTO vprecio1
        FROM preciohistoricoproducto
        WHERE idproductositio = vproductositio1 AND fechahasta IS NULL
        LIMIT 1;

        -- Orden de venta con FKs normalizadas
        INSERT INTO ordenventa(
            codigoordenventa,
            idsitioweb,
            idclientefinal,
            iddireccioncliente,
            idmoneda,
            idestadoorden,
            fechaorden,
            totalbruto,
            totalimpuesto,
            totalcostos,
            totalneto,
            observaciones
        )
        VALUES (
            CONCAT('OV', DATE_FORMAT(CURRENT_DATE, '%Y%m'), LPAD(i, 5, '0')),
            vsitio,
            vcliente,
            vdireccion,
            vidmoneda,
            videstadoentregada,
            NOW() - INTERVAL (i MOD 7) DAY,
            vbruto,
            vimpuesto,
            ROUND(vcostoshipping + vcostopermiso, 4),
            ROUND(vbruto + vimpuesto + vcostoshipping + vcostopermiso, 4),
            CONCAT('orden demo para sitio ', vcodigositio)
        )
        AS nuevo
        ON DUPLICATE KEY UPDATE
            idestadoorden = nuevo.idestadoorden,
            totalbruto    = nuevo.totalbruto,
            totalimpuesto = nuevo.totalimpuesto,
            totalcostos   = nuevo.totalcostos,
            totalneto     = nuevo.totalneto,
            observaciones = nuevo.observaciones;

        SELECT idordenventa INTO vorden
        FROM ordenventa
        WHERE codigoordenventa = CONCAT('OV', DATE_FORMAT(CURRENT_DATE, '%Y%m'), LPAD(i, 5, '0'));

        -- Costos detallados de la orden
        INSERT INTO costoorden(idordenventa, idtipocostoorden, monto)
        VALUES
            (vorden, vidtiposhipping, vcostoshipping),
            (vorden, vidtipopermiso,  vcostopermiso);

        -- Detalle de orden con FKs a productositio y preciohistorico
        INSERT INTO ordenventadetalle(idordenventa, idproductositio, idpreciohistorico, cantidad, preciounitariolocal, subtotal)
        VALUES (vorden, vproductositio1, vprecio1, vcantidad, vprecio, ROUND(vcantidad * vprecio, 4))
        AS nuevo
        ON DUPLICATE KEY UPDATE
            cantidad            = nuevo.cantidad,
            preciounitariolocal = nuevo.preciounitariolocal,
            subtotal            = nuevo.subtotal;

        -- Courier del pais del sitio
        SELECT c.idcourierexterno INTO vidcourier
        FROM courierexterno c
        WHERE c.idpais = vidpais AND c.activo = 1
        LIMIT 1;

        -- Despacho sin estados ni fechas (esas van en tracking)
        INSERT INTO despacho(idordenventa, idcourierexterno, codigoguia, costocourierlocal, idmoneda)
        VALUES (
            vorden,
            vidcourier,
            CONCAT('GUIA', DATE_FORMAT(CURRENT_DATE, '%Y%m'), LPAD(i, 6, '0')),
            ROUND(4 + (i MOD 4), 4),
            vidmoneda
        )
        AS nuevo
        ON DUPLICATE KEY UPDATE
            costocourierlocal = nuevo.costocourierlocal;

        SELECT iddespacho INTO vdespacho
        FROM despacho
        WHERE codigoguia = CONCAT('GUIA', DATE_FORMAT(CURRENT_DATE, '%Y%m'), LPAD(i, 6, '0'));

        -- Tracking como log de inserts (reemplaza despachoseguimiento)
        INSERT INTO trackingdespacho(iddespacho, idestadodespacho, ubicacion, observacion, fechaevento)
        SELECT vdespacho, ed.idestadodespacho, datos.ubicacion, datos.observacion, datos.fechaevento
        FROM (
            SELECT 'saliohub'   AS codigo, 'hub central'         AS ubicacion, 'salida inicial desde el hub'        AS observacion, NOW() - INTERVAL 4 DAY AS fechaevento UNION ALL
            SELECT 'entransito',            'en ruta',                          'movimiento en curso hacia destino',                NOW() - INTERVAL 2 DAY              UNION ALL
            SELECT 'entregado',             CONCAT('pais ', vcodigopais),       'entrega confirmada',                              NOW() - INTERVAL 1 DAY
        ) datos
        INNER JOIN estadodespacho ed ON ed.codigo = datos.codigo;

        SET i = i + 1;
    END WHILE;

    CALL sp_registrarlogcarga('dynamicbrands', 'ordenventa,ordenventadetalle,despacho,trackingdespacho', 'carga ordenes demo', 'ok', pordenes, 'ordenes demo cargadas correctamente');
    COMMIT;
END$$

DELIMITER ;