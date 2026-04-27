# Etheria Global & Dynamic Brands Group
**Caso #2 — Bases de Datos I**  
**Profesor: Rodrigo Núñez**

---

## Descripción del proyecto

Sistema integrado y contenedorizado que conecta dos empresas del mismo holding:

- **Etheria Global** — gestión de importación, inventario y costos en USD (PostgreSQL 16)
- **Dynamic Brands** — ventas digitales con marcas blancas generadas por IA en múltiples países (MySQL 8.4)

Un proceso ETL cruza ambas fuentes y consolida los datos en un esquema gerencial (`gerencial.ventaunificada`) que alimenta un dashboard de rentabilidad en Metabase.

Además, se incorporaron varias mejoras recomendadas en la carpeta `REVISION/`: catálogo de monedas, atributos variables de producto, historial de despacho, validaciones más estrictas e idempotencia en los seeds.

---

## Estructura del repositorio

```
proyecto/
├── docker-compose.yml
├── docker/
│   └── etl.Dockerfile
├── docs/
│   ├── esquema_postgresql.md
│   └── esquema_mysql.md
├── diagramas/
│   ├── erd_etheria_postgresql.pdf
│   └── erd_dynamicbrands_mysql.pdf
├── postgresql/
│   ├── 01_ddl_etheria.sql
│   ├── 02_sp_etheria.sql
│   ├── 03_seed_orquestacion_etheria.sql
│   ├── 04_ddl_gerencial.sql
│   └── 05_vistas_kpi.sql
├── mysql/
│   ├── 01_ddl_dynamic.sql
│   ├── 02_sp_dynamic.sql
│   └── 03_seed_orquestacion_dynamic.sql
├── integracion/
│   ├── python/
│   │   ├── etl_unificacion.py
│   │   └── requirements.txt
│   └── sql/
│       └── consultas_unificacion_validacion.sql
└── dashboard/
    └── consultas_dashboard.sql
```

---

## Requisitos previos

- Docker Desktop instalado y corriendo
- Puertos disponibles: `5432`, `3306`, `3000`

---

## Levantar el proyecto

```bash
docker compose up --build
```

Este único comando levanta:
- PostgreSQL 16 con los esquemas `etheria` y `gerencial` ya creados y con datos
- MySQL 8.4 con el esquema `dynamicbrands` ya creado y con datos
- El ETL que cruza ambas fuentes y puebla `gerencial.ventaunificada`
- Metabase en `http://localhost:3000` para el dashboard gerencial

Si necesitan resetear todo desde cero:

```bash
docker compose down -v
docker compose up --build
```

---

## Credenciales

| Servicio | Host | Puerto | Base | Usuario | Contraseña |
|---|---|---|---|---|---|
| PostgreSQL | localhost | 5432 | etheria | etheria_user | etheria_pass |
| MySQL | localhost | 3306 | dynamicbrands | dynamic_user | dynamic_pass |
| Metabase | localhost | 3000 | — | configurar al inicio | — |

---

## Datos de prueba cargados

| Dato | Cantidad |
|---|---|
| Países | 5 (Nicaragua, Colombia, Perú, Costa Rica, México) |
| Categorías | 5 (aceites, bebidas, alimentos, cosmética, jabonería) |
| Proveedores | 5 |
| Productos base | 100 (PRD0001 a PRD0100) |
| Marcas IA | 3 (auraviva, nativaflux, dermaterra) |
| Sitios web | 9 (3 marcas × 3 países cada una) |
| Órdenes de venta | 120 |
| Importaciones | 20 |

---

## Opción 1 — Dashboard en Metabase

1. Abrir `http://localhost:3000`
2. Crear cuenta administrador de Metabase
3. Agregar conexión PostgreSQL:
   - Host: `postgres_etheria`
   - Puerto: `5432`
   - Base de datos: `etheria`
   - Usuario: `etheria_user`
   - Contraseña: `etheria_pass`
4. Agregar conexión MySQL:
   - Host: `mysql_dynamic`
   - Puerto: `3306`
   - Base de datos: `dynamicbrands`
   - Usuario: `dynamic_user`
   - Contraseña: `dynamic_pass`
5. Crear nueva pregunta → SQL nativo → seleccionar conexión PostgreSQL
6. Pegar cada consulta del archivo `dashboard/consultas_dashboard.sql`
7. Guardar cada consulta y agregarla al dashboard gerencial

### Indicadores disponibles en el dashboard

