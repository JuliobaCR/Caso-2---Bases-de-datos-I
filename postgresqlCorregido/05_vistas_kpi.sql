set search_path = public;

create or replace view gerencial.vistarentabilidadcategoria as
select
    nombrecategoria,
    count(distinct codigoordenventa) as totalordenes,
    sum(cantidad) as unidadesvendidas,
    round(sum(ingresousd), 2) as ingresototalusd,
    round(sum(costototalusd), 2) as costototalusd,
    round(sum(margenusd), 2) as margentotalusd,
    round((sum(margenusd) / nullif(sum(ingresousd), 0)) * 100, 2) as margenpromedioporcentaje
from gerencial.ventaunificada
group by nombrecategoria
order by margentotalusd desc;

create or replace view gerencial.vistaefectividadmarca as
select
    nombremarca,
    count(distinct codigositio) as totalsitios,
    count(distinct codigoordenventa) as totalordenes,
    round(sum(ingresousd), 2) as ingresototalusd,
    round(sum(margenusd), 2) as margentotalusd,
    round(avg(margenporcentaje), 2) as margenpromedioporcentaje
from gerencial.ventaunificada
group by nombremarca
order by margentotalusd desc;

create or replace view gerencial.vistamargenpais as
select
    codigopaisiso,
    nombrepais,
    count(distinct codigoordenventa) as totalordenes,
    round(sum(ingresousd), 2) as ingresototalusd,
    round(sum(costototalusd), 2) as costototalusd,
    round(sum(margenusd), 2) as margentotalusd,
    round((sum(margenusd) / nullif(sum(ingresousd), 0)) * 100, 2) as margenporcentual
from gerencial.ventaunificada
group by codigopaisiso, nombrepais
order by margentotalusd desc;

create or replace view gerencial.vistacomparacioncompraventaproducto as
select
    codigoproducto,
    nombreproducto,
    nombrecategoria,
    round(sum(cantidad), 2) as cantidadvendida,
    round(avg(costoproductousd), 4) as costopromediousd,
    round(avg(ingresousd / nullif(cantidad, 0)), 4) as precioventapromediousd,
    round(sum(ingresousd), 2) as ingresototalusd,
    round(sum(costototalusd), 2) as costototalusd,
    round(sum(margenusd), 2) as margentotalusd
from gerencial.ventaunificada
group by codigoproducto, nombreproducto, nombrecategoria
order by margentotalusd desc;
