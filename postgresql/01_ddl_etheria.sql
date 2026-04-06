set search_path = public;

create schema if not exists etheria;
create schema if not exists gerencial;

create table if not exists etheria.pais (
    idpais bigserial primary key,
    codigopaisiso char(2) not null unique,
    nombrepais varchar(80) not null unique,
    codigomoneda char(3) not null,
    monedaoficial varchar(50) not null,
    activo boolean not null default true,
    fechacreacion timestamp not null default now()
);

create table if not exists etheria.categoria (
    idcategoria bigserial primary key,
    nombrecategoria varchar(80) not null unique,
    descripcion text,
    fechacreacion timestamp not null default now()
);

create table if not exists etheria.proveedor (
    idproveedor bigserial primary key,
    nombreproveedor varchar(120) not null,
    paisorigen varchar(80) not null,
    correocontacto varchar(120),
    telefonocontacto varchar(30),
    activo boolean not null default true,
    fechacreacion timestamp not null default now(),
    constraint uk_proveedor_nombre_pais unique (nombreproveedor, paisorigen)
);

create table if not exists etheria.productobase (
    idproductobase bigserial primary key,
    codigoproducto varchar(20) not null unique,
    nombreproducto varchar(160) not null,
    idcategoria bigint not null references etheria.categoria(idcategoria),
    tipouso varchar(30) not null check (tipouso in ('ingesta', 'piel', 'capilar', 'aromaterapia', 'mixto')),
    unidadmedida varchar(20) not null,
    ingredientebase varchar(200),
    beneficiosalud text,
    activo boolean not null default true,
    fechacreacion timestamp not null default now()
);

create table if not exists etheria.productopais (
    idproductopais bigserial primary key,
    idproductobase bigint not null references etheria.productobase(idproductobase),
    idpaisdestino bigint not null references etheria.pais(idpais),
    codigosanitario varchar(60),
    requierepermiso boolean not null default true,
    restricciones text,
    fechavigencia date not null default current_date,
    activo boolean not null default true,
    constraint uk_productopais unique (idproductobase, idpaisdestino)
);

create table if not exists etheria.requisitolegal (
    idrequisitolegal bigserial primary key,
    nombrerequisito varchar(120) not null,
    entidadreguladora varchar(120) not null,
    descripcion text,
    obligatorio boolean not null default true,
    fechacreacion timestamp not null default now(),
    constraint uk_requisito unique (nombrerequisito, entidadreguladora)
);

create table if not exists etheria.requisitoproductopais (
    idrequisitopp bigserial primary key,
    idproductopais bigint not null references etheria.productopais(idproductopais),
    idrequisitolegal bigint not null references etheria.requisitolegal(idrequisitolegal),
    detalleaplicacion text,
    fechacreacion timestamp not null default now(),
    constraint uk_requisitopp unique (idproductopais, idrequisitolegal)
);

create table if not exists etheria.importacion (
    idimportacion bigserial primary key,
    codigoimportacion varchar(30) not null unique,
    idproveedor bigint not null references etheria.proveedor(idproveedor),
    estadoimportacion varchar(20) not null check (estadoimportacion in ('pedido', 'transito', 'recibido', 'cerrado')),
    fechapedido date not null,
    fechallegadacaribe date,
    observaciones text,
    fechacreacion timestamp not null default now()
);

create table if not exists etheria.importaciondetalle (
    idimportaciondetalle bigserial primary key,
    idimportacion bigint not null references etheria.importacion(idimportacion),
    idproductobase bigint not null references etheria.productobase(idproductobase),
    cantidadbulk numeric(14,2) not null check (cantidadbulk > 0),
    costounitariousd numeric(14,4) not null check (costounitariousd > 0),
    subtotalusd numeric(16,4) generated always as (cantidadbulk * costounitariousd) stored,
    fechacreacion timestamp not null default now(),
    constraint uk_importaciondetalle unique (idimportacion, idproductobase)
);

