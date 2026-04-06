-- Consultas para alimentar dashboard gerencial en Postgres

-- 1) Rentabilidad por categoria
select * from gerencial.vistarentabilidadcategoria;

-- 2) Efectividad de marcas IA
select * from gerencial.vistaefectividadmarca;

-- 3) Margen por pais
select * from gerencial.vistamargenpais;

-- 4) Comparacion compra (USD) vs venta (USD) por producto
select * from gerencial.vistacomparacioncompraventaproducto;

-- 5) Top 20 combinaciones pais-sitio con mayor margen
select
    codigopaisiso,
    nombrepais,
    codigositio,
    nombremarca,
    round(sum(ingresousd), 2) as ingresousd,
    round(sum(costototalusd), 2) as costototalusd,
    round(sum(margenusd), 2) as margenusd,
    round(avg(margenporcentaje), 2) as margenporcentaje
from gerencial.ventaunificada
group by codigopaisiso, nombrepais, codigositio, nombremarca
order by margenusd desc
limit 20;

-- 6) Eficiencia logistica por pais
select
    codigopaisiso,
    nombrepais,
    round(sum(costoslogisticosusd), 2) as costoslogisticosusd,
    round(sum(ingresousd), 2) as ingresousd,
    round((sum(costoslogisticosusd) / nullif(sum(ingresousd), 0)) * 100, 2) as pesologistico_porcentaje
from gerencial.ventaunificada
group by codigopaisiso, nombrepais
order by pesologistico_porcentaje desc;
