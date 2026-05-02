import os
import time
from decimal import Decimal

import psycopg2
import pymysql
from psycopg2.extras import execute_values


def obtener_conexion_postgres(reintentos=20, espera=3):
    """Conecta a PostgreSQL con reintentos"""
    for intento in range(1, reintentos + 1):
        try:
            conn = psycopg2.connect(
                host=os.getenv("PG_HOST", "localhost"),
                port=int(os.getenv("PG_PORT", "5432")),
                dbname=os.getenv("PG_DB", "etheria"),
                user=os.getenv("PG_USER", "etheria_user"),
                password=os.getenv("PG_PASSWORD", "etheria_pass"),
            )
            print(f"✅ Conectado a PostgreSQL (intento {intento})")
            return conn
        except psycopg2.OperationalError as e:
            if intento < reintentos:
                print(f"⚠️ Error conectando PostgreSQL (intento {intento}/{reintentos}): {e}")
                print(f"   Esperando {espera}s...")
                time.sleep(espera)
            else:
                print(f"❌ No se pudo conectar a PostgreSQL después de {reintentos} intentos")
                raise


def obtener_conexion_mysql(reintentos=20, espera=3):
    """Conecta a MySQL con reintentos"""
    for intento in range(1, reintentos + 1):
        try:
            conn = pymysql.connect(
                host=os.getenv("MYSQL_HOST", "localhost"),
                port=int(os.getenv("MYSQL_PORT", "3306")),
                user=os.getenv("MYSQL_USER", "dynamic_user"),
                password=os.getenv("MYSQL_PASSWORD", "dynamic_pass"),
                database=os.getenv("MYSQL_DB", "dynamicbrands"),
                charset="utf8mb4",
                cursorclass=pymysql.cursors.DictCursor,
            )
            print(f"✅ Conectado a MySQL (intento {intento})")
            return conn
        except pymysql.MySQLError as e:
            if intento < reintentos:
                print(f"⚠️ Error conectando MySQL (intento {intento}/{reintentos}): {e}")
                print(f"   Esperando {espera}s...")
                time.sleep(espera)
            else:
                print(f"❌ No se pudo conectar a MySQL después de {reintentos} intentos")
                raise


def cargar_ventas_mysql(conn_mysql):
    """Extrae órdenes de venta desde MySQL"""
    consulta = """
        select
            date(ov.fechaorden) as fechaorden,
            p.codigopaisiso,
            p.nombrepais,
            s.idsitioweb,
            s.codigositio,
            m.nombremarca,
            ov.codigoordenventa,
            ov.totalimpuesto,
            ov.totalcostos,
            ovd.cantidad,
            ovd.preciounitariolocal,
            ovd.subtotal,
            ps.nombrecomercial as codigoproducto,
            ifnull(d.costocourierlocal, 0) as costocourierlocal
        from ordenventa ov
        inner join sitioweb s on s.idsitioweb = ov.idsitioweb
        inner join marcaia m on m.idmarcaia = s.idmarcaia
        inner join pais p on p.idpais = s.idpais
        inner join ordenventadetalle ovd on ovd.idordenventa = ov.idordenventa
        inner join productositio ps on ps.idproductositio = ovd.idproductositio
        left join despacho d on d.idordenventa = ov.idordenventa
        limit 500
    """
    with conn_mysql.cursor() as cursor:
        cursor.execute(consulta)
        return cursor.fetchall()


def obtener_contexto_producto(conn_pg, codigoproducto):
    """Obtiene información del producto desde PostgreSQL"""
    # Por ahora retorna valores por defecto
    return ("producto no mapeado", "sin categoria", Decimal("0"))


def obtener_tasa_cambio(conn_pg, codigopaisiso, fechaorden):
    """Obtiene la tasa de cambio USD a moneda local"""
    # Por ahora retorna 1.0 (1:1)
    return Decimal("1")


