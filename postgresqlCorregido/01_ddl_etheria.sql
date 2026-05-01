-- ============================================================
-- Script DDL - Etheria Global
-- Motor: PostgreSQL 16
-- Schemas: etheria (operativo), gerencial (analitico)
-- ============================================================

CREATE SCHEMA IF NOT EXISTS etheria;
CREATE SCHEMA IF NOT EXISTS gerencial;

SET search_path TO etheria;

-- ------------------------------------------------------------
-- CATALOGOS BASE
-- ------------------------------------------------------------

CREATE TABLE etheria.moneda (
    idmoneda          BIGSERIAL       NOT NULL,
    codigoisomoneda   CHAR(3)         NOT NULL,
    nombremoneda      VARCHAR(80)     NOT NULL,
    simbolo           VARCHAR(10)     NOT NULL,
    activo            BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion TIMESTAMP       NULL,
    CONSTRAINT pk_moneda PRIMARY KEY (idmoneda),
    CONSTRAINT uk_moneda_codigo  UNIQUE (codigoisomoneda),
    CONSTRAINT uk_moneda_nombre  UNIQUE (nombremoneda)
);

CREATE TABLE etheria.pais (
    idpais            BIGSERIAL       NOT NULL,
    codigopaisiso     CHAR(2)         NOT NULL,
    nombrepais        VARCHAR(80)     NOT NULL,
    idmoneda          BIGINT          NOT NULL,
    activo            BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion TIMESTAMP       NULL,
    CONSTRAINT pk_pais          PRIMARY KEY (idpais),
    CONSTRAINT uk_pais_codigo   UNIQUE (codigopaisiso),
    CONSTRAINT uk_pais_nombre   UNIQUE (nombrepais),
    CONSTRAINT fk_pais_moneda   FOREIGN KEY (idmoneda) REFERENCES etheria.moneda (idmoneda)
);

CREATE TABLE etheria.categoria (
    idcategoria       BIGSERIAL       NOT NULL,
    nombrecategoria   VARCHAR(80)     NOT NULL,
    descripcion       VARCHAR(500)    NULL,
    activo            BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion TIMESTAMP       NULL,
    CONSTRAINT pk_categoria       PRIMARY KEY (idcategoria),
    CONSTRAINT uk_categoria_nombre UNIQUE (nombrecategoria)
);

CREATE TABLE etheria.proveedor (
    idproveedor       BIGSERIAL       NOT NULL,
    nombreproveedor   VARCHAR(120)    NOT NULL,
    idpais            BIGINT          NOT NULL,
    correocontacto    VARCHAR(120)    NULL,
    telefonocontacto  VARCHAR(30)     NULL,
    activo            BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion TIMESTAMP       NULL,
    CONSTRAINT pk_proveedor         PRIMARY KEY (idproveedor),
    CONSTRAINT uk_proveedor_nombre  UNIQUE (nombreproveedor),
    CONSTRAINT fk_proveedor_pais    FOREIGN KEY (idpais) REFERENCES etheria.pais (idpais)
);

-- ------------------------------------------------------------
-- CATALOGOS DE PRODUCTO
-- ------------------------------------------------------------

CREATE TABLE etheria.tipousoproducto (
    idtipousobase       BIGSERIAL       NOT NULL,
    nombretipousobase   VARCHAR(80)     NOT NULL, -- ingesta, piel, capilar, aromaterapia, mixto
    descripcion         VARCHAR(220)    NULL,
    activo              BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion       TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion   TIMESTAMP       NULL,
    CONSTRAINT pk_tipousoproducto       PRIMARY KEY (idtipousobase),
    CONSTRAINT uk_tipousoproducto_nombre UNIQUE (nombretipousobase)
);

