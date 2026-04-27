create database if not exists dynamicbrands character set utf8mb4 collate utf8mb4_spanish_ci;
use dynamicbrands;

create table if not exists moneda (
    codigomoneda char(3) primary key,
    nombremoneda varchar(50) not null unique,
    simbolomoneda varchar(10),
    activa tinyint(1) not null default 1,
    fechacreacion timestamp not null default current_timestamp
);

create table if not exists pais (
    idpais bigint auto_increment primary key,
    codigopaisiso char(2) not null unique,
    nombrepais varchar(80) not null unique,
    codigomoneda char(3) not null,
    monedaoficial varchar(50) not null,
    activo tinyint(1) not null default 1,
    fechacreacion timestamp not null default current_timestamp,
    constraint fk_pais_moneda foreign key (codigomoneda) references moneda(codigomoneda)
);

create table if not exists marcaia (
    idmarcaia bigint auto_increment primary key,
    nombremarca varchar(120) not null unique,
    enfoqueprincipal varchar(120) not null,
    descripcionmarca text,
    estado varchar(20) not null,
    fechacreacion timestamp not null default current_timestamp,
    fechamodificacion timestamp not null default current_timestamp on update current_timestamp,
    constraint ck_marcaia_estado check (estado in ('activa', 'inactiva', 'pausada'))
);

create table if not exists sitioweb (
    idsitioweb bigint auto_increment primary key,
    codigositio varchar(40) not null unique,
    idmarcaia bigint not null,
    idpais bigint not null,
    dominioweb varchar(180) not null unique,
    idioma varchar(20) not null,
    monedaoperacion char(3) not null,
    configuracionjson json not null,
    estado varchar(20) not null,
    fechainicio date not null,
    fechacierre date null,
    fechamodificacion timestamp not null default current_timestamp on update current_timestamp,
    constraint fk_sitioweb_marca foreign key (idmarcaia) references marcaia(idmarcaia),
    constraint fk_sitioweb_pais foreign key (idpais) references pais(idpais),
    constraint fk_sitioweb_moneda foreign key (monedaoperacion) references moneda(codigomoneda),
    constraint ck_sitioweb_estado check (estado in ('activo', 'cerrado', 'mantenimiento'))
);

create table if not exists clientefinal (
    idclientefinal bigint auto_increment primary key,
    nombrecompleto varchar(120) not null,
    correo varchar(150) not null unique,
    telefono varchar(30),
    direccionentrega varchar(220) not null,
    idpais bigint not null,
    fecharegistro timestamp not null default current_timestamp,
    fechamodificacion timestamp not null default current_timestamp on update current_timestamp,
    constraint fk_clientefinal_pais foreign key (idpais) references pais(idpais)
);

create table if not exists ordenventa (
    idordenventa bigint auto_increment primary key,
    codigoordenventa varchar(40) not null unique,
    idsitioweb bigint not null,
    idclientefinal bigint not null,
    codigomoneda char(3) not null,
    fechaorden datetime not null,
    estadoorden varchar(20) not null,
    totalmonedalocal decimal(16,4) not null,
    totalimpuesto decimal(16,4) not null,
    costoshipping decimal(16,4) not null,
    permisosanitario decimal(16,4) not null,
    observaciones varchar(500),
    fechacreacion timestamp not null default current_timestamp,
    fechamodificacion timestamp not null default current_timestamp on update current_timestamp,
    constraint fk_ordenventa_sitio foreign key (idsitioweb) references sitioweb(idsitioweb),
    constraint fk_ordenventa_cliente foreign key (idclientefinal) references clientefinal(idclientefinal),
    constraint fk_ordenventa_moneda foreign key (codigomoneda) references moneda(codigomoneda),
    constraint ck_ordenventa_montos check (totalmonedalocal >= 0 and totalimpuesto >= 0 and costoshipping >= 0 and permisosanitario >= 0),
    constraint ck_ordenventa_estado check (estadoorden in ('creada', 'pagada', 'preparando', 'despachada', 'entregada', 'cancelada'))
);