def construir_ventas_unificadas(filas_mysql, conn_pg):
    filas_unificadas = []

    for fila in filas_mysql:
        fechaorden = fila["fechaorden"]
        codigopaisiso = fila["codigopaisiso"]
        tasacambio = obtener_tasa_cambio(conn_pg, codigopaisiso, fechaorden)

        nombreproducto, nombrecategoria, costoproductousd = obtener_contexto_producto(
            conn_pg, fila["codigoproducto"]
        )

        cantidad = Decimal(str(fila["cantidad"]))
        subtotal_local = Decimal(str(fila["subtotal"]))
        impuesto_local = Decimal(str(fila["totalimpuesto"]))
        costos_local = Decimal(str(fila["totalcostos"]))
        courier_local = Decimal(str(fila["costocourierlocal"]))

        ingresousd = subtotal_local / tasacambio if tasacambio > 0 else Decimal("0")
        costoslogisticosusd = costos_local / tasacambio if tasacambio > 0 else Decimal("0")
        costoproductototalusd = costoproductousd * cantidad
        costototalusd = costoproductototalusd + costoslogisticosusd
        margenusd = ingresousd - costototalusd
        margenporcentaje = (
            Decimal("0")
            if ingresousd == 0
            else (margenusd / ingresousd) * Decimal("100")
        )

        filas_unificadas.append(
            (
                fechaorden,
                codigopaisiso,
                fila["nombrepais"],
                fila["idsitioweb"],
                fila["codigositio"],
                fila["nombremarca"],
                fila["codigoordenventa"],
                fila["codigoproducto"],
                nombreproducto,
                nombrecategoria,
                cantidad,
                Decimal(str(fila["preciounitariolocal"])),
                subtotal_local,
                impuesto_local,
                Decimal("0"),
                Decimal("0"),
                courier_local,
                tasacambio,
                ingresousd,
                costoproductousd,
                Decimal("0"),
                costoslogisticosusd,
                costototalusd,
                margenusd,
                margenporcentaje,
            )
        )

    return filas_unificadas


def guardar_ventas_unificadas(conn_pg, filas):
    if not filas:
        print("No hay filas para unificar")
        return

    # Limpiar tabla
    with conn_pg.cursor() as cursor:
        cursor.execute("truncate table gerencial.ventaunificada")
        conn_pg.commit()

    sentencia = """
        insert into gerencial.ventaunificada(
            fechaorden,
            codigopaisiso,
            nombrepais,
            idsitioweb,
            codigositio,
            nombremarca,
            codigoordenventa,
            codigoproducto,
            nombreproducto,
            nombrecategoria,
            cantidad,
            preciounitariolocal,
            subtotalmonedalocal,
            totalimpuesto,
            costoshippinglocal,
            permisosanitariolocal,
            costocourierlocal,
            tasacambio,
            ingresousd,
            costoproductousd,
            costosimportacionusd,
            costoslogisticosusd,
            costototalusd,
            margenusd,
            margenporcentaje
        )
        values %s
    """

    with conn_pg.cursor() as cursor:
        execute_values(cursor, sentencia, filas)

    conn_pg.commit()
    print(f"\n✅ {len(filas)} filas unificadas cargadas exitosamente en gerencial.ventaunificada")


def ejecutar_etl():
    print("=" * 60)
    print("INICIANDO ETL DE UNIFICACIÓN DE VENTAS")
    print("=" * 60)
    
    print("\n⏳ Esperando 30 segundos para que las bases estén completamente listas...")
    time.sleep(30)
    
    conn_mysql = None
    conn_pg = None
    try:
        print("\n📡 Intentando conectar a las bases de datos...")
        conn_mysql = obtener_conexion_mysql(reintentos=20, espera=3)
        conn_pg = obtener_conexion_postgres(reintentos=20, espera=3)
        print("✅ Conexiones establecidas exitosamente\n")

        filas_mysql = cargar_ventas_mysql(conn_mysql)
        print(f"✅ Ventas leidas desde MySQL: {len(filas_mysql)}")

        filas_unificadas = construir_ventas_unificadas(filas_mysql, conn_pg)
        guardar_ventas_unificadas(conn_pg, filas_unificadas)
        
        print("\n" + "=" * 60)
        print("✅ ETL COMPLETADO EXITOSAMENTE")
        print("=" * 60)
    except Exception as e:
        print(f"\n❌ ERROR EN ETL: {e}")
        import traceback
        traceback.print_exc()
        raise
    finally:
        if conn_mysql:
            conn_mysql.close()
        if conn_pg:
            conn_pg.close()


if __name__ == "__main__":
    ejecutar_etl()
