# Esquema MySQL - Dynamic Brands

## Motor y alcance
- Motor: MySQL 8.4
- Base de datos: dynamicbrands
- Enfoque: marcas generadas por IA, sitios dinamicos, ventas y despacho por pais

## Criterios de diseno aplicados
- Nombres en espanol, minuscula y pegados.
- Modelo multisitio y multipais bajo una sola plataforma.
- Trazabilidad por orden y despacho.
- Estructura preparada para apertura/cierre de tiendas por temporada.

## Tablas principales

### pais
- PK: idpais
- UK: codigopaisiso, nombrepais
- Campos clave: codigomoneda, monedaoficial

### marcaia
- PK: idmarcaia
- UK: nombremarca
- Campos clave: enfoquemarketing, estado

### sitioweb
- PK: idsitioweb
- UK: codigositio, dominioweb
- FK: idmarcaia -> marcaia
- FK: idpais -> pais
- Campos clave: monedaoperacion, idioma, estado, fechainicio, fechacierre

### clientefinal
- PK: idclientefinal
- UK: correo
- FK: idpais -> pais

### ordenventa
- PK: idordenventa
- UK: codigoordenventa
- FK: idsitioweb -> sitioweb
- FK: idclientefinal -> clientefinal
- Campos clave: totalmonedalocal, totalimpuesto, costoshipping, permisosanitario

### ordenventadetalle
- PK: idordenventadetalle
- UK: idordenventa + codigoproductoetheria
- FK: idordenventa -> ordenventa
- Integracion: codigoproductoetheria referencia logica hacia Etheria
- Campos clave: cantidad, preciounitariolocal, subtotal

### courierexterno
- PK: idcourierexterno
- UK: nombrecourier + paisoperacion

### despacho
- PK: iddespacho
- UK: codigoguia
- FK: idordenventa -> ordenventa
- FK: idcourierexterno -> courierexterno
- Campos clave: fechas de salida/llegada/entrega, estadodespacho, costocourierlocal

### costositio
- PK: idcostositio
- UK: idsitioweb + fechaaplicacion + tipocosto
- FK: idsitioweb -> sitioweb

### logcargaproceso
- PK: idlogcargaproceso
- Campos clave: modulo, tablaobjetivo, paso, estado, filasafectadas, mensaje

## Scripts relacionados
- mysql/01_ddl_dynamic.sql
- mysql/02_sp_dynamic.sql
- mysql/03_seed_orquestacion_dynamic.sql
