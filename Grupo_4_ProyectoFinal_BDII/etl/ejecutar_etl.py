# ETL CoopDB - Integrante 4. Carga CSV + Excel a asociados/cuentas.
# Los DPI son identificadores ficticios generados para pruebas y se cifran en MySQL.
import csv, json, os, re
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from openpyxl import load_workbook
import mysql.connector

ROOT=Path(__file__).resolve().parents[1]
CSV_PATH=ROOT/'datos'/'fuente_asociados.csv'
XLSX_PATH=ROOT/'datos'/'fuente_cuentas.xlsx'
DDL_PATH=ROOT/'sql'/'04_Carga_Masiva_ETL'/'00_etl_estructura.sql'


def clean(v):
    if v is None: return ''
    return ' '.join(str(v).strip().split())


def connect():
    return mysql.connector.connect(
        host=os.getenv('COOPDB_HOST','127.0.0.1'),
        port=int(os.getenv('COOPDB_PORT','3306')),
        user=os.getenv('COOPDB_USER','root'),
        password=os.getenv('COOPDB_PASSWORD',''),
        database='coopdb_core', charset='utf8mb4', autocommit=False)


def execute_ddl(cur):
    # Ejecuta las sentencias simples del archivo de estructura (sin DELIMITER).
    content=DDL_PATH.read_text(encoding='utf-8')
    content='\n'.join(line for line in content.splitlines() if not line.lstrip().startswith('--'))
    for stmt in content.split(';'):
        if stmt.strip(): cur.execute(stmt)