CREATE TABLE etheria.tipoatributoproducto (
    idtipoatributo      BIGSERIAL       NOT NULL,
    nombreatributo      VARCHAR(80)     NOT NULL, -- ingrediente, beneficio, contraindicacion
    unidadmedida        VARCHAR(20)     NULL,      -- NULL si no aplica
    activo              BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion       TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion   TIMESTAMP       NULL,
    CONSTRAINT pk_tipoatributoproducto       PRIMARY KEY (idtipoatributo),
    CONSTRAINT uk_tipoatributoproducto_nombre UNIQUE (nombreatributo)
);

CREATE TABLE etheria.productobase (
    idproductobase    BIGSERIAL       NOT NULL,
    codigoproducto    VARCHAR(20)     NOT NULL,
    nombreproducto    VARCHAR(160)    NOT NULL,
    idcategoria       BIGINT          NOT NULL,
    idtipousobase     BIGINT          NOT NULL,
    unidadmedida      VARCHAR(20)     NOT NULL,
    activo            BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion TIMESTAMP       NULL,
    CONSTRAINT pk_productobase          PRIMARY KEY (idproductobase),
    CONSTRAINT uk_productobase_codigo   UNIQUE (codigoproducto),
    CONSTRAINT fk_productobase_categoria FOREIGN KEY (idcategoria)   REFERENCES etheria.categoria       (idcategoria),
    CONSTRAINT fk_productobase_tipousobase FOREIGN KEY (idtipousobase) REFERENCES etheria.tipousoproducto (idtipousobase)
);

CREATE TABLE etheria.atributoproductobase (
    idatributoproductobase BIGSERIAL    NOT NULL,
    idproductobase         BIGINT       NOT NULL,
    idtipoatributo         BIGINT       NOT NULL,
    valor                  VARCHAR(220) NOT NULL, -- "Aloe Vera", "Hidratacion profunda", etc.
    fechacreacion          TIMESTAMP    NOT NULL DEFAULT now(),
    fechamodificacion      TIMESTAMP    NULL,
    CONSTRAINT pk_atributoproductobase       PRIMARY KEY (idatributoproductobase),
    CONSTRAINT uk_atributoproductobase       UNIQUE (idproductobase, idtipoatributo),
    CONSTRAINT fk_atributo_productobase      FOREIGN KEY (idproductobase) REFERENCES etheria.productobase        (idproductobase),
    CONSTRAINT fk_atributo_tipoatributo      FOREIGN KEY (idtipoatributo) REFERENCES etheria.tipoatributoproducto (idtipoatributo)
);

-- ------------------------------------------------------------
-- REGULATORIO
-- ------------------------------------------------------------

CREATE TABLE etheria.codigosanitario (
    idcodigosanitario BIGSERIAL       NOT NULL,
    idpais            BIGINT          NOT NULL,
    codigo            VARCHAR(60)     NOT NULL,
    entidademisora    VARCHAR(120)    NOT NULL, -- MINSA, COFEPRIS, INVIMA, etc.
    urldocumento      VARCHAR(500)    NULL,
    fechaemision      DATE            NULL,
    fechavencimiento  DATE            NULL,
    activo            BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion TIMESTAMP       NULL,
    CONSTRAINT pk_codigosanitario       PRIMARY KEY (idcodigosanitario),
    CONSTRAINT uk_codigosanitario_codigo UNIQUE (codigo),
    CONSTRAINT fk_codigosanitario_pais  FOREIGN KEY (idpais) REFERENCES etheria.pais (idpais)
);

CREATE TABLE etheria.configuracionregulatoriacategoria (
    idconfigregulatoria   BIGSERIAL   NOT NULL,
    idcategoria           BIGINT      NOT NULL,
    idpais                BIGINT      NOT NULL,
    idcodigosanitario     BIGINT      NULL,
    requierepermiso       BOOLEAN     NOT NULL DEFAULT true,
    fechavigencia         DATE        NOT NULL DEFAULT current_date,
    activo                BOOLEAN     NOT NULL DEFAULT true,
    fechacreacion         TIMESTAMP   NOT NULL DEFAULT now(),
    fechamodificacion     TIMESTAMP   NULL,
    CONSTRAINT pk_configregulatoria       PRIMARY KEY (idconfigregulatoria),
    CONSTRAINT uk_configregulatoria       UNIQUE (idcategoria, idpais),
    CONSTRAINT fk_configregulatoria_cat   FOREIGN KEY (idcategoria)       REFERENCES etheria.categoria       (idcategoria),
    CONSTRAINT fk_configregulatoria_pais  FOREIGN KEY (idpais)            REFERENCES etheria.pais            (idpais),
    CONSTRAINT fk_configregulatoria_codigo FOREIGN KEY (idcodigosanitario) REFERENCES etheria.codigosanitario (idcodigosanitario)
);

