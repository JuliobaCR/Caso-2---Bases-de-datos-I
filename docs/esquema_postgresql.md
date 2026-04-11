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
- idpais PK: bigserial
- codigopaisiso UK: char(2) NOT NULL
- nombrepais UK: varchar(80) NOT NULL
- codigomoneda: char(3) NOT NULL
- monedaoficial: varchar(50) NOT NULL
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()

### categoria
- idcategoria PK: bigserial
- nombrecategoria UK: varchar(80) NOT NULL
- descripcion: text
- fechacreacion: timestamp NOT NULL, DEFAULT now()

### proveedor
- idproveedor PK: bigserial
- nombreproveedor UK: varchar(120) NOT NULL
- paisorigen UK: varchar(80) NOT NULL
- correocontacto: varchar(120)
- telefonocontacto: varchar(30)
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()

### productobase
- idproductobase PK: bigserial
- codigoproducto UK: varchar(20) NOT NULL
- nombreproducto: varchar(160) NOT NULL
- idcategoria FK(categoria): bigint NOT NULL
- tipouso: varchar(30) NOT NULL, CHECK (tipouso IN ('ingesta', 'piel', 'capilar', 'aromaterapia', 'mixto'))
- unidadmedida: varchar(20) NOT NULL
- ingredientebase: varchar(200)
- beneficiosalud: varchar(500)
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()

### productopais
- idproductopais PK: bigserial
- idproductobase UK, FK(productobase): bigint NOT NULL
- idpaisdestino UK, FK(pais): bigint NOT NULL
- codigosanitario: varchar(60)
- requierepermiso: boolean NOT NULL, DEFAULT true
- restricciones: text
- fechavigencia: date NOT NULL, DEFAULT current_date
- activo: boolean NOT NULL, DEFAULT true

### requisitolegal
- idrequisitolegal PK: bigserial
- nombrerequisito UK: varchar(120) NOT NULL
- entidadreguladora UK: varchar(120) NOT NULL
- descripcion: text
- obligatorio: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()

### requisitoproductopais
- idrequisitopp PK: bigserial
- idproductopais UK, FK(productopais.): bigint NOT NULL
- idrequisitolegal UK, FK(requisitolegal): bigint NOT NULL
- detalleaplicacion: text
- fechacreacion: timestamp NOT NULL, DEFAULT now()

### importacion
- idimportacion PK: bigserial
- codigoimportacion UK: varchar(30) NOT NULL
- idproveedor FK(proveedor): bigint NOT NULL
- estadoimportacion: varchar(20) NOT NULL, CHECK (estadoimportacion IN ('pedido', 'transito', 'recibido', 'cerrado'))
- fechapedido: date NOT NULL
- fechallegadacaribe: date
- observaciones: text
- fechacreacion: timestamp NOT NULL, DEFAULT now()

### importaciondetalle
- idimportaciondetalle PK: bigserial
- idimportacion UK, FK(importacion): bigint NOT NULL
- idproductobase UK, FK(productobase): bigint NOT NULL
- cantidadbulk: numeric(14,2) NOT NULL, CHECK (cantidadbulk > 0)
- costounitariousd: numeric(14,4) NOT NULL, CHECK (costounitariousd > 0)
- subtotalusd: numeric(16,4) GENERATED ALWAYS AS (cantidadbulk * costounitariousd) STORED
- fechacreacion: timestamp NOT NULL, DEFAULT now()

### loteinventario
- idloteinventario PK: bigserial
- codigolote UK: varchar(40) NOT NULL
- idimportaciondetalle FK(importaciondetalle): bigint NOT NULL
- cantidadinicial: numeric(14,2) NOT NULL, CHECK (cantidadinicial > 0)
- cantidaddisponible: numeric(14,2) NOT NULL, CHECK (cantidaddisponible >= 0)
- fechavencimiento: date
- estado: varchar(20) NOT NULL, CHECK (estado IN ('disponible', 'reservado', 'agotado', 'vencido'))
- fechacreacion: timestamp NOT NULL, DEFAULT now()

### movimientosinventario
- idmovimiento PK: bigserial
- idloteinventario FK(loteinventario): bigint NOT NULL
- tipomovimiento: varchar(20) NOT NULL, CHECK (tipomovimiento IN ('entrada', 'salida', 'ajuste'))
- origenmovimiento: varchar(30) NOT NULL
- cantidad: numeric(14,2) NOT NULL, CHECK (cantidad > 0)
- referenciaexterna: varchar(80)
- observacion: text
- fechamovimiento: timestamp NOT NULL, DEFAULT now()

