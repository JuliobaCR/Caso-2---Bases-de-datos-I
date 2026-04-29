-- ============================================================
-- Script DDL - Dynamic Brands
-- Motor: MySQL 8.4
-- Base de datos: dynamicbrands
-- ============================================================

CREATE DATABASE IF NOT EXISTS dynamicbrands
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE dynamicbrands;

-- ------------------------------------------------------------
-- CATALOGOS BASE
-- ------------------------------------------------------------

CREATE TABLE moneda (
    idmoneda          BIGINT        NOT NULL AUTO_INCREMENT,
    codigoisomoneda   CHAR(3)       NOT NULL,
    nombremoneda      VARCHAR(80)   NOT NULL,
    simbolo           VARCHAR(10)   NOT NULL,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idmoneda),
    UNIQUE KEY uk_moneda_codigo (codigoisomoneda),
    UNIQUE KEY uk_moneda_nombre (nombremoneda)
);

CREATE TABLE pais (
    idpais            BIGINT        NOT NULL AUTO_INCREMENT,
    codigopaisiso     CHAR(2)       NOT NULL,
    nombrepais        VARCHAR(80)   NOT NULL,
    idmoneda          BIGINT        NOT NULL,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idpais),
    UNIQUE KEY uk_pais_codigo (codigopaisiso),
    UNIQUE KEY uk_pais_nombre (nombrepais),
    CONSTRAINT fk_pais_moneda FOREIGN KEY (idmoneda) REFERENCES moneda (idmoneda)
);

CREATE TABLE marcaia (
    idmarcaia         BIGINT        NOT NULL AUTO_INCREMENT,
    nombremarca       VARCHAR(120)  NOT NULL,
    estado            VARCHAR(20)   NOT NULL,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idmarcaia),
    UNIQUE KEY uk_marcaia_nombre (nombremarca),
    CONSTRAINT chk_marcaia_estado CHECK (estado IN ('activa', 'inactiva'))
);

CREATE TABLE idioma (
    ididioma          BIGINT        NOT NULL AUTO_INCREMENT,
    codigoidioma      CHAR(5)       NOT NULL, -- es-CR, en-US
    nombreidioma      VARCHAR(80)   NOT NULL,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (ididioma),
    UNIQUE KEY uk_idioma_codigo (codigoidioma),
    UNIQUE KEY uk_idioma_nombre (nombreidioma)
);

-- ------------------------------------------------------------
-- SITIO WEB
-- ------------------------------------------------------------

CREATE TABLE sitioweb (
    idsitioweb        BIGINT        NOT NULL AUTO_INCREMENT,
    codigositio       VARCHAR(40)   NOT NULL,
    idmarcaia         BIGINT        NOT NULL,
    idpais            BIGINT        NOT NULL,
    idmoneda          BIGINT        NOT NULL,
    ididioma          BIGINT        NOT NULL,
    dominioweb        VARCHAR(180)  NOT NULL,
    urllogo           VARCHAR(500)  NOT NULL,
    urlbrand          VARCHAR(500)  NOT NULL,
    configjson        JSON          NULL,
    estado            VARCHAR(20)   NOT NULL,
    fechainicio       DATE          NOT NULL,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idsitioweb),
    UNIQUE KEY uk_sitioweb_codigo (codigositio),
    UNIQUE KEY uk_sitioweb_dominio (dominioweb),
    CONSTRAINT fk_sitioweb_marca   FOREIGN KEY (idmarcaia) REFERENCES marcaia (idmarcaia),
    CONSTRAINT fk_sitioweb_pais    FOREIGN KEY (idpais)    REFERENCES pais    (idpais),
    CONSTRAINT fk_sitioweb_moneda  FOREIGN KEY (idmoneda)  REFERENCES moneda  (idmoneda),
    CONSTRAINT fk_sitioweb_idioma  FOREIGN KEY (ididioma)  REFERENCES idioma  (ididioma),
    CONSTRAINT chk_sitioweb_estado CHECK (estado IN ('activo', 'cerrado', 'mantenimiento')),
    CONSTRAINT chk_sitioweb_config CHECK (JSON_TYPE(configjson) = 'OBJECT')
);