CREATE TABLE etheria.requisitolegal (
    idrequisitolegal    BIGSERIAL       NOT NULL,
    idpais              BIGINT          NOT NULL,
    nombrerequisito     VARCHAR(120)    NOT NULL,
    entidadreguladora   VARCHAR(120)    NOT NULL,
    urldocumento        VARCHAR(500)    NULL,
    obligatorio         BOOLEAN         NOT NULL DEFAULT true,
    activo              BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion       TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion   TIMESTAMP       NULL,
    CONSTRAINT pk_requisitolegal        PRIMARY KEY (idrequisitolegal),
    CONSTRAINT uk_requisitolegal        UNIQUE (idpais, nombrerequisito),
    CONSTRAINT fk_requisitolegal_pais   FOREIGN KEY (idpais) REFERENCES etheria.pais (idpais)
);

CREATE TABLE etheria.requisitosporconfiguracion (
    idconfigrequisito   BIGSERIAL   NOT NULL,
    idconfigregulatoria BIGINT      NOT NULL,
    idrequisitolegal    BIGINT      NOT NULL,
    fechacreacion       TIMESTAMP   NOT NULL DEFAULT now(),
    CONSTRAINT pk_requisitosporconfiguracion    PRIMARY KEY (idconfigrequisito),
    CONSTRAINT uk_requisitosporconfiguracion    UNIQUE (idconfigregulatoria, idrequisitolegal),
    CONSTRAINT fk_reqconfig_configuracion       FOREIGN KEY (idconfigregulatoria) REFERENCES etheria.configuracionregulatoriacategoria (idconfigregulatoria),
    CONSTRAINT fk_reqconfig_requisito           FOREIGN KEY (idrequisitolegal)    REFERENCES etheria.requisitolegal                   (idrequisitolegal)
);

-- ------------------------------------------------------------
-- IMPORTACION
-- ------------------------------------------------------------

CREATE TABLE etheria.estadoimportacion (
    idestadoimportacion BIGSERIAL       NOT NULL,
    codigo              VARCHAR(20)     NOT NULL, -- pedido, transito, recibido, cerrado
    descripcion         VARCHAR(120)    NOT NULL,
    activo              BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion       TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion   TIMESTAMP       NULL,
    CONSTRAINT pk_estadoimportacion       PRIMARY KEY (idestadoimportacion),
    CONSTRAINT uk_estadoimportacion_codigo UNIQUE (codigo)
);

CREATE TABLE etheria.codigoaduanal (
    idcodigoaduanal   BIGSERIAL       NOT NULL,
    idpais            BIGINT          NOT NULL,
    idcategoria       BIGINT          NOT NULL,
    codigo            VARCHAR(30)     NOT NULL, -- codigo arancelario HS
    descripcion       VARCHAR(220)    NOT NULL,
    activo            BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion TIMESTAMP       NULL,
    CONSTRAINT pk_codigoaduanal         PRIMARY KEY (idcodigoaduanal),
    CONSTRAINT uk_codigoaduanal_codigo  UNIQUE (codigo),
    CONSTRAINT uk_codigoaduanal_paiscategoria UNIQUE (idpais, idcategoria),
    CONSTRAINT fk_codigoaduanal_pais    FOREIGN KEY (idpais)      REFERENCES etheria.pais      (idpais),
    CONSTRAINT fk_codigoaduanal_cat     FOREIGN KEY (idcategoria) REFERENCES etheria.categoria (idcategoria)
);

