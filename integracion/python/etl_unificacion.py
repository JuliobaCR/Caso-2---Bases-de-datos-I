import os
import time
from decimal import Decimal

import psycopg2
import pymysql
from psycopg2.extras import execute_values


def obtener_conexion_postgres(reintentos=5, espera=3):
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


def obtener_conexion_mysql(reintentos=5, espera=3):
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
    consulta = """
        select
            date(ov.fechaorden) as fechaorden,
            p.codigopaisiso,
            p.nombrepais,
            s.idsitioweb,
            s.codigositio,
            m.nombremarca,
            ov.codigoordenventa,
            ov.totalmonedalocal,
            round(ov.totalimpuesto * (ovd.subtotal / ov.totalmonedalocal), 4) as totalimpuesto,
            round(ov.costoshipping * (ovd.subtotal / ov.totalmonedalocal), 4) as costoshipping,
            round(ov.permisosanitario * (ovd.subtotal / ov.totalmonedalocal), 4) as permisosanitario,
            ifnull(d.costocourierlocal, 0) as costocourierlocal,
            ovd.codigoproductoetheria as codigoproducto,
            ovd.cantidad,
            ovd.preciounitariolocal,
            ovd.subtotal
        from ordenventa ov
        inner join sitioweb s on s.idsitioweb = ov.idsitioweb
        inner join marcaia m on m.idmarcaia = s.idmarcaia
        inner join pais p on p.idpais = s.idpais
        inner join ordenventadetalle ovd on ovd.idordenventa = ov.idordenventa
        left join despacho d on d.idordenventa = ov.idordenventa
            and d.estadodespacho = 'entregado'
        where ov.estadoorden = 'entregada'
    """
    with conn_mysql.cursor() as cursor:
        cursor.execute(consulta)
        return cursor.fetchall()


def obtener_contexto_producto(conn_pg, codigoproducto):
    consulta = """
        select
            pb.nombreproducto,
            c.nombrecategoria,
            coalesce(ultimocosto.costounitariousd, 0) as costoproductousd
        from etheria.productobase pb
        inner join etheria.categoria c on c.idcategoria = pb.idcategoria
        left join lateral (
            select idt.costounitariousd
            from etheria.importaciondetalle idt
            inner join etheria.importacion imp on imp.idimportacion = idt.idimportacion
            where idt.idproductobase = pb.idproductobase
            order by imp.fechallegadacaribe desc nulls last, imp.fechapedido desc, idt.idimportaciondetalle desc
            limit 1
        ) ultimocosto on true
        where pb.codigoproducto = %s
    """
    with conn_pg.cursor() as cursor:
        cursor.execute(consulta, (codigoproducto,))
        fila = cursor.fetchone()
    if not fila:
        return ("producto no mapeado", "sin categoria", Decimal("0"))
    return fila


def obtener_costo_importacion_unitario(conn_pg, codigoproducto):
    """Obtiene el costo unitario más reciente del producto desde importaciones"""
    consulta = """
        select coalesce(idt.costounitariousd, 0) as costousd
        from etheria.importaciondetalle idt
        inner join etheria.importacion imp on imp.idimportacion = idt.idimportacion
        inner join etheria.productobase pb on pb.idproductobase = idt.idproductobase
        where pb.codigoproducto = %s
        order by imp.fechallegadacaribe desc nulls last, 
                 imp.fechapedido desc, 
                 idt.idimportaciondetalle desc
        limit 1
    """
    with conn_pg.cursor() as cursor:
        cursor.execute(consulta, (codigoproducto,))
        fila = cursor.fetchone()
    if fila:
        return Decimal(str(fila[0]))
    return Decimal("0")