-- ------------------------------------------------------------
-- CLIENTES Y DIRECCIONES
-- ------------------------------------------------------------

CREATE TABLE clientefinal (
    idclientefinal    BIGINT        NOT NULL AUTO_INCREMENT,
    nombrecompleto    VARCHAR(120)  NOT NULL,
    correo            VARCHAR(150)  NOT NULL,
    telefono          VARCHAR(30)   NULL,
    fecharegistro     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idclientefinal),
    UNIQUE KEY uk_clientefinal_correo (correo)
);

CREATE TABLE direccioncliente (
    iddireccioncliente BIGINT       NOT NULL AUTO_INCREMENT,
    idclientefinal     BIGINT       NOT NULL,
    idpais             BIGINT       NOT NULL,
    alias              VARCHAR(60)  NOT NULL,           -- ej: "casa", "oficina"
    nombrecompleto     VARCHAR(120) NOT NULL,           -- destinatario puede diferir del cliente
    telefono           VARCHAR(30)  NULL,
    lineadireccion1    VARCHAR(220) NOT NULL,           -- calle, numero, apto
    lineadireccion2    VARCHAR(220) NULL,               -- urbanizacion, barrio, referencias
    ciudad             VARCHAR(100) NOT NULL,
    estadoprovincia    VARCHAR(100) NOT NULL,
    codigopostal       VARCHAR(20)  NULL,               -- no todos los paises lo usan
    predeterminada     TINYINT(1)   NOT NULL DEFAULT 0,
    activo             TINYINT(1)   NOT NULL DEFAULT 1,
    fechacreacion      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion  TIMESTAMP    NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (iddireccioncliente),
    UNIQUE KEY uk_direccion_cliente (idclientefinal, iddireccioncliente),
    CONSTRAINT fk_direccion_cliente FOREIGN KEY (idclientefinal) REFERENCES clientefinal (idclientefinal),
    CONSTRAINT fk_direccion_pais    FOREIGN KEY (idpais)         REFERENCES pais         (idpais)
);

-- ------------------------------------------------------------
-- CATALOGOS DE ORDEN
-- ------------------------------------------------------------

CREATE TABLE estadoorden (
    idestadoorden     BIGINT        NOT NULL AUTO_INCREMENT,
    codigo            VARCHAR(20)   NOT NULL, -- creada, pagada, preparando, despachada, entregada, cancelada
    descripcion       VARCHAR(120)  NOT NULL,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idestadoorden),
    UNIQUE KEY uk_estadoorden_codigo (codigo)
);

CREATE TABLE tipoimpuesto (
    idtipoimpuesto    BIGINT        NOT NULL AUTO_INCREMENT,
    idpais            BIGINT        NOT NULL,
    nombreimpuesto    VARCHAR(80)   NOT NULL, -- IVA, ISR, etc.
    porcentaje        DECIMAL(6,4)  NOT NULL,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idtipoimpuesto),
    CONSTRAINT fk_tipoimpuesto_pais FOREIGN KEY (idpais) REFERENCES pais (idpais)
);

CREATE TABLE tipocostoorden (
    idtipocostoorden  BIGINT        NOT NULL AUTO_INCREMENT,
    nombrecosto       VARCHAR(80)   NOT NULL, -- shipping, permisosanitario, etc.
    descripcion       VARCHAR(220)  NULL,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idtipocostoorden),
    UNIQUE KEY uk_tipocostoorden_nombre (nombrecosto)
);

-- ------------------------------------------------------------
-- ORDENES DE VENTA
-- ------------------------------------------------------------

