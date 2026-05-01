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

## Ajustes incorporados
- Catalogo `moneda` y FK desde `pais` para mantener consistencia monetaria.
- `productobase` incluye `atributosjsonb` para caracteristicas variables.
- `movimientosinventario` guarda saldo final y se registra con procedimiento transaccional.
- `costosimportacion` incorpora metadatos para soportar costos fijos o porcentuales.
- La carga de inventario usa lotes con saldo controlado para evitar duplicar estados.

## Tablas operativas (schema etheria)

### moneda
- idmoneda PK: bigserial
- codigoisomoneda UK: char(3) NOT NULL
- nombremoneda UK: varchar(80) NOT NULL
- simbolo: varchar(10) NOT NULL
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

### pais
- idpais PK: bigserial
- codigopaisiso UK: char(2) NOT NULL
- nombrepais UK: varchar(80) NOT NULL
- idmoneda FK(moneda): bigint NOT NULL
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

### categoria
- idcategoria PK: bigserial
- nombrecategoria UK: varchar(80) NOT NULL
- descripcion: varchar(500)
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

### proveedor
- idproveedor PK: bigserial
- nombreproveedor UK: varchar(120) NOT NULL
- idpais FK(pais): bigint NOT NULL
- correocontacto: varchar(120)
- telefonocontacto: varchar(30)
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

//Normalizar los tipos de uso
### tipousoproducto
- idtipousobase PK: bigserial
- nombretipousobase UK: varchar(80) NOT NULL  -- ingesta, piel, capilar, aromaterapia, mixto
- descripcion: varchar(220)
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

//Tabla para atributos variables (ingredientes, beneficios, ...)
### tipoatributoproducto
- idtipoatributo PK: bigserial
- nombreatributo UK: varchar(80) NOT NULL  -- ingrediente, beneficio, contraindicacion
- unidadmedida: varchar(20)  -- NULL si no aplica
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

//Se normalizan los atributos y los tipos de uso
### productobase
- idproductobase PK: bigserial
- codigoproducto UK: varchar(20) NOT NULL
- nombreproducto: varchar(160) NOT NULL
- idcategoria FK(categoria): bigint NOT NULL
- idtipousobase FK(tipousoproducto): bigint NOT NULL
- unidadmedida: varchar(20) NOT NULL
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

### atributoproductobase
- idatributoproductobase PK: bigserial
- idproductobase FK(productobase): bigint NOT NULL
- idtipoatributo FK(tipoatributoproducto): bigint NOT NULL
- valor: varchar(220) NOT NULL  -- "Aloe Vera", "Hidratacion profunda", etc.
- UK(idproductobase, idtipoatributo)
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

//Codigos sanitarios normalizados para las configuraciones de profuctos por categoria
### codigosanitario (nueva)
- idcodigosanitario PK: bigserial
- idpais FK(pais): bigint NOT NULL
- codigo UK: varchar(60) NOT NULL
- entidademisora: varchar(120) NOT NULL  -- MINSA, COFEPRIS, INVIMA, etc.
- urldocumento: varchar(500)
- fechaemision: date
- fechavencimiento: date
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

//Hace la regulacion por categoria de productos en cada pais
### configuracionregulatoriacategoria (reemplaza productopais)
- idconfigregulatoria PK: bigserial
- idcategoria FK(categoria): bigint NOT NULL
- idpais FK(pais): bigint NOT NULL
- idcodigosanitario FK(codigosanitario): bigint
- requierepermiso: boolean NOT NULL, DEFAULT true
- fechavigencia: date NOT NULL, DEFAULT current_date
- activo: boolean NOT NULL, DEFAULT true
- UK(idcategoria, idpais)
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

### requisitolegal
- idrequisitolegal PK: bigserial
- idpais FK(pais): bigint NOT NULL
- nombrerequisito: varchar(120) NOT NULL
- entidadreguladora: varchar(120) NOT NULL
- urldocumento: varchar(500)
- obligatorio: boolean NOT NULL, DEFAULT true
- UK(idpais, nombrerequisito)
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