def obtener_tasa_cambio(conn_pg, codigopaisiso, fechaorden):
    consulta = """
        select tc.tasausdmonedalocal
        from etheria.tipocambio tc
        inner join etheria.pais p on p.idpais = tc.idpais
        where p.codigopaisiso = %s
          and tc.fechatasa <= %s
        order by tc.fechatasa desc
        limit 1
    """
    with conn_pg.cursor() as cursor:
        cursor.execute(consulta, (codigopaisiso, fechaorden))
        fila = cursor.fetchone()
    if fila:
        return Decimal(str(fila[0]))
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
        
        # Obtener costo de importación específico del producto
        costo_importacion_unitario = obtener_costo_importacion_unitario(conn_pg, fila["codigoproducto"])

        cantidad = Decimal(str(fila["cantidad"]))
        subtotal_local = Decimal(str(fila["subtotal"]))
        impuesto_local = Decimal(str(fila["totalimpuesto"]))
        shipping_local = Decimal(str(fila["costoshipping"]))
        permiso_local = Decimal(str(fila["permisosanitario"]))
        courier_local = Decimal(str(fila["costocourierlocal"]))

        ingresousd = subtotal_local / tasacambio
        costoslogisticosusd = (shipping_local + permiso_local + courier_local) / tasacambio
        costosimportacionusd = costo_importacion_unitario * cantidad
        costoproductototalusd = costoproductousd * cantidad
        costototalusd = costoproductototalusd + costosimportacionusd + costoslogisticosusd
        margenusd = ingresousd - costototalusd
        margenporcentaje = Decimal("0") if ingresousd == 0 else (margenusd / ingresousd) * Decimal("100")

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
                shipping_local,
                permiso_local,
                courier_local,
                tasacambio,
                ingresousd,
                costoproductousd,
                costosimportacionusd,
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
        on conflict (codigoordenventa, codigoproducto)
        do update set
            fechaorden = excluded.fechaorden,
            codigopaisiso = excluded.codigopaisiso,
            nombrepais = excluded.nombrepais,
            idsitioweb = excluded.idsitioweb,
            codigositio = excluded.codigositio,
            nombremarca = excluded.nombremarca,
            nombreproducto = excluded.nombreproducto,
            nombrecategoria = excluded.nombrecategoria,
            cantidad = excluded.cantidad,
            preciounitariolocal = excluded.preciounitariolocal,
            subtotalmonedalocal = excluded.subtotalmonedalocal,
            totalimpuesto = excluded.totalimpuesto,
            costoshippinglocal = excluded.costoshippinglocal,
            permisosanitariolocal = excluded.permisosanitariolocal,
            costocourierlocal = excluded.costocourierlocal,
            tasacambio = excluded.tasacambio,
            ingresousd = excluded.ingresousd,
            costoproductousd = excluded.costoproductousd,
            costosimportacionusd = excluded.costosimportacionusd,
            costoslogisticosusd = excluded.costoslogisticosusd,
            costototalusd = excluded.costototalusd,
            margenusd = excluded.margenusd,
            margenporcentaje = excluded.margenporcentaje,
            fechacarga = now()
    """

    with conn_pg.cursor() as cursor:
        execute_values(cursor, sentencia, filas)

    conn_pg.commit()
    print(f"\n✅ {len(filas)} filas unificadas cargadas exitosamente en gerencial.ventaunificada")


def ejecutar_etl():
    print("=" * 60)
    print("INICIANDO ETL DE UNIFICACIÓN DE VENTAS")
    print("=" * 60)
    
    # Esperar a que las BDs estén 100% listas (aún después del health check)
    # Aumentado a 30s porque la inicialización de MySQL puede tardar más
    print("\n⏳ Esperando 30 segundos para que las bases estén 100% listas...")
    time.sleep(30)
    
    conn_mysql = None
    conn_pg = None
    try:
        print("\n📡 Intentando conectar a las bases de datos...")
        # Aumentar reintentos y espera para tolerar inicializaciones lentas
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
        raise
    finally:
        if conn_mysql:
            conn_mysql.close()
        if conn_pg:
            conn_pg.close()


if __name__ == "__main__":
    ejecutar_etl()