CREATE TABLE ordenventa (
    idordenventa      BIGINT        NOT NULL AUTO_INCREMENT,
    codigoordenventa  VARCHAR(40)   NOT NULL,
    idsitioweb        BIGINT        NOT NULL,
    idclientefinal    BIGINT        NOT NULL,
    iddireccioncliente BIGINT       NOT NULL,
    idmoneda          BIGINT        NOT NULL,
    idestadoorden     BIGINT        NOT NULL,
    fechaorden        DATETIME      NOT NULL,
    totalbruto        DECIMAL(16,4) NOT NULL,
    totalimpuesto     DECIMAL(16,4) NOT NULL,
    totalcostos       DECIMAL(16,4) NOT NULL,
    totalneto         DECIMAL(16,4) NOT NULL,
    observaciones     VARCHAR(300)  NULL,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idordenventa),
    UNIQUE KEY uk_ordenventa_codigo (codigoordenventa),
    CONSTRAINT fk_orden_sitio      FOREIGN KEY (idsitioweb)    REFERENCES sitioweb    (idsitioweb),
    CONSTRAINT fk_orden_moneda     FOREIGN KEY (idmoneda)      REFERENCES moneda      (idmoneda),
    CONSTRAINT fk_orden_estado     FOREIGN KEY (idestadoorden) REFERENCES estadoorden (idestadoorden),
    CONSTRAINT fk_orden_direccion  FOREIGN KEY (idclientefinal, iddireccioncliente)
                                   REFERENCES direccioncliente (idclientefinal, iddireccioncliente)
);

CREATE TABLE costoorden (
    idcostoorden      BIGINT        NOT NULL AUTO_INCREMENT,
    idordenventa      BIGINT        NOT NULL,
    idtipocostoorden  BIGINT        NOT NULL,
    monto             DECIMAL(16,4) NOT NULL,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (idcostoorden),
    CONSTRAINT fk_costoorden_orden FOREIGN KEY (idordenventa)     REFERENCES ordenventa     (idordenventa),
    CONSTRAINT fk_costoorden_tipo  FOREIGN KEY (idtipocostoorden) REFERENCES tipocostoorden (idtipocostoorden)
);

-- ------------------------------------------------------------
-- PRODUCTOS
-- ------------------------------------------------------------

CREATE TABLE producto (
    idproducto        BIGINT        NOT NULL AUTO_INCREMENT,
    nombreproducto    VARCHAR(180)  NOT NULL,
    descripcion       VARCHAR(500)  NULL,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idproducto),
    UNIQUE KEY uk_producto_nombre (nombreproducto)
);

CREATE TABLE productositio (
    idproductositio   BIGINT        NOT NULL AUTO_INCREMENT,
    idproducto        BIGINT        NOT NULL,
    idsitioweb        BIGINT        NOT NULL,
    idmarcaia         BIGINT        NOT NULL,
    nombrecomercial   VARCHAR(180)  NOT NULL, -- nombre del producto en esa tienda
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idproductositio),
    UNIQUE KEY uk_productositio (idproducto, idsitioweb),
    CONSTRAINT fk_productositio_producto FOREIGN KEY (idproducto) REFERENCES producto  (idproducto),
    CONSTRAINT fk_productositio_sitio    FOREIGN KEY (idsitioweb) REFERENCES sitioweb  (idsitioweb),
    CONSTRAINT fk_productositio_marca    FOREIGN KEY (idmarcaia)  REFERENCES marcaia   (idmarcaia)
);

CREATE TABLE preciohistoricoproducto (
    idpreciohistorico BIGINT        NOT NULL AUTO_INCREMENT,
    idproductositio   BIGINT        NOT NULL,
    idmoneda          BIGINT        NOT NULL,
    precio            DECIMAL(16,4) NOT NULL,
    fechadesde        DATE          NOT NULL,
    fechahasta        DATE          NULL, -- NULL significa precio vigente
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (idpreciohistorico),
    CONSTRAINT fk_precio_productositio FOREIGN KEY (idproductositio) REFERENCES productositio (idproductositio),
    CONSTRAINT fk_precio_moneda        FOREIGN KEY (idmoneda)        REFERENCES moneda         (idmoneda)
);