create table if not exists ordenventadetalle (
    idordenventadetalle bigint auto_increment primary key,
    idordenventa bigint not null,
    codigoproductoetheria varchar(20) not null,
    nombreproductomarca varchar(180) not null,
    cantidad decimal(14,2) not null,
    preciounitariolocal decimal(16,4) not null,
    subtotal decimal(16,4) generated always as (cantidad * preciounitariolocal) stored,
    constraint fk_ordenventadetalle_orden foreign key (idordenventa) references ordenventa(idordenventa),
    constraint uk_ordenventadetalle unique (idordenventa, codigoproductoetheria),
    constraint ck_ordenventadetalle_cantidad check (cantidad > 0)
);

create table if not exists courierexterno (
    idcourierexterno bigint auto_increment primary key,
    nombrecourier varchar(120) not null,
    paisoperacion varchar(80) not null,
    nivelservicio varchar(40) not null,
    activo tinyint(1) not null default 1,
    fechamodificacion timestamp not null default current_timestamp on update current_timestamp,
    constraint uk_courier unique (nombrecourier, paisoperacion),
    constraint ck_courier_nivel check (nivelservicio in ('estandar', 'express', 'premium'))
);

create table if not exists despacho (
    iddespacho bigint auto_increment primary key,
    idordenventa bigint not null,
    idcourierexterno bigint not null,
    codigoguia varchar(60) not null unique,
    fechasalida datetime not null,
    fechallegadapais datetime,
    fechaentrega datetime,
    estadodespacho varchar(20) not null,
    costocourierlocal decimal(16,4) not null,
    observacion varchar(500),
    fechamodificacion timestamp not null default current_timestamp on update current_timestamp,
    constraint fk_despacho_orden foreign key (idordenventa) references ordenventa(idordenventa),
    constraint fk_despacho_courier foreign key (idcourierexterno) references courierexterno(idcourierexterno),
    constraint uk_despacho_orden unique (idordenventa),
    constraint ck_despacho_costo check (costocourierlocal >= 0),
    constraint ck_despacho_estado check (estadodespacho in ('saliohub', 'enaduana', 'entransito', 'entregado', 'incidencia'))
);

create table if not exists despachoseguimiento (
    idseguimiento bigint auto_increment primary key,
    iddespacho bigint not null,
    estadodespacho varchar(20) not null,
    comentario varchar(500),
    fechaseguimiento timestamp not null default current_timestamp,
    constraint fk_despachoseguimiento_despacho foreign key (iddespacho) references despacho(iddespacho),
    constraint uk_despachoseguimiento unique (iddespacho, estadodespacho, comentario),
    constraint ck_despachoseguimiento_estado check (estadodespacho in ('saliohub', 'enaduana', 'entransito', 'entregado', 'incidencia'))
);

create table if not exists costositio (
    idcostositio bigint auto_increment primary key,
    idsitioweb bigint not null,
    tipocosto varchar(40) not null,
    montolocal decimal(16,4) not null,
    fechaaplicacion date not null,
    observacion varchar(500),
    fechamodificacion timestamp not null default current_timestamp on update current_timestamp,
    constraint fk_costositio_sitio foreign key (idsitioweb) references sitioweb(idsitioweb),
    constraint ck_costositio_monto check (montolocal >= 0),
    constraint uk_costositio unique (idsitioweb, fechaaplicacion, tipocosto)
);

create table if not exists logcargaproceso (
    idlogcargaproceso bigint auto_increment primary key,
    modulo varchar(50) not null,
    tablaobjetivo varchar(80) not null,
    paso varchar(120) not null,
    estado varchar(20) not null,
    filasafectadas int,
    mensaje text,
    fecharegistro timestamp not null default current_timestamp,
    constraint ck_log_estado check (estado in ('iniciado', 'ok', 'error'))
);

create index ix_sitioweb_pais on sitioweb(idpais);
create index ix_ordenventa_fecha on ordenventa(fechaorden);
create index ix_ordenventa_estado on ordenventa(estadoorden);
create index ix_ordenventadetalle_producto on ordenventadetalle(codigoproductoetheria);
create index ix_despacho_estado on despacho(estadodespacho);
create index ix_despachoseguimiento_fecha on despachoseguimiento(fechaseguimiento);
create index ix_log_fecha on logcargaproceso(fecharegistro);
