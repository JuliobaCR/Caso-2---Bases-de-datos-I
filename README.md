# Caso #2 - Bases de datos I

## Integrantes
- Completar con nombres y usuarios GitHub de la pareja.

## Contexto del caso
Este repositorio implementa una solucion integrada para:
- Etheria Global (PostgreSQL): abastecimiento, importacion, inventario y costos en USD.
- Dynamic Brands (MySQL): sitios dinamicos, marcas IA, ventas en moneda local y despacho.

La solucion unifica ambas fuentes en un esquema gerencial en PostgreSQL para medir rentabilidad real, efectividad de marcas y margen por pais.

## Principios de diseno aplicados
- Nombres en espanol, minuscula y pegados.
- Separacion por dominios operativos (PostgreSQL y MySQL) y capa analitica unificada.
- Carga de datos por stored procedures transaccionales con manejo de excepciones.
- Logging central de ejecuciones por motor con SP independiente de auditoria.
- Estructura preparada para crecimiento futuro (mas paises, mas marcas, mas monedas).

## Estructura del repositorio
- `postgresql/01_ddl_etheria.sql`: DDL operativo Etheria + restricciones + indices.
- `postgresql/02_sp_etheria.sql`: SP transaccionales de carga y logging.
- `postgresql/03_seed_orquestacion_etheria.sql`: orquestacion de carga Etheria.
- `postgresql/04_ddl_gerencial.sql`: tabla de hechos unificada para dashboard.
- `postgresql/05_vistas_kpi.sql`: vistas KPI gerenciales.
- `mysql/01_ddl_dynamic.sql`: DDL operativo Dynamic Brands.
- `mysql/02_sp_dynamic.sql`: SP transaccionales de carga y logging.
- `mysql/03_seed_orquestacion_dynamic.sql`: orquestacion de carga Dynamic.
- `integracion/python/etl_unificacion.py`: ETL MySQL -> PostgreSQL (tabla gerencial).
- `dashboard/sql/consultas_dashboard.sql`: consultas listas para dashboard.
- `integracion/sql/consultas_unificacion_validacion.sql`: validaciones gerenciales.
- `docs/esquema_postgresql.md`: documentacion del esquema PostgreSQL.
- `docs/esquema_mysql.md`: documentacion del esquema MySQL.
- `docs/diagramas/erd_postgresql.mmd`: diagrama ERD PostgreSQL (Mermaid).
- `docs/diagramas/erd_mysql.mmd`: diagrama ERD MySQL (Mermaid).
- `docs/diagramas/como_exportar_pdf.md`: guia para exportar ERD a PDF.
- `docker-compose.yml`: despliegue completo con un comando.
- `docker/etl.Dockerfile`: imagen para el proceso de ETL.

## Cobertura de requerimientos del enunciado
1. Esquemas y restricciones en Markdown:
	- `docs/esquema_postgresql.md`
	- `docs/esquema_mysql.md`
2. Scripts SQL de PostgreSQL y MySQL:
	- Carpeta `postgresql/`
	- Carpeta `mysql/`
3. Diagramas de ambas bases:
	- Fuente Mermaid en `docs/diagramas/`
	- Exportables a PDF segun `docs/diagramas/como_exportar_pdf.md`
4. Carga de datos por SP transaccionales:
	- PostgreSQL: `postgresql/02_sp_etheria.sql`
	- MySQL: `mysql/02_sp_dynamic.sql`
5. SP independiente de logging:
	- PostgreSQL: `etheria.sp_registrarlogcarga`
	- MySQL: `sp_registrarlogcarga`
6. Minimos de data:
	- 5 paises: cargados en ambos motores.
	- 100 productos: `sp_cargarproductosbase(100)` en PostgreSQL.
	- 9 sitios dinamicos: `sp_cargarmarcasysitios()` en MySQL.
7. Solucion de integracion de datos:
	- ETL Python en `integracion/python/etl_unificacion.py`
	- Carga de tabla unificada `gerencial.ventaunificada`
8. Dashboard gerencial:
	- Vistas KPI en PostgreSQL + consultas en `dashboard/sql/consultas_dashboard.sql`
9. Proyecto contenedorizado:
	- Todo se ejecuta con `docker compose up --build`

## Arquitectura tecnica
1. PostgreSQL (`etheria`): origen de costos de importacion, inventario, tipo de cambio y catalogo base.
2. MySQL (`dynamicbrands`): origen de demanda digital, sitios, ordenes, detalle y courier.
3. ETL (`etl_unificacion`): extrae ventas de MySQL, enriquece con costos/tipo de cambio en PostgreSQL y consolida en `gerencial.ventaunificada`.
4. Dashboard (`metabase`): consume vistas KPI desde PostgreSQL.

## Ejecucion del proyecto
### Levantar todo
```bash
docker compose up --build
```

### Accesos
- PostgreSQL:
  - Host: `localhost`
  - Puerto: `5432`
  - DB: `etheria`
  - User: `etheria_user`
  - Password: `etheria_pass`
- MySQL:
  - Host: `localhost`
  - Puerto: `3306`
  - DB: `dynamicbrands`
  - User: `dynamic_user`
  - Password: `dynamic_pass`
- Metabase:
  - URL: `http://localhost:3000`

### Volver a ejecutar ETL manualmente
```bash
docker compose run --rm etl_unificacion
```

## Evidencia de analitica gerencial
### Pregunta 1: rentabilidad real por categoria (costos USD vs ventas moneda local)
Usar vista: `gerencial.vistarentabilidadcategoria`

### Pregunta 2: marca IA mas efectiva frente a costos de importacion
Usar vista: `gerencial.vistaefectividadmarca`

### Pregunta 3: margen por pais incluyendo shipping y permisos
Usar vista: `gerencial.vistamargenpais`

### Pregunta 4: comparacion compra vs venta por producto
Usar vista: `gerencial.vistacomparacioncompraventaproducto`

Consultas listas en:
- `dashboard/sql/consultas_dashboard.sql`
- `integracion/sql/consultas_unificacion_validacion.sql`

## Estrategia para hoy y para futuro
1. Hoy:
	- Integracion por ETL batch determinista, repetible y auditable.
	- Tabla unificada denormalizada para dashboard y respuesta rapida.
2. Futuro:
	- Programar ETL incremental por ventana de fechas y CDC.
	- Agregar historico de tasas de cambio intradia.
	- Implementar capa semantica para consultas en lenguaje natural.
	- Exponer metadatos de negocio para BI asistido por IA.

## Consultas en lenguaje natural (vision futura)
El modelo ya deja una base adecuada porque:
- `gerencial.ventaunificada` concentra dimensiones y metricas en una sola entidad analitica.
- Las vistas KPI encapsulan reglas de negocio reutilizables.
- El diccionario de nombres en espanol ayuda a mapear prompts de negocio hacia SQL.

## Control de calidad recomendado antes de entrega
1. Ejecutar `docker compose down -v`.
2. Ejecutar `docker compose up --build`.
3. Confirmar en PostgreSQL:
	- `select count(*) from etheria.pais;` debe ser 5.
	- `select count(*) from etheria.productobase;` debe ser 100.
4. Confirmar en MySQL:
	- `select count(*) from sitioweb;` debe ser 9.
5. Ejecutar ETL y validar:
	- `select count(*) from gerencial.ventaunificada;` mayor que 0.
6. Validar vistas KPI desde Metabase o SQL.

## Nota de entrega academica
La fecha/hora de finalizacion se valida con el ultimo commit del repositorio. Registrar aportes de ambos integrantes durante el desarrollo para la revision con el profesor.