CREATE TABLE etheria.importacion (
    idimportacion         BIGSERIAL       NOT NULL,
    idproveedor           BIGINT          NOT NULL,
    idestadoimportacion   BIGINT          NOT NULL,
    idcodigoaduanal       BIGINT          NOT NULL,
    fechapedido           DATE            NOT NULL,
    fechallegadacaribe    DATE            NULL,
    observaciones         VARCHAR(500)    NULL,
    fechacreacion         TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion     TIMESTAMP       NULL,
    CONSTRAINT pk_importacion               PRIMARY KEY (idimportacion),
    CONSTRAINT fk_importacion_proveedor     FOREIGN KEY (idproveedor)         REFERENCES etheria.proveedor         (idproveedor),
    CONSTRAINT fk_importacion_estado        FOREIGN KEY (idestadoimportacion) REFERENCES etheria.estadoimportacion (idestadoimportacion),
    CONSTRAINT fk_importacion_codigoaduanal FOREIGN KEY (idcodigoaduanal)     REFERENCES etheria.codigoaduanal     (idcodigoaduanal)
);

-- ------------------------------------------------------------
-- TIPO DE CAMBIO
-- ------------------------------------------------------------

CREATE TABLE etheria.tipocambio (
    idtipocambio      BIGSERIAL       NOT NULL,
    idmonedabase      BIGINT          NOT NULL, -- moneda origen, ej: USD
    idmonedadestino   BIGINT          NOT NULL, -- moneda destino, ej: CRC
    tasa              NUMERIC(14,6)   NOT NULL,
    fuente            VARCHAR(80)     NOT NULL,
    fechadesde        DATE            NOT NULL,
    fechahasta        DATE            NULL,     -- NULL significa tasa vigente
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    CONSTRAINT pk_tipocambio            PRIMARY KEY (idtipocambio),
    CONSTRAINT uk_tipocambio            UNIQUE (idmonedabase, idmonedadestino, fechadesde),
    CONSTRAINT chk_tipocambio_tasa      CHECK (tasa > 0),
    CONSTRAINT fk_tipocambio_base       FOREIGN KEY (idmonedabase)    REFERENCES etheria.moneda (idmoneda),
    CONSTRAINT fk_tipocambio_destino    FOREIGN KEY (idmonedadestino) REFERENCES etheria.moneda (idmoneda)
);

-- ------------------------------------------------------------
-- INVENTARIO
-- ------------------------------------------------------------

CREATE TABLE etheria.loteinventario (
    idloteinventario  BIGSERIAL       NOT NULL,
    codigolote        VARCHAR(40)     NOT NULL,
    idproductobase    BIGINT          NOT NULL,
    cantidadinicial   NUMERIC(14,2)   NOT NULL,
    fechavencimiento  DATE            NULL,
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    CONSTRAINT pk_loteinventario        PRIMARY KEY (idloteinventario),
    CONSTRAINT uk_loteinventario_codigo UNIQUE (codigolote),
    CONSTRAINT chk_loteinventario_cantidad CHECK (cantidadinicial > 0),
    CONSTRAINT fk_loteinventario_producto FOREIGN KEY (idproductobase) REFERENCES etheria.productobase (idproductobase)
);