CREATE TABLE tipocaracteristica (
    idtipocaracteristica BIGINT      NOT NULL AUTO_INCREMENT,
    nombrecaracteristica VARCHAR(80) NOT NULL, -- talla, color, peso
    unidadmedida         VARCHAR(20) NULL,     -- kg, cm, NULL si no aplica
    activo               TINYINT(1)  NOT NULL DEFAULT 1,
    fechacreacion        TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion    TIMESTAMP   NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idtipocaracteristica),
    UNIQUE KEY uk_tipocaracteristica_nombre (nombrecaracteristica)
);

CREATE TABLE caracteristicaproducto (
    idcaracteristicaproducto BIGINT      NOT NULL AUTO_INCREMENT,
    idproductositio          BIGINT      NOT NULL,
    idtipocaracteristica     BIGINT      NOT NULL,
    valor                    VARCHAR(120) NOT NULL, -- "XL", "Rojo", "2.5"
    fechacreacion            TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion        TIMESTAMP   NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idcaracteristicaproducto),
    UNIQUE KEY uk_caracteristica_producto (idproductositio, idtipocaracteristica),
    CONSTRAINT fk_caracteristica_producto FOREIGN KEY (idproductositio)      REFERENCES productositio     (idproductositio),
    CONSTRAINT fk_caracteristica_tipo     FOREIGN KEY (idtipocaracteristica) REFERENCES tipocaracteristica (idtipocaracteristica)
);

CREATE TABLE ordenventadetalle (
    idordenventadetalle BIGINT        NOT NULL AUTO_INCREMENT,
    idordenventa        BIGINT        NOT NULL,
    idproductositio     BIGINT        NOT NULL,
    idpreciohistorico   BIGINT        NOT NULL,
    cantidad            DECIMAL(14,2) NOT NULL,
    preciounitariolocal DECIMAL(16,4) NOT NULL,
    subtotal            DECIMAL(16,4) NOT NULL,
    fechacreacion       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion   TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idordenventadetalle),
    CONSTRAINT chk_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT fk_detalle_orden   FOREIGN KEY (idordenventa)      REFERENCES ordenventa             (idordenventa),
    CONSTRAINT fk_detalle_producto FOREIGN KEY (idproductositio)  REFERENCES productositio          (idproductositio),
    CONSTRAINT fk_detalle_precio   FOREIGN KEY (idpreciohistorico) REFERENCES preciohistoricoproducto (idpreciohistorico)
);

-- ------------------------------------------------------------
-- COURIER Y DESPACHO
-- ------------------------------------------------------------

CREATE TABLE nivelserviciocourier (
    idnivelservicio   BIGINT        NOT NULL AUTO_INCREMENT,
    nombrenivelservicio VARCHAR(80) NOT NULL, -- express, estandar, economico
    descripcion       VARCHAR(220)  NULL,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idnivelservicio),
    UNIQUE KEY uk_nivelservicio_nombre (nombrenivelservicio)
);

CREATE TABLE courierexterno (
    idcourierexterno  BIGINT        NOT NULL AUTO_INCREMENT,
    nombrecourier     VARCHAR(120)  NOT NULL,
    idpais            BIGINT        NOT NULL,
    idnivelservicio   BIGINT        NOT NULL,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idcourierexterno),
    UNIQUE KEY uk_courier_nombre (nombrecourier),
    CONSTRAINT fk_courier_pais   FOREIGN KEY (idpais)          REFERENCES pais                 (idpais),
    CONSTRAINT fk_courier_nivel  FOREIGN KEY (idnivelservicio) REFERENCES nivelserviciocourier (idnivelservicio)
);

CREATE TABLE despacho (
    iddespacho        BIGINT        NOT NULL AUTO_INCREMENT,
    idordenventa      BIGINT        NOT NULL,
    idcourierexterno  BIGINT        NOT NULL,
    codigoguia        VARCHAR(60)   NOT NULL,
    costocourierlocal DECIMAL(16,4) NOT NULL,
    idmoneda          BIGINT        NOT NULL,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (iddespacho),
    UNIQUE KEY uk_despacho_guia (codigoguia),
    CONSTRAINT fk_despacho_orden   FOREIGN KEY (idordenventa)     REFERENCES ordenventa    (idordenventa),
    CONSTRAINT fk_despacho_courier FOREIGN KEY (idcourierexterno) REFERENCES courierexterno (idcourierexterno),
    CONSTRAINT fk_despacho_moneda  FOREIGN KEY (idmoneda)         REFERENCES moneda         (idmoneda)
);