def main():
    key=os.getenv('COOPDB_DATA_KEY')
    if not key:
        raise RuntimeError('Define COOPDB_DATA_KEY antes de ejecutar; no se usa una clave fija.')
    conn=connect(); cur=conn.cursor()
    try:
        execute_ddl(cur)
        cur.execute('DELETE FROM etl_stg_asociados')
        cur.execute('DELETE FROM etl_stg_cuentas')
        cur.execute('DELETE FROM etl_rechazos')
        accepted_customers={}; rejected=0
        with CSV_PATH.open(encoding='utf-8-sig',newline='') as f:
            reader=csv.DictReader(f)
            required={'id_cliente','nombre','apellido','email','telefono','fecha_registro','departamento','activo'}
            if not required.issubset(set(reader.fieldnames or [])):
                raise RuntimeError('El CSV no contiene todas las columnas esperadas: '+', '.join(sorted(required)))
            for rownum,row in enumerate(reader,start=2):
                try:
                    source_id=int(clean(row['id_cliente']))
                    name=clean(row['nombre']).title(); surname=clean(row['apellido']).title()
                    email=clean(row['email']).lower() or None
                    phone=clean(row['telefono']) or None
                    dt=datetime.strptime(clean(row['fecha_registro']),'%Y-%m-%d').date()
                    dept=clean(row['departamento']).title() or None
                    active=int(clean(row['activo']))
                    if source_id<=0 or not name or not surname or active not in (0,1):
                        raise ValueError('ID, nombre, apellido o estado fuera de regla')
                    if email and not re.fullmatch(r'[^@\s]+@[^@\s]+\.[^@\s]+',email):
                        raise ValueError('Correo con formato inválido')
                    code=f'ETL-{source_id:012d}'
                    if code in accepted_customers: raise ValueError('ID de origen duplicado')
                    accepted_customers[code]=(source_id,name,surname,email,phone,dt,dept,active)
                except Exception as ex:
                    rejected+=1
                    cur.execute('''INSERT INTO etl_rechazos(fuente,numero_fila,clave_origen,motivo,registro_json)
                                   VALUES(%s,%s,%s,%s,%s)''',('fuente_asociados.csv',rownum,clean(row.get('id_cliente')),str(ex)[:500],json.dumps(row,ensure_ascii=False)))
        # Lee el catálogo Excel y valida sus referencias contra los catálogos reales.
        cur.execute('SELECT codigo,agencia_id FROM agencias WHERE activa=1'); agencies={r[0]:r[1] for r in cur.fetchall()}
        cur.execute('SELECT codigo,tipo_cuenta_id FROM tipos_cuenta WHERE activa=1'); types={r[0]:r[1] for r in cur.fetchall()}
        accepted_accounts={}
        wb=load_workbook(XLSX_PATH,read_only=True,data_only=True); ws=wb['Cuentas']
        rows=ws.iter_rows(values_only=True); headers=[clean(x) for x in next(rows)]
        for rownum,values in enumerate(rows,start=2):
            row=dict(zip(headers,values))
            try:
                sid=int(clean(row.get('id_cliente_origen')))
                number=clean(row.get('numero_cuenta')).upper()
                agency=clean(row.get('codigo_agencia')).upper()
                typ=clean(row.get('tipo_cuenta')).upper()
                state=clean(row.get('estado_cuenta')).upper()
                if sid not in [v[0] for v in accepted_customers.values()]: raise ValueError('No existe asociado válido para el ID de origen')
                if not number or len(number)>24: raise ValueError('Número de cuenta vacío o excede 24 caracteres')
                if agency not in agencies: raise ValueError(f'Agencia inexistente o inactiva: {agency}')
                if typ not in types: raise ValueError(f'Tipo de cuenta inexistente o inactivo: {typ}')
                if state not in ('ACTIVA','BLOQUEADA','CERRADA'): raise ValueError('Estado de cuenta no permitido')
                if sid in accepted_accounts: raise ValueError('ID de asociado duplicado en Excel')
                accepted_accounts[sid]=(number,agency,typ,state)
            except Exception as ex:
                rejected+=1
                cur.execute('''INSERT INTO etl_rechazos(fuente,numero_fila,clave_origen,motivo,registro_json)
                               VALUES(%s,%s,%s,%s,%s)''',('fuente_cuentas.xlsx',rownum,clean(row.get('id_cliente_origen')),str(ex)[:500],json.dumps({k:clean(v) for k,v in row.items()},ensure_ascii=False)))
        # Solo se migran asociados con una fila de cuenta válida para mantener el lote consistente.
        common_ids=set(accepted_accounts)
        customer_rows=[v for v in accepted_customers.values() if v[0] in common_ids]
        if len(customer_rows)<1000:
            raise RuntimeError(f'Solo hay {len(customer_rows)} asociados válidos con cuenta relacionada; se requieren al menos 1,000.')
        cur.executemany('''INSERT INTO etl_stg_asociados
          (id_cliente_origen,codigo,nombres,apellidos,correo,telefono,fecha_registro,departamento_origen,activo)
          VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)''',
          [(v[0],f'ETL-{v[0]:012d}',v[1],v[2],v[3],v[4],v[5],v[6],v[7]) for v in customer_rows])
        cur.executemany('''INSERT INTO etl_stg_cuentas
          (id_cliente_origen,numero_cuenta,codigo_agencia,codigo_tipo_cuenta,estado_cuenta)
          VALUES(%s,%s,%s,%s,%s)''',
          [(sid,*accepted_accounts[sid]) for sid in sorted(common_ids)])
        conn.commit()
        # Insert/update associated records. DPI ficticio determinístico, cifrado y hash; no son DPI reales.
        for v in customer_rows:
            sid,code,name,surname,email,phone,dt,dept,active=v
            fake_dpi=f'9{sid:012d}'
            agency_code=accepted_accounts[sid][1]
            agency_id=agencies[agency_code]
            cur.execute('''INSERT INTO asociados
              (codigo,agencia_id,nombres,apellidos,fecha_nacimiento,telefono,correo,direccion,
               dpi_cifrado,dpi_hash,nit_cifrado,fecha_registro,activo)
              VALUES(%s,%s,%s,%s,NULL,%s,%s,%s,AES_ENCRYPT(%s,%s),UNHEX(SHA2(%s,256)),NULL,%s,%s)
              ON DUPLICATE KEY UPDATE agencia_id=VALUES(agencia_id),nombres=VALUES(nombres),
               apellidos=VALUES(apellidos),telefono=VALUES(telefono),correo=VALUES(correo),
               fecha_registro=VALUES(fecha_registro),activo=VALUES(activo)''',
              (code,agency_id,name,surname,phone,email,dept,fake_dpi,key,fake_dpi,datetime.combine(dt,datetime.min.time()),bool(active)))
        conn.commit()
        # Cuentas se abren con saldo cero. No se generan movimientos ni se alteran saldos existentes.
        cur.execute('''INSERT INTO cuentas(numero_cuenta,asociado_id,agencia_id,tipo_cuenta_id,saldo,estado)
          SELECT s.numero_cuenta,a.asociado_id,g.agencia_id,t.tipo_cuenta_id,0,s.estado_cuenta
          FROM etl_stg_cuentas s
          JOIN etl_stg_asociados x ON x.id_cliente_origen=s.id_cliente_origen
          JOIN asociados a ON a.codigo=x.codigo
          JOIN agencias g ON g.codigo=s.codigo_agencia
          JOIN tipos_cuenta t ON t.codigo=s.codigo_tipo_cuenta
          ON DUPLICATE KEY UPDATE asociado_id=VALUES(asociado_id),agencia_id=VALUES(agencia_id),
           tipo_cuenta_id=VALUES(tipo_cuenta_id),estado=VALUES(estado)''')
        conn.commit()
        cur.execute('DROP TABLE IF EXISTS etl_historico_cuentas')
        cur.execute('''CREATE TABLE etl_historico_cuentas AS
          SELECT a.asociado_id,a.codigo AS codigo_asociado,a.nombres,a.apellidos,
                 c.cuenta_id,c.numero_cuenta,g.codigo AS agencia,t.codigo AS tipo_cuenta,
                 c.estado AS estado_cuenta,c.saldo AS saldo_capturado,
                 CURRENT_TIMESTAMP AS fecha_captura
          FROM asociados a JOIN cuentas c ON c.asociado_id=a.asociado_id
          JOIN agencias g ON g.agencia_id=c.agencia_id
          JOIN tipos_cuenta t ON t.tipo_cuenta_id=c.tipo_cuenta_id
          WHERE a.codigo LIKE 'ETL-%' AND c.numero_cuenta LIKE 'ETL-CTA-%' ''')
        cur.execute('SELECT COUNT(*) FROM etl_stg_asociados'); staged_assoc=cur.fetchone()[0]
        cur.execute('SELECT COUNT(*) FROM etl_stg_cuentas'); staged_acct=cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM asociados WHERE codigo LIKE 'ETL-%'"); loaded_assoc=cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM cuentas WHERE numero_cuenta LIKE 'ETL-CTA-%'"); loaded_acct=cur.fetchone()[0]
        cur.execute('SELECT COUNT(*) FROM etl_historico_cuentas'); hist=cur.fetchone()[0]
        cur.execute('SELECT COUNT(*) FROM etl_rechazos'); rejects=cur.fetchone()[0]
        conn.commit()
        print('ETL COMPLETADO')
        print(f'Asociados aceptados en staging: {staged_assoc}')
        print(f'Cuentas aceptadas en staging: {staged_acct}')
        print(f'Asociados ETL en tabla principal: {loaded_assoc}')
        print(f'Cuentas ETL en tabla principal: {loaded_acct}')
        print(f'Registros en historico: {hist}')
        print(f'Rechazos registrados con motivo: {rejects}')
        if min(loaded_assoc,loaded_acct,hist)>=1000: print('REQUISITO DE CARGA MASIVA: CUMPLIDO EN ESTA EJECUCION')
        else: print('ADVERTENCIA: revisar conteos, no se alcanzaron 1,000 registros en todos los destinos.')
    except Exception:
        conn.rollback(); raise
    finally:
        cur.close(); conn.close()

if __name__=='__main__': main()