create table if not exists etheria.loteinventario (
    idloteinventario bigserial primary key,
    codigolote varchar(40) not null unique,
    idimportaciondetalle bigint not null references etheria.importaciondetalle(idimportaciondetalle),
    cantidadinicial numeric(14,2) not null check (cantidadinicial > 0),
    cantidaddisponible numeric(14,2) not null check (cantidaddisponible >= 0),
    fechavencimiento date,
    estado varchar(20) not null check (estado in ('disponible', 'reservado', 'agotado', 'vencido')),
    fechacreacion timestamp not null default now()
);

create table if not exists etheria.movimientosinventario (
    idmovimiento bigserial primary key,
    idloteinventario bigint not null references etheria.loteinventario(idloteinventario),
    tipomovimiento varchar(20) not null check (tipomovimiento in ('entrada', 'salida', 'ajuste')),
    origenmovimiento varchar(30) not null,
    cantidad numeric(14,2) not null check (cantidad > 0),
    referenciaexterna varchar(80),
    observacion text,
    fechamovimiento timestamp not null default now()
);

create table if not exists etheria.costosimportacion (
    idcostoimportacion bigserial primary key,
    idimportacion bigint not null references etheria.importacion(idimportacion),
    tipocosto varchar(30) not null check (tipocosto in ('flete', 'seguro', 'arancel', 'agenciaaduanal', 'almacenaje', 'otro')),
    montousd numeric(14,4) not null check (montousd >= 0),
    descripcion text,
    fecharegistro timestamp not null default now()
);

create table if not exists etheria.ordenabastecimiento (
    idordenabastecimiento bigserial primary key,
    codigoorden varchar(40) not null unique,
    idpaisdestino bigint not null references etheria.pais(idpais),
    nombresitioexterno varchar(120) not null,
    idmarcaexterna bigint not null,
    estadoorden varchar(20) not null check (estadoorden in ('creada', 'preparacion', 'despachada', 'cerrada', 'cancelada')),
    fechaorden timestamp not null default now(),
    observaciones text
);

create table if not exists etheria.ordenabastecimientodetalle (
    idordenabdetalle bigserial primary key,
    idordenabastecimiento bigint not null references etheria.ordenabastecimiento(idordenabastecimiento),
    idproductobase bigint not null references etheria.productobase(idproductobase),
    cantidadsolicitada numeric(14,2) not null check (cantidadsolicitada > 0),
    cantidadasignada numeric(14,2) not null default 0 check (cantidadasignada >= 0),
    preciosalidamonedalocal numeric(14,4) not null default 0,
    constraint uk_ordenabdetalle unique (idordenabastecimiento, idproductobase)
);

create table if not exists etheria.etiquetadomarca (
    idetiquetadomarca bigserial primary key,
    idordenabdetalle bigint not null references etheria.ordenabastecimientodetalle(idordenabdetalle),
    codigobarrainterno varchar(40) not null unique,
    marcaprint varchar(100) not null,
    enfoquepublicitario varchar(120),
    fecharegistro timestamp not null default now()
);

create table if not exists etheria.tipocambio (
    idtipocambio bigserial primary key,
    idpais bigint not null references etheria.pais(idpais),
    fechatasa date not null,
    tasausdmonedalocal numeric(14,6) not null check (tasausdmonedalocal > 0),
    fuente varchar(80) not null,
    fechacreacion timestamp not null default now(),
    constraint uk_tipocambio unique (idpais, fechatasa)
);

create table if not exists etheria.logcargaproceso (
    idlogcargaproceso bigserial primary key,
    modulo varchar(50) not null,
    tablaobjetivo varchar(80) not null,
    paso varchar(120) not null,
    estado varchar(20) not null check (estado in ('iniciado', 'ok', 'error')),
    filasafectadas integer,
    mensaje text,
    fecharegistro timestamp not null default now()
);

create index if not exists ix_productobase_categoria on etheria.productobase(idcategoria);
create index if not exists ix_productopais_pais on etheria.productopais(idpaisdestino);
create index if not exists ix_importacion_estado on etheria.importacion(estadoimportacion);
create index if not exists ix_loteinventario_estado on etheria.loteinventario(estado);
create index if not exists ix_tipocambio_fechatasa on etheria.tipocambio(fechatasa);
create index if not exists ix_logcargaproceso_fecha on etheria.logcargaproceso(fecharegistro);