CREATE TABLE estadodespacho (
    idestadodespacho  BIGINT        NOT NULL AUTO_INCREMENT,
    codigo            VARCHAR(20)   NOT NULL, -- saliohub, enaduana, entransito, entregado, incidencia
    descripcion       VARCHAR(120)  NOT NULL,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    fechacreacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fechamodificacion TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (idestadodespacho),
    UNIQUE KEY uk_estadodespacho_codigo (codigo)
);

-- Solo inserts, nunca updates — patron de log de tracking
CREATE TABLE trackingdespacho (
    idtrackingdespacho BIGINT       NOT NULL AUTO_INCREMENT,
    iddespacho         BIGINT       NOT NULL,
    idestadodespacho   BIGINT       NOT NULL,
    ubicacion          VARCHAR(220) NULL,  -- ciudad, aduana, bodega, etc.
    observacion        VARCHAR(500) NULL,
    fechaevento        DATETIME     NOT NULL,
    fechacreacion      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (idtrackingdespacho),
    CONSTRAINT fk_tracking_despacho FOREIGN KEY (iddespacho)       REFERENCES despacho       (iddespacho),
    CONSTRAINT fk_tracking_estado   FOREIGN KEY (idestadodespacho) REFERENCES estadodespacho (idestadodespacho)
);

-- ------------------------------------------------------------
-- LOGS
-- ------------------------------------------------------------

-- Solo inserts, nunca updates — patron de log de procesos
CREATE TABLE logcargaproceso (
    idlogcargaproceso BIGINT        NOT NULL AUTO_INCREMENT,
    modulo            VARCHAR(50)   NOT NULL,
    tablaobjetivo     VARCHAR(80)   NOT NULL,
    paso              VARCHAR(120)  NOT NULL,
    estado            VARCHAR(20)   NOT NULL,
    filasafectadas    INT           NULL,
    duracionms        INT           NULL,  -- duracion del paso en milisegundos
    idreferencia      BIGINT        NULL,  -- ID del registro afectado
    mensaje           VARCHAR(500)  NULL,
    fecharegistro     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (idlogcargaproceso),
    CONSTRAINT chk_log_estado CHECK (estado IN ('iniciado', 'ok', 'error'))
);

-- ------------------------------------------------------------
-- INDICES
-- ------------------------------------------------------------

CREATE INDEX ix_sitioweb_pais                ON sitioweb                (idpais);
CREATE INDEX ix_sitioweb_marca               ON sitioweb                (idmarcaia);
CREATE INDEX ix_ordenventa_fecha             ON ordenventa              (fechaorden);
CREATE INDEX ix_ordenventa_estado            ON ordenventa              (idestadoorden);
CREATE INDEX ix_ordenventa_cliente           ON ordenventa              (idclientefinal);
CREATE INDEX ix_ordenventadetalle_producto   ON ordenventadetalle       (idproductositio);
CREATE INDEX ix_productositio_sitio          ON productositio           (idsitioweb);
CREATE INDEX ix_preciohistorico_producto     ON preciohistoricoproducto (idproductositio);
CREATE INDEX ix_trackingdespacho_despacho    ON trackingdespacho        (iddespacho);
CREATE INDEX ix_trackingdespacho_estado      ON trackingdespacho        (idestadodespacho);
CREATE INDEX ix_trackingdespacho_fecha       ON trackingdespacho        (fechaevento);
CREATE INDEX ix_log_fecha                    ON logcargaproceso         (fecharegistro);
CREATE INDEX ix_log_modulo                   ON logcargaproceso         (modulo);