CREATE TABLE etheria.importaciondetalle (
    idimportaciondetalle  BIGSERIAL       NOT NULL,
    idimportacion         BIGINT          NOT NULL,
    idloteinventario      BIGINT          NOT NULL,
    idtipocambio          BIGINT          NOT NULL,
    tasacambio            NUMERIC(14,6)   NOT NULL, -- tasa guardada en el momento de la transaccion
    costounitariobase     NUMERIC(14,4)   NOT NULL,
    subtotalbase          NUMERIC(16,4)   NOT NULL,
    costounitariolocal    NUMERIC(14,4)   NOT NULL,
    subtotallocal         NUMERIC(16,4)   NOT NULL,
    fechacreacion         TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion     TIMESTAMP       NULL,
    CONSTRAINT pk_importaciondetalle        PRIMARY KEY (idimportaciondetalle),
    CONSTRAINT uk_importaciondetalle        UNIQUE (idimportacion, idloteinventario),
    CONSTRAINT chk_importdet_costo          CHECK (costounitariobase > 0),
    CONSTRAINT fk_importdet_importacion     FOREIGN KEY (idimportacion)    REFERENCES etheria.importacion    (idimportacion),
    CONSTRAINT fk_importdet_lote            FOREIGN KEY (idloteinventario) REFERENCES etheria.loteinventario (idloteinventario),
    CONSTRAINT fk_importdet_tipocambio      FOREIGN KEY (idtipocambio)     REFERENCES etheria.tipocambio     (idtipocambio)
);

CREATE TABLE etheria.tipomovimientoinventario (
    idtipomovimiento  BIGSERIAL       NOT NULL,
    codigo            VARCHAR(20)     NOT NULL, -- entrada, salida, ajuste
    descripcion       VARCHAR(120)    NOT NULL,
    activo            BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion TIMESTAMP       NULL,
    CONSTRAINT pk_tipomovimientoinventario       PRIMARY KEY (idtipomovimiento),
    CONSTRAINT uk_tipomovimientoinventario_codigo UNIQUE (codigo)
);

-- Solo inserts, nunca updates - patron de log de movimientos
CREATE TABLE etheria.movimientosinventario (
    idmovimiento      BIGSERIAL       NOT NULL,
    idloteinventario  BIGINT          NOT NULL,
    idtipomovimiento  BIGINT          NOT NULL,
    origenmovimiento  VARCHAR(30)     NOT NULL,
    cantidad          NUMERIC(14,2)   NOT NULL,
    referenciaexterna VARCHAR(80)     NULL,
    observacion       VARCHAR(500)    NULL,
    fechamovimiento   TIMESTAMP       NOT NULL DEFAULT now(),
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    CONSTRAINT pk_movimientosinventario     PRIMARY KEY (idmovimiento),
    CONSTRAINT chk_movimientos_cantidad     CHECK (cantidad > 0),
    CONSTRAINT fk_movimientos_lote          FOREIGN KEY (idloteinventario) REFERENCES etheria.loteinventario          (idloteinventario),
    CONSTRAINT fk_movimientos_tipo          FOREIGN KEY (idtipomovimiento) REFERENCES etheria.tipomovimientoinventario (idtipomovimiento)
);

-- ------------------------------------------------------------
-- COSTOS DE IMPORTACION
-- ------------------------------------------------------------

CREATE TABLE etheria.tipocostoimportacion (
    idtipocosto       BIGSERIAL       NOT NULL,
    nombrecosto       VARCHAR(80)     NOT NULL, -- flete, seguro, arancel, agenciaaduanal, almacenaje, otro
    descripcion       VARCHAR(220)    NULL,
    esporcentaje      BOOLEAN         NOT NULL DEFAULT false, -- true = %, false = flat
    valor             NUMERIC(14,4)   NOT NULL,
    fechadesde        DATE            NOT NULL,
    fechahasta        DATE            NULL,     -- NULL significa vigente
    activo            BOOLEAN         NOT NULL DEFAULT true,
    fechacreacion     TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion TIMESTAMP       NULL,
    CONSTRAINT pk_tipocostoimportacion      PRIMARY KEY (idtipocosto),
    CONSTRAINT uk_tipocostoimportacion      UNIQUE (nombrecosto, fechadesde),
    CONSTRAINT chk_tipocosto_valor          CHECK (valor >= 0)
);

