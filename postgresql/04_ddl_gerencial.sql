set search_path = public;

create schema if not exists gerencial;

create table if not exists gerencial.ventaunificada (
    idventaunificada bigserial primary key,
    fechaorden date not null,
    fechacarga timestamp not null default now(),
    codigopaisiso char(2) not null,
    nombrepais varchar(80) not null,
    idsitioweb bigint not null,
    codigositio varchar(40) not null,
    nombremarca varchar(120) not null,
    codigoordenventa varchar(40) not null,
    codigoproducto varchar(20) not null,
    nombreproducto varchar(160) not null,
    nombrecategoria varchar(80) not null,
    cantidad numeric(14,2) not null,
    preciounitariolocal numeric(16,4) not null,
    subtotalmonedalocal numeric(16,4) not null,
    totalimpuesto numeric(16,4) not null,
    costoshippinglocal numeric(16,4) not null,
    permisosanitariolocal numeric(16,4) not null,
    costocourierlocal numeric(16,4) not null,
    tasacambio numeric(16,6) not null,
    ingresousd numeric(16,4) not null,
    costoproductousd numeric(16,4) not null,
    costosimportacionusd numeric(16,4) not null,
    costoslogisticosusd numeric(16,4) not null,
    costototalusd numeric(16,4) not null,
    margenusd numeric(16,4) not null,
    margenporcentaje numeric(8,2) not null,
    unique (codigoordenventa, codigoproducto)
);

create index if not exists ix_ventaunificada_fecha on gerencial.ventaunificada(fechaorden);
create index if not exists ix_ventaunificada_categoria on gerencial.ventaunificada(nombrecategoria);
create index if not exists ix_ventaunificada_pais on gerencial.ventaunificada(codigopaisiso);
create index if not exists ix_ventaunificada_marca on gerencial.ventaunificada(nombremarca);
