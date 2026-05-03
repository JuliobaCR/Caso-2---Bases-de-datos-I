SET search_path TO etheria;

-- 1. Catalogos base: moneda, pais
CALL etheria.sp_cargarpaisesbase();

-- 2. Catalogos operativos: categoria, tipousoproducto, tipoatributoproducto,
--    proveedor, estadoimportacion, tipomovimientoinventario, tipocostoimportacion, requisitolegal
CALL etheria.sp_cargarcatalogosbase();

-- 3. Tipo de cambio: debe ir antes de importaciones para que los detalles resuelvan la tasa vigente
CALL etheria.sp_cargartipocambiodemo();

-- 4. Productos base y sus atributos
CALL etheria.sp_cargarproductosbase(100);

-- 5. Importaciones, lotes, detalles, costos y movimientos de entrada
CALL etheria.sp_cargarimportacionesdemo(20);
