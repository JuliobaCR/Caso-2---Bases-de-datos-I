-- Validaciones para demostrar que los datos unificados responden preguntas gerenciales

-- A. Rentabilidad de una categoria con costo en USD y venta en monedas locales
select
    nombrecategoria,
    round(sum(ingresousd), 2) as ingresototalusd,
    round(sum(costototalusd), 2) as costototalusd,
    round(sum(margenusd), 2) as margentotalusd,
    round((sum(margenusd) / nullif(sum(ingresousd), 0)) * 100, 2) as margenporcentaje
from gerencial.ventaunificada
where nombrecategoria = 'aceites'
group by nombrecategoria;

-- B. Marca IA mas efectiva contra costos
select
    nombremarca,
    round(sum(ingresousd), 2) as ingresousd,
    round(sum(costototalusd), 2) as costototalusd,
    round(sum(margenusd), 2) as margenusd,
    round(avg(margenporcentaje), 2) as margenpromedioporcentaje
from gerencial.ventaunificada
group by nombremarca
order by margenusd desc;

-- C. Margen por pais incluyendo shipping y permisos
select
    codigopaisiso,
    nombrepais,
    round(sum(ingresousd), 2) as ingresousd,
    round(sum(costoslogisticosusd), 2) as costoslogisticosusd,
    round(sum(costototalusd), 2) as costototalusd,
    round(sum(margenusd), 2) as margenusd
from gerencial.ventaunificada
group by codigopaisiso, nombrepais
order by margenusd desc;

-- D. Insumo para consultas de lenguaje natural (vista denormalizada)
select
    fechaorden,
    nombrepais,
    codigositio,
    nombremarca,
    nombrecategoria,
    codigoproducto,
    nombreproducto,
    ingresousd,
    costototalusd,
    margenusd,
    margenporcentaje
from gerencial.ventaunificada
order by fechaorden desc
limit 100;
