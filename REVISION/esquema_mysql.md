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
- idpais PK: bigint AUTO_INCREMENT
- codigopaisiso UK: char(2) NOT NULL
- nombrepais UK: varchar(80) NOT NULL
- codigomoneda: char(3) NOT NULL  -- mismo comentario que el otro modelo
- monedaoficial: varchar(50) NOT NULL
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp

### marcaia, -- necesitas mas informacion, vos no estas haciendo el sistema que genera los sitos, ese existe, vos lo que tenes son los sitios hechos con sus tiendas
- idmarcaia PK: bigint AUTO_INCREMENT
- nombremarca UK: varchar(120) NOT NULL
- enfoqueprincipal: varchar(120) NOT NULL
- descripcionmarca: text
- estado: varchar(20) NOT NULL, CHECK (estado IN ('activa', 'inactiva', 'pausada'))
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp

### sitioweb -- FK a monedas, metele un config json, logo, brand, 
- idsitioweb PK: bigint AUTO_INCREMENT
- codigositio UK: varchar(40) NOT NULL
- idmarcaia FK(marcaia): bigint NOT NULL
- idpais FK(pais): bigint NOT NULL
- dominioweb UK: varchar(180) NOT NULL
- idioma: varchar(20) NOT NULL
- monedaoperacion: char(3) NOT NULL
- estado: varchar(20) NOT NULL, CHECK (estado IN ('activo', 'cerrado', 'mantenimiento'))
- fechainicio: date NOT NULL
- fechacierre: date

### clientefinal, un cliente puede tener N direcciones, modelo de direciones
- idclientefinal PK: bigint AUTO_INCREMENT
- nombrecompleto: varchar(120) NOT NULL
- correo UK: varchar(150) NOT NULL
- telefono: varchar(30)
- direccionentrega: varchar(220) NOT NULL
- idpais FK(pais): bigint NOT NULL
- fecharegistro: timestamp NOT NULL, DEFAULT current_timestamp

### ordenventa -- normalizar estadoorden, asociar a monedas asociar a impuestos, asociar a costos y ahi si esta bien sumar , observaciones que no sea text
- idordenventa PK: bigint AUTO_INCREMENT
- codigoordenventa UK: varchar(40) NOT NULL
- idsitioweb FK(sitioweb): bigint NOT NULL
- idclientefinal FK(clientefinal): bigint NOT NULL
- fechaorden: datetime NOT NULL
- estadoorden: varchar(20) NOT NULL, CHECK (estadoorden IN ('creada', 'pagada', 'preparando', 'despachada', 'entregada', 'cancelada'))
- totalmonedalocal: decimal(16,4) NOT NULL
- totalimpuesto: decimal(16,4) NOT NULL
- costoshipping: decimal(16,4) NOT NULL
- permisosanitario: decimal(16,4) NOT NULL
- observaciones: text
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp

### ordenventadetalle, has olvidado info de audit en todas las tablas, no asocies a codigos de la otra db , no los tenes son independientes, marcas debe estar normalizado asociado a tienda y eso lo sabe el producto. No olvides que un mismo producto se puede vender con diferentes marcas y precios caracteristias en las tiendas, y que esos precios cambian con el tiempo. Agrega caracteristicas variables a los productos. 
- idordenventadetalle PK: bigint AUTO_INCREMENT
- idordenventa UK, FK(ordenventa): bigint NOT NULL
- codigoproductoetheria UK: varchar(20) NOT NULL
- nombreproductomarca: varchar(180) NOT NULL
- cantidad: decimal(14,2) NOT NULL, CHECK (cantidad > 0)
- preciounitariolocal: decimal(16,4) NOT NULL
- subtotal: decimal(16,4) NOT NULL

### courierexterno
- idcourierexterno PK: bigint AUTO_INCREMENT
- nombrecourier UK: varchar(120) NOT NULL
- paisoperacion UK: varchar(80) NOT NULL
- nivelservicio: varchar(40) NOT NULL -- normalizar
- activo: tinyint(1) NOT NULL, DEFAULT 1

### despacho, -- esto diseñarlo como patron de transacciones o logs similar, para que sea de inserts del tracking y no de update
- iddespacho PK: bigint AUTO_INCREMENT
- idordenventa FK(ordenventa): bigint NOT NULL
- idcourierexterno FK(courierexterno): bigint NOT NULL
- codigoguia UK: varchar(60) NOT NULL
- fechasalida: datetime NOT NULL
- fechallegadapais: datetime
- fechaentrega: datetime
- estadodespacho: varchar(20) NOT NULL, CHECK (estadodespacho IN ('saliohub', 'enaduana', 'entransito', 'entregado', 'incidencia'))
- costocourierlocal: decimal(16,4) NOT NULL
- observacion: text

### costositio, -- out of scope
- idcostositio PK: bigint AUTO_INCREMENT
- idsitioweb UK, FK(sitioweb): bigint NOT NULL
- tipocosto UK: varchar(40) NOT NULL
- montolocal: decimal(16,4) NOT NULL
- fechaaplicacion UK: date NOT NULL
- observacion: text

### logcargaproceso  -- patron de logs mejor
- idlogcargaproceso PK: bigint AUTO_INCREMENT
- modulo: varchar(50) NOT NULL
- tablaobjetivo: varchar(80) NOT NULL
- paso: varchar(120) NOT NULL
- estado: varchar(20) NOT NULL, CHECK (estado IN ('iniciado', 'ok', 'error'))
- filasafectadas: int
- mensaje: text
- fecharegistro: timestamp NOT NULL, DEFAULT current_timestamp

#### Índices
- ix_sitioweb_pais → sitioweb(idpais)
- ix_ordenventa_fecha → ordenventa(fechaorden)
- ix_ordenventa_estado → ordenventa(estadoorden)
- ix_ordenventadetalle_producto → ordenventadetalle(codigoproductoetheria)
- ix_despacho_estado → despacho(estadodespacho)
- ix_log_fecha → logcargaproceso(fecharegistro)