//Maneja los requisitos legales necesarios por configuracion
### requisitosporconfiguracion
- idconfigrequisito PK: bigserial
- idconfigregulatoria FK(configuracionregulatoriacategoria): bigint NOT NULL
- idrequisitolegal FK(requisitolegal): bigint NOT NULL
- UK(idconfigregulatoria, idrequisitolegal)
- fechacreacion: timestamp NOT NULL, DEFAULT now()

//Normaliza los estados de una importacion
### estadoimportacion
- idestadoimportacion PK: bigserial
- codigo UK: varchar(20) NOT NULL  -- pedido, transito, recibido, cerrado
- descripcion: varchar(120) NOT NULL
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

//Normaliza los codigos aduanales por pais
### codigoaduanal
- idcodigoaduanal PK: bigserial
- idpais FK(pais): bigint NOT NULL
- idcategoria FK(categoria): bigint NOT NULL
- codigo UK: varchar(30) NOT NULL  -- codigo arancelario HS
- descripcion: varchar(220) NOT NULL
- activo: boolean NOT NULL, DEFAULT true
- UK(idpais, idcategoria)
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

### importacion
- idimportacion PK: bigserial
- idproveedor FK(proveedor): bigint NOT NULL
- idestadoimportacion FK(estadoimportacion): bigint NOT NULL
- idcodigoaduanal FK(codigoaduanal): bigint NOT NULL
- fechapedido: date NOT NULL
- fechallegadacaribe: date
- observaciones: varchar(500)
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

//Maneja tasas de cambio entre 2 monedas
### tipocambio
- idtipocambio PK: bigserial
- idmonedabase FK(moneda): bigint NOT NULL      -- moneda origen, ej: USD
- idmonedadestino FK(moneda): bigint NOT NULL   -- moneda destino, ej: CRC
- tasa: numeric(14,6) NOT NULL, CHECK (tasa > 0)
- fuente: varchar(80) NOT NULL
- fechadesde: date NOT NULL
- fechahasta: date                              -- NULL significa tasa vigente
- UK(idmonedabase, idmonedadestino, fechadesde)
- fechacreacion: timestamp NOT NULL, DEFAULT now()

### loteinventario
- idloteinventario PK: bigserial
- codigolote UK: varchar(40) NOT NULL
- idproductobase FK(productobase): bigint NOT NULL
- cantidadinicial: numeric(14,2) NOT NULL, CHECK (cantidadinicial > 0)
- fechavencimiento: date
- fechacreacion: timestamp NOT NULL, DEFAULT now()

//Tabla con los tipos de movimientos de un lote.
### tipomovimientoinventario
- idtipomovimiento PK: bigserial
- codigo UK: varchar(20) NOT NULL  -- entrada, salida, ajuste
- descripcion: varchar(120) NOT NULL
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

//Se deja de depender del usd, se calcula el total del origen y del destino.
### importaciondetalle
- idimportaciondetalle PK: bigserial
- idimportacion UK(idimportacion, idloteinventario), FK(importacion): bigint NOT NULL
- idloteinventario UK(idimportacion, idloteinventario), FK(loteinventario): bigint NOT NULL
- idtipocambio FK(tipocambio): bigint NOT NULL  -- contiene par de monedas y tasa del momento
- tasacambio: numeric(14,6) NOT NULL            -- tasa guardada en el momento de la transaccion
- costounitariobase: numeric(14,4) NOT NULL, CHECK (costounitariobase > 0)
- subtotalbase: numeric(16,4) NOT NULL
- costounitariolocal: numeric(14,4) NOT NULL
- subtotallocal: numeric(16,4) NOT NULL
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

### movimientosinventario
- idmovimiento PK: bigserial
- idloteinventario FK(loteinventario): bigint NOT NULL
- idtipomovimiento FK(tipomovimientoinventario): bigint NOT NULL
- origenmovimiento: varchar(30) NOT NULL
- cantidad: numeric(14,2) NOT NULL, CHECK (cantidad > 0)
- referenciaexterna: varchar(80)
- observacion: varchar(500)
- fechamovimiento: timestamp NOT NULL, DEFAULT now()
- fechacreacion: timestamp NOT NULL, DEFAULT now()