CREATE TABLE etheria.costosimportacion (
    idcostoimportacion  BIGSERIAL       NOT NULL,
    idimportacion       BIGINT          NOT NULL,
    idtipocosto         BIGINT          NOT NULL,
    idtipocambio        BIGINT          NOT NULL,
    tasacambio          NUMERIC(14,6)   NOT NULL,
    valorlocal          NUMERIC(14,4)   NOT NULL, -- valor convertido a moneda local en el momento
    fechacreacion       TIMESTAMP       NOT NULL DEFAULT now(),
    CONSTRAINT pk_costosimportacion         PRIMARY KEY (idcostoimportacion),
    CONSTRAINT fk_costos_importacion        FOREIGN KEY (idimportacion) REFERENCES etheria.importacion        (idimportacion),
    CONSTRAINT fk_costos_tipocosto          FOREIGN KEY (idtipocosto)   REFERENCES etheria.tipocostoimportacion (idtipocosto),
    CONSTRAINT fk_costos_tipocambio         FOREIGN KEY (idtipocambio)  REFERENCES etheria.tipocambio           (idtipocambio)
);

-- ------------------------------------------------------------
-- ETIQUETADO
-- ------------------------------------------------------------

CREATE TABLE etheria.etiquetadomarca (
    idetiquetadomarca   BIGSERIAL       NOT NULL,
    idimportacion       BIGINT          NOT NULL,
    idproductobase      BIGINT          NOT NULL,
    codigobarrainterno  VARCHAR(40)     NOT NULL,
    marcaprint          VARCHAR(100)    NOT NULL,
    enfoquepublicitario VARCHAR(120)    NULL,
    fechacreacion       TIMESTAMP       NOT NULL DEFAULT now(),
    fechamodificacion   TIMESTAMP       NULL,
    CONSTRAINT pk_etiquetadomarca           PRIMARY KEY (idetiquetadomarca),
    CONSTRAINT uk_etiquetadomarca_codigo    UNIQUE (codigobarrainterno),
    CONSTRAINT fk_etiquetado_importacion    FOREIGN KEY (idimportacion)  REFERENCES etheria.importacion  (idimportacion),
    CONSTRAINT fk_etiquetado_producto       FOREIGN KEY (idproductobase) REFERENCES etheria.productobase (idproductobase)
);

-- ------------------------------------------------------------
-- LOGS
-- ------------------------------------------------------------

-- Solo inserts, nunca updates - patron de log de procesos
CREATE TABLE etheria.logcargaproceso (
    idlogcargaproceso BIGSERIAL       NOT NULL,
    modulo            VARCHAR(50)     NOT NULL,
    tablaobjetivo     VARCHAR(80)     NOT NULL,
    paso              VARCHAR(120)    NOT NULL,
    estado            VARCHAR(20)     NOT NULL,
    filasafectadas    INTEGER         NULL,
    duracionms        INTEGER         NULL,  -- duracion del paso en milisegundos
    idreferencia      BIGINT          NULL,  -- ID del registro afectado
    mensaje           VARCHAR(500)    NULL,
    fecharegistro     TIMESTAMP       NOT NULL DEFAULT now(),
    CONSTRAINT pk_logcargaproceso   PRIMARY KEY (idlogcargaproceso),
    CONSTRAINT chk_log_estado       CHECK (estado IN ('iniciado', 'ok', 'error'))
);

-- ------------------------------------------------------------
-- INDICES (schema etheria)
-- ------------------------------------------------------------

