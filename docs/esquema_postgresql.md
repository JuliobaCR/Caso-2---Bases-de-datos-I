# Esquema PostgreSQL - Etheria Global

## Motor y alcance
- Motor: PostgreSQL 16
- Esquema principal: etheria
- Esquema analitico: gerencial
- Enfoque: abastecimiento, importacion, inventario, cumplimiento regulatorio y costos en USD

## Criterios de diseno aplicados
- Nombres en espanol, minuscula y pegados.
- Integridad referencial estricta por llaves foraneas.
- Restricciones check para estados de negocio.
- Trazabilidad por lote, movimiento y log de procesos.
- Indices para consultas de dashboard y operacion.

## Tablas operativas (schema etheria)

### pais
- PK: idpais
- UK: codigopaisiso, nombrepais
- Campos clave: codigomoneda, monedaoficial, activo

### categoria
- PK: idcategoria
- UK: nombrecategoria

### proveedor
- PK: idproveedor
- UK: nombreproveedor + paisorigen

### productobase
- PK: idproductobase
- UK: codigoproducto
- FK: idcategoria -> categoria
- Campos clave: tipouso, unidadmedida, ingredientebase, beneficiosalud

### productopais
- PK: idproductopais
- UK: idproductobase + idpaisdestino
- FK: idproductobase -> productobase
- FK: idpaisdestino -> pais
- Campos clave: codigosanitario, requierepermiso, restricciones

### requisitolegal
- PK: idrequisitolegal
- UK: nombrerequisito + entidadreguladora

### requisitoproductopais
- PK: idrequisitopp
- UK: idproductopais + idrequisitolegal
- FK: idproductopais -> productopais
- FK: idrequisitolegal -> requisitolegal

### importacion
- PK: idimportacion
- UK: codigoimportacion
- FK: idproveedor -> proveedor
- Campos clave: estadoimportacion, fechapedido, fechallegadacaribe

### importaciondetalle
- PK: idimportaciondetalle
- UK: idimportacion + idproductobase
- FK: idimportacion -> importacion
- FK: idproductobase -> productobase
- Campos clave: cantidadbulk, costounitariusd, subtotalusd (generado)

### loteinventario
- PK: idloteinventario
- UK: codigolote
- FK: idimportaciondetalle -> importaciondetalle
- Campos clave: cantidadinicial, cantidaddisponible, estado

### movimientosinventario
- PK: idmovimiento
- FK: idloteinventario -> loteinventario
- Campos clave: tipomovimiento, origenmovimiento, referenciaexterna

### costosimportacion
- PK: idcostoimportacion
- FK: idimportacion -> importacion
- Campos clave: tipocosto, montousd

### ordenabastecimiento
- PK: idordenabastecimiento
- UK: codigoorden
- FK: idpaisdestino -> pais
- Campos clave: nombresitioexterno, idmarcaexterna, estadoorden

### ordenabastecimientodetalle
- PK: idordenabdetalle
- UK: idordenabastecimiento + idproductobase
- FK: idordenabastecimiento -> ordenabastecimiento
- FK: idproductobase -> productobase

### etiquetadomarca
- PK: idetiquetadomarca
- UK: codigobarrainterno
- FK: idordenabdetalle -> ordenabastecimientodetalle

### tipocambio
- PK: idtipocambio
- UK: idpais + fechatasa
- FK: idpais -> pais
- Campo clave: tasausdmonedalocal

### logcargaproceso
- PK: idlogcargaproceso
- Campos clave: modulo, tablaobjetivo, paso, estado, filasafectadas, mensaje

## Tablas analiticas (schema gerencial)

### ventaunificada
- PK: idventaunificada
- Modelo: tabla de hechos denormalizada orientada al dashboard
- Campos clave:
  - contexto comercial: pais, sitio, marca
  - producto: codigoproducto, categoria
  - metricas locales y USD: ingresos, costos, shipping, permisos, courier
  - KPI de salida: margenusd, margenporcentaje

## Vistas gerenciales
- gerencial.vistarentabilidadcategoria
- gerencial.vistaefectividadmarca
- gerencial.vistamargenpais
- gerencial.vistacomparacioncompraventaproducto

## Scripts relacionados
- postgresql/01_ddl_etheria.sql
- postgresql/02_sp_etheria.sql
- postgresql/03_seed_orquestacion_etheria.sql
- postgresql/04_ddl_gerencial.sql
- postgresql/05_vistas_kpi.sql
