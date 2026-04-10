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
- codigomoneda: char(3) NOT NULL
- monedaoficial: varchar(50) NOT NULL
- activo: tinyint(1) NOT NULL, DEFAULT 1
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp

### marcaia
- idmarcaia PK: bigint AUTO_INCREMENT
- nombremarca UK: varchar(120) NOT NULL
- enfoqueprincipal: varchar(120) NOT NULL
- descripcionmarca: text
- estado: varchar(20) NOT NULL, CHECK (estado IN ('activa', 'inactiva', 'pausada'))
- fechacreacion: timestamp NOT NULL, DEFAULT current_timestamp

### sitioweb
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

### clientefinal
- idclientefinal PK: bigint AUTO_INCREMENT
- nombrecompleto: varchar(120) NOT NULL
- correo UK: varchar(150) NOT NULL
- telefono: varchar(30)
- direccionentrega: varchar(220) NOT NULL
- idpais FK(pais): bigint NOT NULL
- fecharegistro: timestamp NOT NULL, DEFAULT current_timestamp

### ordenventa
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

### ordenventadetalle
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
- nivelservicio: varchar(40) NOT NULL
- activo: tinyint(1) NOT NULL, DEFAULT 1

### despacho
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

### costositio
- idcostositio PK: bigint AUTO_INCREMENT
- idsitioweb UK, FK(sitioweb): bigint NOT NULL
- tipocosto UK: varchar(40) NOT NULL
- montolocal: decimal(16,4) NOT NULL
- fechaaplicacion UK: date NOT NULL
- observacion: text

### logcargaproceso
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