//Tabla con tipos de costo en la importacion con fechas de vigencia
### tipocostoimportacion (corregida)
- idtipocosto PK: bigserial
- nombrecosto: varchar(80) NOT NULL  -- flete, seguro, arancel, agenciaaduanal, almacenaje, otro
- UK(nombrecosto, fechadesde)
- descripcion: varchar(220)
- esporcentaje: boolean NOT NULL, DEFAULT false  -- true = %, false = flat
- valor: numeric(14,4) NOT NULL, CHECK (valor >= 0)  -- monto flat o porcentaje segun esporcentaje
- fechadesde: date NOT NULL
- fechahasta: date                              -- NULL significa vigente
- activo: boolean NOT NULL, DEFAULT true
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

### costosimportacion
- idcostoimportacion PK: bigserial
- idimportacion FK(importacion): bigint NOT NULL
- idtipocosto FK(tipocostoimportacion): bigint NOT NULL
- idtipocambio FK(tipocambio): bigint NOT NULL
- tasacambio: numeric(14,6) NOT NULL
- valorlocal: numeric(14,4) NOT NULL  -- valor convertido a moneda local en el momento
- fechacreacion: timestamp NOT NULL, DEFAULT now()

//Asociada con importacion (funciona como orden)
### etiquetadomarca
- idetiquetadomarca PK: bigserial
- idimportacion FK(importacion): bigint NOT NULL
- idproductobase FK(productobase): bigint NOT NULL
- codigobarrainterno UK: varchar(40) NOT NULL
- marcaprint: varchar(100) NOT NULL
- enfoquepublicitario: varchar(120)
- fechacreacion: timestamp NOT NULL, DEFAULT now()
- fechamodificacion: timestamp NULL

//Patron de logs
### logcargaproceso
- idlogcargaproceso PK: bigserial
- modulo: varchar(50) NOT NULL
- tablaobjetivo: varchar(80) NOT NULL
- paso: varchar(120) NOT NULL
- estado: varchar(20) NOT NULL, CHECK (estado IN ('iniciado', 'ok', 'error'))
- filasafectadas: integer
- duracionms: integer  -- duracion del paso en milisegundos
- idreferencia: bigint  -- ID del registro afectado, nullable
- mensaje: varchar(500)
- fecharegistro: timestamp NOT NULL, DEFAULT now()

#### Índices
- ix_productobase_categoria → productobase(idcategoria)
- ix_productobase_tipousobase → productobase(idtipousobase)
- ix_proveedor_pais → proveedor(idpais)
- ix_importacion_proveedor → importacion(idproveedor)
- ix_importacion_estado → importacion(idestadoimportacion)
- ix_importacion_codigoaduanal → importacion(idcodigoaduanal)
- ix_importaciondetalle_lote → importaciondetalle(idloteinventario)
- ix_loteinventario_producto → loteinventario(idproductobase)
- ix_loteinventario_vencimiento → loteinventario(fechavencimiento)
- ix_movimientos_lote → movimientosinventario(idloteinventario)
- ix_movimientos_fecha → movimientosinventario(fechamovimiento)
- ix_tipocambio_monedas → tipocambio(idmonedabase, idmonedadestino)
- ix_tipocambio_vigente → tipocambio(idmonedabase, idmonedadestino, fechahasta)
- ix_configregulatoria_pais → configuracionregulatoriacategoria(idpais)
- ix_requisitolegal_pais → requisitolegal(idpais)
- ix_logcargaproceso_fecha → logcargaproceso(fecharegistro)
- ix_logcargaproceso_modulo → logcargaproceso(modulo)

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
- codigoordenventa: varchar(40) NOT NULL
- codigoproducto: varchar(20) NOT NULL
- UK(codigoordenventa, codigoproducto)
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
- ix_ventaunificada_fecha → ventaunificada(fechaorden)
- ix_ventaunificada_categoria → ventaunificada(nombrecategoria)
- ix_ventaunificada_pais → ventaunificada(codigopaisiso)
- ix_ventaunificada_marca → ventaunificada(nombremarca)