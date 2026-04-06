set search_path = public;

call etheria.sp_cargarpaisesbase();
call etheria.sp_cargarcatalogosbase();
call etheria.sp_cargarproductosbase(100);
call etheria.sp_cargarimportacionesdemo(20);
call etheria.sp_cargartipocambiodemo();
