# RESUMEN DE CORRECCIONES - ETL Unificación

**Fecha:** 2026-05-01  
**Estado:** Correcciones completadas ✅  

## Resumen Ejecutivo

Se identificaron y corrigieron **3 problemas críticos** en el ETL que causaban cálculos incorrectos de márgenes y costos:

1. **Distribución de costos por línea de detalle** (MySQL)
2. **Cálculo de costo de importación por producto** (PostgreSQL)
3. **Replicación incorrecta de costos en Python**

---

## Detalle de Cambios

### Cambio 1: Distribución de costos en la consulta MySQL

**Archivo:** `integracion/python/etl_unificacion.py` (línea 59-89)

**Antes:**
```sql
ov.totalimpuesto,
ov.costoshipping,
ov.permisosanitario,
```
❌ Problema: Se replicaba el costo TOTAL para CADA línea de detalle


**Después:**
```sql
round(ov.totalimpuesto * (ovd.subtotal / ov.totalmonedalocal), 4) as totalimpuesto,
round(ov.costoshipping * (ovd.subtotal / ov.totalmonedalocal), 4) as costoshipping,
round(ov.permisosanitario * (ovd.subtotal / ov.totalmonedalocal), 4) as permisosanitario,
```
✅ Distribución proporcional: `costo_línea = costo_total × (subtotal_línea / total_orden)`

**Impacto:** 
- Orden con 2 líneas y impuesto total=10: Ahora asigna ~5 a cada línea (antes asignaba 10 a ambas)
- Los márgenes calculados ahora son realistas

---

### Cambio 2: Obtención de costo de importación específico por producto

**Archivo:** `integracion/python/etl_unificacion.py` (línea 107-126)

**Antes:**
```python
def obtener_costo_importacion_unitario(conn_pg):
    consulta = """
        select (sum(ci.montousd) / sum(idt.cantidadbulk))
        from etheria.costosimportacion ci
        inner join etheria.importaciondetalle idt
    """
```
❌ Problema: Calcula un promedio GLOBAL de todas las importaciones


**Después:**
```python
def obtener_costo_importacion_unitario(conn_pg, codigoproducto):
    """Obtiene el costo unitario más reciente del producto"""
    consulta = """
        select coalesce(idt.costounitariousd, 0)
        from etheria.importaciondetalle idt
        inner join etheria.importacion imp ...
        inner join etheria.productobase pb ...
        where pb.codigoproducto = %s
        order by imp.fechallegadacaribe desc, ...
        limit 1
    """
```
✅ Obtiene el costo específico del producto basado en la importación MÁS RECIENTE

**Impacto:**
- PRD0001 importado a $10 USD vs PRD0002 a $15 USD: Ahora tienen costos diferentes (antes igual)
- Los márgenes reflejan la realidad de cada producto

---

### Cambio 3: Integración en construir_ventas_unificadas()

**Archivo:** `integracion/python/etl_unificacion.py` (línea 165-209)

**Antes:**
```python
costo_importacion_unitario = obtener_costo_importacion_unitario(conn_pg)  # Una vez
for fila in filas_mysql:
    costosimportacionusd = costo_importacion_unitario * cantidad
```
❌ Mismo costo para todos los productos


**Después:**
```python
for fila in filas_mysql:
    costo_importacion_unitario = obtener_costo_importacion_unitario(
        conn_pg, fila["codigoproducto"]
    )  # Por cada línea
    costosimportacionusd = costo_importacion_unitario * cantidad
```
✅ Costo individual por producto en cada línea

---

## Datos Esperados

Después de las correcciones, los datos cargados en `gerencial.ventaunificada` deberán cumplir:

### Volumen
- **120 órdenes** → ~240-360 líneas de detalle (2-3 líneas por orden)
- **Cada línea de detalle** = 1 fila en ventaunificada

### Validaciones de Integridad

#### 1. Sin duplicados de costos
```sql
-- Verificación: Margen no debe ser excesivamente negativo o positivo
SELECT COUNT(*) FROM gerencial.ventaunificada 
WHERE margenporcentaje < -50 OR margenporcentaje > 100;
-- Esperado: Pocos resultados (órdenes excepcionales)
```

#### 2. Totales coherentes
```sql
SELECT 
    COUNT(*) as filas,
    SUM(ingresousd) as ingresos_total,
    SUM(costototalusd) as costos_total,
    SUM(margenusd) as margen_total,
    AVG(margenporcentaje) as margen_promedio
FROM gerencial.ventaunificada;

-- Esperado:
-- filas: 240-360
-- ingresos_total: ~$5,000-8,000 USD
-- costos_total: ~$2,000-4,000 USD
-- margen_total: ~$2,000-4,000 USD (positivo)
-- margen_promedio: 40-50% (rentabilidad)
```

#### 3. Distribución de costos coherente
```sql
SELECT 
    codigoordenventa,
    COUNT(*) as lineas,
    ROUND(SUM(totalimpuesto), 4) as imp_total,
    ROUND(SUM(costoshippinglocal), 4) as ship_total,
    ROUND(SUM(permisosanitariolocal), 4) as permiso_total
FROM gerencial.ventaunificada
GROUP BY codigoordenventa
HAVING COUNT(*) > 0
LIMIT 5;

-- Esperado: Costos distribuidos (no duplicados)
-- Si orden tiene totalimpuesto=10 y 2 líneas: cada línea debe tener ~5
```

---

## Pruebas Recomendadas

### 1. Ejecución del ETL
```bash
docker compose up --build
# Esperar a que se complete el ETL (debe decir ✅ ETL COMPLETADO EXITOSAMENTE)
```

### 2. Verificar datos cargados
```bash
# Conectarse a PostgreSQL
psql -h localhost -p 5432 -U etheria_user -d etheria

# Consultar datos
SELECT COUNT(*) as filas_cargadas FROM gerencial.ventaunificada;
SELECT * FROM gerencial.ventaunificada LIMIT 10;
```

### 3. Validar vistas KPI
```sql
-- Las 4 vistas deberían mostrar datos coherentes
SELECT * FROM gerencial.vistarentabilidadcategoria;
SELECT * FROM gerencial.vistaefectividadmarca;
SELECT * FROM gerencial.vistamargenpais;
SELECT * FROM gerencial.vistacomparacioncompraventaproducto;
```

---

## Archivos Modificados

1. ✅ `/integracion/python/etl_unificacion.py`
   - Función `cargar_ventas_mysql()` - Distribución de costos
   - Función `obtener_costo_importacion_unitario()` - Nueva lógica por producto
   - Función `construir_ventas_unificadas()` - Integración de cambios

## Archivos sin cambios necesarios

- ✅ `/postgresql/04_ddl_gerencial.sql` - Estructura correcta
- ✅ `/mysql/01_ddl_dynamic.sql` - Campos necesarios ya existen
- ✅ `/docker-compose.yml` - Configuración adecuada
- ✅ `/docker/etl.Dockerfile` - Importaciones correctas

---

## Next Steps

1. [ ] Ejecutar el proyecto con correcciones
2. [ ] Validar que las 240-360 filas se inserten correctamente
3. [ ] Verificar vistas KPI y márgenes
4. [ ] Configurar dashboard en Metabase
5. [ ] Ejecutar consultas de validación del README

---

**Nota:** Las correcciones mantienen compatibilidad con las estructuras de datos existentes. No requieren cambios en DDL ni en stored procedures.