### costosimportacion
- idcostoimportacion PK: bigserial
- idimportacion FK(importacion): bigint NOT NULL
- tipocosto: varchar(30) NOT NULL, CHECK (tipocosto IN ('flete', 'seguro', 'arancel', 'agenciaaduanal', 'almacenaje', 'otro'))
- montousd: numeric(14,4) NOT NULL, CHECK (montousd >= 0)
- descripcion: text
- fecharegistro: timestamp NOT NULL, DEFAULT now()

### ordenabastecimiento
- idordenabastecimiento PK: bigserial
- codigoorden UK: varchar(40) NOT NULL
- idpaisdestino FK(pais): bigint NOT NULL
- nombresitioexterno: varchar(120) NOT NULL
- idmarcaexterna: bigint NOT NULL
- estadoorden: varchar(20) NOT NULL, CHECK (estadoorden IN ('creada', 'preparacion', 'despachada', 'cerrada', 'cancelada'))
- fechaorden: timestamp NOT NULL, DEFAULT now()
- observaciones: text

### ordenabastecimientodetalle
- idordenabdetalle PK: bigserial
- idordenabastecimiento UK, FK(ordenabastecimiento): bigint NOT NULL
- idproductobase UK, FK(productobase): bigint NOT NULL
- cantidadsolicitada: numeric(14,2) NOT NULL, CHECK (cantidadsolicitada > 0)
- cantidadasignada: numeric(14,2) NOT NULL, DEFAULT 0, CHECK (cantidadasignada >= 0)
- preciosalidamonedalocal: numeric(14,4) NOT NULL, DEFAULT 0

### etiquetadomarca
- idetiquetadomarca PK: bigserial
- idordenabdetalle FK(ordenabastecimientodetalle): bigint NOT NULL
- codigobarrainterno UK: varchar(40) NOT NULL
- marcaprint: varchar(100) NOT NULL
- enfoquepublicitario: varchar(120)
- fecharegistro: timestamp NOT NULL, DEFAULT now()

### tipocambio
- idtipocambio PK: bigserial
- idpais UK, FK(pais): bigint NOT NULL
- fechatasa UK: date NOT NULL
- tasausdmonedalocal: numeric(14,6) NOT NULL, CHECK (tasausdmonedalocal > 0)
- fuente: varchar(80) NOT NULL
- fechacreacion: timestamp NOT NULL, DEFAULT now()

### logcargaproceso
- idlogcargaproceso PK: bigserial
- modulo: varchar(50) NOT NULL
- tablaobjetivo: varchar(80) NOT NULL
- paso: varchar(120) NOT NULL
- estado: varchar(20) NOT NULL, CHECK (estado IN ('iniciado', 'ok', 'error'))
- filasafectadas: integer
- mensaje: text
- fecharegistro: timestamp NOT NULL, DEFAULT now()

#### Índices
- ix_productobase_categoria → productobase(idcategoria)
- ix_productopais_pais → productopais(idpaisdestino)
- ix_importacion_estado → importacion(estadoimportacion)
- ix_loteinventario_estado → loteinventario(estado)
- ix_tipocambio_fechatasa → tipocambio(fechatasa)
- ix_logcargaproceso_fecha → logcargaproceso(fecharegistro)

## Tablas analiticas (schema gerencial)

### ventaunificada
- idventaunificada PK: bigserial
- fechaorden: date NOT NULL
- fechacarga: timestamp NOT NULL, DEFAULT now()
- codigopaisiso: char(2) NOT NULL
- nombrepais: varchar(80) NOT NULL
- idsitioweb: bigint NOT NULL
- codigositio: varchar(40) NOT NULL
- nombremarca: varchar(120) NOT NULL
- codigoordenventa UK: varchar(40) NOT NULL
- codigoproducto UK: varchar(20) NOT NULL
- nombreproducto: varchar(160) NOT NULL
- nombrecategoria: varchar(80) NOT NULL
- cantidad: numeric(14,2) NOT NULL
- preciounitariolocal: numeric(16,4) NOT NULL
- subtotalmonedalocal: numeric(16,4) NOT NULL
- totalimpuesto: numeric(16,4) NOT NULL
- costoshippinglocal: numeric(16,4) NOT NULL
- permisosanitariolocal: numeric(16,4) NOT NULL
- costocourierlocal: numeric(16,4) NOT NULL
- tasacambio: numeric(16,6) NOT NULL
- ingresousd: numeric(16,4) NOT NULL
- costoproductousd: numeric(16,4) NOT NULL
- costosimportacionusd: numeric(16,4) NOT NULL
- costoslogisticosusd: numeric(16,4) NOT NULL
- costototalusd: numeric(16,4) NOT NULL
- margenusd: numeric(16,4) NOT NULL
- margenporcentaje: numeric(8,2) NOT NULL

#### Índices
- ix_ventaunificada_fecha → fechaorden
- ix_ventaunificada_categoria → nombrecategoria
- ix_ventaunificada_pais → codigopaisiso
- ix_ventaunificada_marca → nombremarca