CREATE INDEX ix_productobase_categoria         ON etheria.productobase                      (idcategoria);
CREATE INDEX ix_productobase_tipousobase        ON etheria.productobase                      (idtipousobase);
CREATE INDEX ix_proveedor_pais                  ON etheria.proveedor                         (idpais);
CREATE INDEX ix_importacion_proveedor           ON etheria.importacion                       (idproveedor);
CREATE INDEX ix_importacion_estado              ON etheria.importacion                       (idestadoimportacion);
CREATE INDEX ix_importacion_codigoaduanal       ON etheria.importacion                       (idcodigoaduanal);
CREATE INDEX ix_importaciondetalle_lote         ON etheria.importaciondetalle                (idloteinventario);
CREATE INDEX ix_loteinventario_producto         ON etheria.loteinventario                    (idproductobase);
CREATE INDEX ix_loteinventario_vencimiento      ON etheria.loteinventario                    (fechavencimiento);
CREATE INDEX ix_movimientos_lote                ON etheria.movimientosinventario             (idloteinventario);
CREATE INDEX ix_movimientos_fecha               ON etheria.movimientosinventario             (fechamovimiento);
CREATE INDEX ix_tipocambio_monedas              ON etheria.tipocambio                        (idmonedabase, idmonedadestino);
CREATE INDEX ix_tipocambio_vigente              ON etheria.tipocambio                        (idmonedabase, idmonedadestino, fechahasta);
CREATE INDEX ix_configregulatoria_pais          ON etheria.configuracionregulatoriacategoria (idpais);
CREATE INDEX ix_requisitolegal_pais             ON etheria.requisitolegal                    (idpais);
CREATE INDEX ix_logcargaproceso_fecha           ON etheria.logcargaproceso                   (fecharegistro);
CREATE INDEX ix_logcargaproceso_modulo          ON etheria.logcargaproceso                   (modulo);

-- ------------------------------------------------------------
-- TABLAS ANALITICAS (schema gerencial)
-- ------------------------------------------------------------

CREATE TABLE gerencial.ventaunificada (
    idventaunificada        BIGSERIAL       NOT NULL,
    fechaorden              DATE            NOT NULL,
    fechacarga              TIMESTAMP       NOT NULL DEFAULT now(),
    codigopaisiso           CHAR(2)         NOT NULL,
    nombrepais              VARCHAR(80)     NOT NULL,
    idsitioweb              BIGINT          NOT NULL,
    codigositio             VARCHAR(40)     NOT NULL,
    nombremarca             VARCHAR(120)    NOT NULL,
    codigoordenventa        VARCHAR(40)     NOT NULL,
    codigoproducto          VARCHAR(20)     NOT NULL,
    nombreproducto          VARCHAR(160)    NOT NULL,
    nombrecategoria         VARCHAR(80)     NOT NULL,
    cantidad                NUMERIC(14,2)   NOT NULL,
    preciounitariolocal     NUMERIC(16,4)   NOT NULL,
    subtotalmonedalocal     NUMERIC(16,4)   NOT NULL,
    totalimpuesto           NUMERIC(16,4)   NOT NULL,
    costoshippinglocal      NUMERIC(16,4)   NOT NULL,
    permisosanitariolocal   NUMERIC(16,4)   NOT NULL,
    costocourierlocal       NUMERIC(16,4)   NOT NULL,
    tasacambio              NUMERIC(16,6)   NOT NULL,
    ingresousd              NUMERIC(16,4)   NOT NULL,
    costoproductousd        NUMERIC(16,4)   NOT NULL,
    costosimportacionusd    NUMERIC(16,4)   NOT NULL,
    costoslogisticosusd     NUMERIC(16,4)   NOT NULL,
    costototalusd           NUMERIC(16,4)   NOT NULL,
    margenusd               NUMERIC(16,4)   NOT NULL,
    margenporcentaje        NUMERIC(8,2)    NOT NULL,
    CONSTRAINT pk_ventaunificada    PRIMARY KEY (idventaunificada),
    CONSTRAINT uk_ventaunificada    UNIQUE (codigoordenventa, codigoproducto)
);

-- ------------------------------------------------------------
-- INDICES (schema gerencial)
-- ------------------------------------------------------------

CREATE INDEX ix_ventaunificada_fecha        ON gerencial.ventaunificada (fechaorden);
CREATE INDEX ix_ventaunificada_categoria    ON gerencial.ventaunificada (nombrecategoria);
CREATE INDEX ix_ventaunificada_pais         ON gerencial.ventaunificada (codigopaisiso);
CREATE INDEX ix_ventaunificada_marca        ON gerencial.ventaunificada (nombremarca);