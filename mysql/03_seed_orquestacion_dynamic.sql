use dynamicbrands;

-- 1. Catalogos base: moneda, pais, idioma
call sp_cargarpaisesbase();

-- 2. Marcas, niveles de servicio courier y sitios web
call sp_cargarmarcasysitios();

-- 3. Catalogos operativos: estadoorden, estadodespacho, tipocostoorden, tipoimpuesto
CALL sp_cargarcatalogosoperacion();

-- 4. Clientes, productos, ordenes y despachos demo
call sp_cargarclientesyordenesdemo(120);
