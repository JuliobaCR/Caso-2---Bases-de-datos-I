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

## Ajustes incorporados
- Catalogo `moneda` y llaves foraneas en `pais`, `sitioweb` y `ordenventa`.
- `sitioweb` incluye `configuracionjson` para metadatos del sitio.
- `ordenventadetalle.subtotal` ahora se calcula de forma generada para evitar inconsistencias.
- `despachoseguimiento` guarda historial de estados y el seed es idempotente.
- Observaciones operativas acotadas a longitud fija en lugar de texto libre donde aplica.

## Tablas principales

### moneda
- idmoneda PK: bigint AUTO_INCREMENT
- codigoisomoneda UK: char(3) NOT NULL
- nombremoneda UK: varchar(80) NOT NULL
- simbolo: varchar(10) NOT NULL
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### pais
- idpais PK: bigint AUTO_INCREMENT
- codigopaisiso UK: char(2) NOT NULL
- nombrepais UK: varchar(80) NOT NULL
- idmoneda FK(moneda): bigint NOT NULL
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### marcaia
- idmarcaia PK: bigint AUTO_INCREMENT
- nombremarca UK: varchar(120) NOT NULL
- estado: varchar(20) NOT NULL, CHECK (estado IN ('activa', 'inactiva'))
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### idioma
- ididioma PK: bigint AUTO_INCREMENT
- codigoidioma UK: char(5) NOT NULL  -- es-CR, en-US
- nombreidioma UK: varchar(80) NOT NULL
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### sitioweb
- idsitioweb PK: bigint AUTO_INCREMENT
- codigositio UK: varchar(40) NOT NULL
- idmarcaia FK(marcaia): bigint NOT NULL
- idpais FK(pais): bigint NOT NULL
- dominioweb UK: varchar(180) NOT NULL
- ididioma FK(idioma): bigint NOT NULL
- idmoneda FK(moneda): bigint NOT NULL
- urllogo: varchar(500) NOT NULL
- urlbrand: varchar(500) NOT NULL
- configjson: json
- estado: varchar(20) NOT NULL, CHECK (estado IN ('activo', 'cerrado', 'mantenimiento'))
- fechainicio: date NOT NULL
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### clientefinal
- idclientefinal PK: bigint AUTO_INCREMENT
- nombrecompleto: varchar(120) NOT NULL
- correo UK: varchar(150) NOT NULL
- telefono: varchar(30)
- fecharegistro: timestamp NOT NULL, DEFAULT current_timestamp

### direccioncliente
- iddireccioncliente PK: bigint AUTO_INCREMENT
- idclientefinal FK(clientefinal): bigint NOT NULL
- idpais FK(pais): bigint NOT NULL
- alias: varchar(60) NOT NULL  -- ej: "casa", "oficina"
- nombrecompleto: varchar(120) NOT NULL  -- destinatario puede diferir del cliente
- telefono: varchar(30)
- lineadireccion1: varchar(220) NOT NULL  -- calle, número, apto
- lineadireccion2: varchar(220)  -- urbanización, barrio, referencias
- ciudad: varchar(100) NOT NULL
- estadoprovincia: varchar(100) NOT NULL
- codigopostal: varchar(20)  -- nullable, no todos los paises lo usan
- predeterminada: tinyint(1) NOT NULL, DEFAULT 0
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp
- UK(idclientefinal, iddireccioncliente)

### estadoorden
- idestadoorden PK: bigint AUTO_INCREMENT
- codigo UK: varchar(20) NOT NULL  -- creada, pagada, preparando, despachada, entregada, cancelada
- descripcion: varchar(120) NOT NULL
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### tipoimpuesto
- idtipoimpuesto PK: bigint AUTO_INCREMENT
- idpais FK(pais): bigint NOT NULL
- nombreimpuesto: varchar(80) NOT NULL  -- IVA, ISR, etc.
- porcentaje: decimal(6,4) NOT NULL
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### tipocostoorden
- idtipocostoorden PK: bigint AUTO_INCREMENT
- nombrecosto UK: varchar(80) NOT NULL  -- shipping, permisosanitario, etc.
- descripcion: varchar(220)
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### ordenventa
- idordenventa PK: bigint AUTO_INCREMENT
- codigoordenventa UK: varchar(40) NOT NULL
- idsitioweb FK(sitioweb): bigint NOT NULL
- idclientefinal FK(clientefinal): bigint NOT NULL
- iddireccioncliente FK: bigint NOT NULL
- CONSTRAINT fk_orden_direccion FOREIGN KEY (idclientefinal, iddireccioncliente) REFERENCES direccioncliente(idclientefinal, iddireccioncliente)
- fechaorden: datetime NOT NULL
- idestadoorden FK(estadoorden): bigint NOT NULL
- idmoneda FK(moneda): bigint NOT NULL
- totalbruto: decimal(16,4) NOT NULL
- totalimpuesto: decimal(16,4) NOT NULL
- totalcostos: decimal(16,4) NOT NULL
- totalneto: decimal(16,4) NOT NULL
- observaciones: varchar(300)
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### costoorden
- idcostoorden PK: bigint AUTO_INCREMENT
- idordenventa FK(ordenventa): bigint NOT NULL
- idtipocostoorden FK(tipocostoorden): bigint NOT NULL
- monto: decimal(16,4) NOT NULL
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp

//Tablas relacionadas a los productos y como pueden representarse de forma diferente dependiendo el sitio
### producto
- idproducto PK: bigint AUTO_INCREMENT
- nombreproducto UK: varchar(180) NOT NULL
- descripcion: varchar(500)
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### productositio
- idproductositio PK: bigint AUTO_INCREMENT
- idproducto FK(producto): bigint NOT NULL
- idsitioweb FK(sitioweb): bigint NOT NULL
- idmarcaia FK(marcaia): bigint NOT NULL
- nombrecomercial: varchar(180) NOT NULL  -- nombre del producto en esa tienda
- activo: tinyint(1) NOT NULL, DEFAULT 1
- UK(idproducto, idsitioweb)
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### preciohistoricoproducto
- idpreciohistorico PK: bigint AUTO_INCREMENT
- idproductositio FK(productositio): bigint NOT NULL
- idmoneda FK(moneda): bigint NOT NULL
- precio: decimal(16,4) NOT NULL
- fechadesde: date NOT NULL
- fechahasta: date  -- NULL significa precio vigente
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp

### tipocaracteristica
- idtipocaracteristica PK: bigint AUTO_INCREMENT
- nombrecaracteristica UK: varchar(80) NOT NULL  -- talla, color, peso
- unidadmedida: varchar(20)  -- kg, cm, NULL si no aplica
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### caracteristicaproducto
- idcaracteristicaproducto PK: bigint AUTO_INCREMENT
- idproductositio FK(productositio): bigint NOT NULL
- idtipocaracteristica FK(tipocaracteristica): bigint NOT NULL
- valor: varchar(120) NOT NULL  -- "XL", "Rojo", "2.5"
- UK(idproductositio, idtipocaracteristica)
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### ordenventadetalle
- idordenventadetalle PK: bigint AUTO_INCREMENT
- idordenventa FK(ordenventa): bigint NOT NULL
- idproductositio FK(productositio): bigint NOT NULL
- idpreciohistorico FK(preciohistoricoproducto): bigint NOT NULL
- cantidad: decimal(14,2) NOT NULL, CHECK (cantidad > 0)
- preciounitariolocal: decimal(16,4) NOT NULL
- subtotal: decimal(16,4) NOT NULL
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp
//Termina las tablas relacionadas al producto

### nivelserviciocourier
- idnivelservicio PK: bigint AUTO_INCREMENT
- nombrenivelservicio UK: varchar(80) NOT NULL  -- express, estandar, economico
- descripcion: varchar(220)
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### courierexterno
- idcourierexterno PK: bigint AUTO_INCREMENT
- nombrecourier UK: varchar(120) NOT NULL
- idpais FK(pais): bigint NOT NULL
- idnivelservicio FK(nivelserviciocourier): bigint NOT NULL
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

### despacho
- iddespacho PK: bigint AUTO_INCREMENT
- idordenventa FK(ordenventa): bigint NOT NULL
- idcourierexterno FK(courierexterno): bigint NOT NULL
- codigoguia UK: varchar(60) NOT NULL
- costocourierlocal: decimal(16,4) NOT NULL
- idmoneda FK(moneda): bigint NOT NULL
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp

//estado despacho normalizado
### estadodespacho
- idestadodespacho PK: bigint AUTO_INCREMENT
- codigo UK: varchar(20) NOT NULL  -- saliohub, enaduana, entransito, entregado, incidencia
- descripcion: varchar(120) NOT NULL
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp
- fechamodificacion: timestamp NULL, ON UPDATE current_timestamp

//Tabla de inserts de despachos que funciona como logs
### trackingdespacho
- idtrackingdespacho PK: bigint AUTO_INCREMENT
- iddespacho FK(despacho): bigint NOT NULL
- idestadodespacho FK(estadodespacho): bigint NOT NULL
- ubicacion: varchar(220)  -- ciudad, aduana, bodega, etc.
- observacion: varchar(500)
- fechaevento: datetime NOT NULL
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp

//Tabla de logs
### logcargaproceso
- idlogcargaproceso PK: bigint AUTO_INCREMENT
- modulo: varchar(50) NOT NULL
- tablaobjetivo: varchar(80) NOT NULL
- paso: varchar(120) NOT NULL
- estado: varchar(20) NOT NULL, CHECK (estado IN ('iniciado', 'ok', 'error'))
- filasafectadas: int
- duracionms: int  -- duración del paso en milisegundos
- idreferencia: bigint  -- ID del registro afectado, nullable
- mensaje: varchar(500)
- fecharegistro: timestamp NOT NULL, DEFAULT current_timestamp

#### Índices
- ix_sitioweb_pais → sitioweb(idpais)
- ix_sitioweb_marca → sitioweb(idmarcaia)
- ix_ordenventa_fecha → ordenventa(fechaorden)
- ix_ordenventa_estado → ordenventa(idestadoorden)
- ix_ordenventa_cliente → ordenventa(idclientefinal)
- ix_ordenventadetalle_producto → ordenventadetalle(idproductositio)
- ix_productositio_sitio → productositio(idsitioweb)
- ix_preciohistorico_producto → preciohistoricoproducto(idproductositio)
- ix_trackingdespacho_despacho → trackingdespacho(iddespacho)
- ix_trackingdespacho_estado → trackingdespacho(idestadodespacho)
- ix_trackingdespacho_fecha → trackingdespacho(fechaevento)
- ix_log_fecha → logcargaproceso(fecharegistro)
- ix_log_modulo → logcargaproceso(modulo)