| Consulta | Indicador |
|---|---|
| 1 | Rentabilidad por categoría |
| 2 | Efectividad de marcas IA |
| 3 | Margen por país |
| 4 | Comparación precio compra vs venta por producto |
| 5 | Top 20 combinaciones país-sitio con mayor margen |
| 6 | Eficiencia logística por país |

---

## Opción 2 — Consultas directas por Query Tool

Conectarse a PostgreSQL con cualquier cliente SQL (pgAdmin, DBeaver, psql) usando las credenciales de la tabla anterior.

### Vistas KPI disponibles (esquema gerencial)

```sql
-- Rentabilidad por categoría
select * from gerencial.vistarentabilidadcategoria;

-- Efectividad de marcas IA
select * from gerencial.vistaefectividadmarca;

-- Margen por país
select * from gerencial.vistamargenpais;

-- Comparación compra vs venta por producto
select * from gerencial.vistacomparacioncompraventaproducto;
```

### Consultas de validación de integración

Las consultas del archivo `integracion/sql/consultas_unificacion_validacion.sql` demuestran que los datos unificados responden las preguntas gerenciales del caso:

```sql
-- A. Rentabilidad de una categoría con costo en USD y venta en moneda local
-- B. Marca IA más efectiva contra costos de importación
-- C. Margen por país incluyendo shipping y permisos sanitarios
-- D. Vista plana para consultas en lenguaje natural
```

---

## Preguntas gerenciales que el sistema responde

| Pregunta | Cómo se responde |
|---|---|
| ¿Cuál es la rentabilidad real de una categoría si el costo es en USD y la venta en moneda local? | `vistarentabilidadcategoria` — convierte todo a USD usando `tipocambio` |
| ¿Qué marca generada por IA es más efectiva comparada con costos de importación? | `vistaefectividadmarca` — cruza ventas de MySQL con costos de PostgreSQL |
| ¿Cuál es el margen por país considerando gastos de envío y permisos? | `vistamargenpais` — incluye `costoshippinglocal`, `permisosanitariolocal` y `costocourierlocal` |

---

## ¿Funciona con consultas en lenguaje natural?

Sí. La tabla `gerencial.ventaunificada` es una tabla de hechos denormalizada — todos los campos relevantes están en una sola fila sin necesidad de joins. Esto la hace compatible con herramientas de consulta en lenguaje natural basadas en LLMs, ya que el modelo puede generar SQL directamente sobre una estructura plana. La consulta D en `integracion/sql/consultas_unificacion_validacion.sql` muestra la estructura disponible para ese propósito.

---

## Scripts SQL por motor

### PostgreSQL — orden de ejecución
| Archivo | Contenido |
|---|---|
| `01_ddl_etheria.sql` | Esquema `etheria` con 17 tablas |
| `02_sp_etheria.sql` | Stored Procedures con manejo de excepciones y SP de logging |
| `03_seed_orquestacion_etheria.sql` | Orquestación del llenado de datos |
| `04_ddl_gerencial.sql` | Tabla `gerencial.ventaunificada` |
| `05_vistas_kpi.sql` | 4 vistas gerenciales de KPI |

### MySQL — orden de ejecución
| Archivo | Contenido |
|---|---|
| `01_ddl_dynamic.sql` | Esquema `dynamicbrands` con 9 tablas |
| `02_sp_dynamic.sql` | Stored Procedures con manejo de excepciones y SP de logging |
| `03_seed_orquestacion_dynamic.sql` | Orquestación del llenado de datos |

---

## ETL — Integración entre motores

El archivo `integracion/python/etl_unificacion.py` realiza las siguientes operaciones:

1. Lee todas las órdenes entregadas desde MySQL (`ordenventa`, `ordenventadetalle`, `despacho`)
2. Por cada línea de venta, consulta en PostgreSQL el producto (`productobase`) y su costo de importación (`importaciondetalle`)
3. Obtiene la tasa de cambio vigente desde `etheria.tipocambio` para convertir moneda local a USD
4. Calcula `ingresousd`, `costoproductousd`, `costosimportacionusd`, `costoslogisticosusd`, `costototalusd`, `margenusd` y `margenporcentaje`
5. Inserta el resultado en `gerencial.ventaunificada` — si ya existe la combinación `(codigoordenventa, codigoproducto)` actualiza el registro

La columna de integración entre ambos motores es `codigoproductoetheria` en MySQL, que referencia lógicamente a `codigoproducto` en `etheria.productobase`.
