# CoopDB  Proyecto integrado



## Estructura
- `sql/01_Estructura_Base_Datos`: estructura, catálogos y validaciones.
- `sql/02_Seguridad_Auditoria`: seguridad, auditoría, vistas, roles y pruebas.
- `sql/03_Operaciones_Financieras`: operaciones de ahorro, préstamos, reportes, permisos y demo.
- `sql/04_Carga_Masiva_ETL`: staging, ETL, rechazos y verificación.
- `sql/05_Dashboards_BI`: vistas SQL para alimentar los tableros.
- `datos`: fuente CSV de asociados y Excel de cuentas.
- `etl`: programa Python de carga.
- `app`: proyectos C# de asociados, seguridad y finanzas.
- `documentacion`: manuales técnicos originales y diagrama.
- `pruebas`: scripts y guiones de pruebas ACID.
- `backup`: script de backup/restauración de integrante 2.

## Requisitos
- MySQL 8.0+ (InnoDB).
- .NET 8 para compilar las aplicaciones C#.
- Python 3.10+.
- Paquetes Python: `mysql-connector-python` y `openpyxl`.

Instalar paquetes:
```powershell
python -m pip install -r requirements.txt
```

## Orden de instalación de base de datos
Ejecutar desde MySQL Workbench con un usuario administrador. No ejecutar todo mezclado en un único editor si Workbench no conserva el soporte de `DELIMITER`; ejecutar cada archivo por separado y en este orden:

1. `sql/01_Estructura_Base_Datos/00_crear_estructura.sql`
2. `sql/01_Estructura_Base_Datos/01_catalogos_demo.sql`
3. `sql/01_Estructura_Base_Datos/02_validaciones.sql`
4. `sql/02_Seguridad_Auditoria/10_seguridad_tablas.sql`
5. `sql/02_Seguridad_Auditoria/11_auditoria_procedimientos.sql`
6. `sql/02_Seguridad_Auditoria/12_vistas_roles.sql`
7. `sql/03_Operaciones_Financieras/20_operaciones_ahorro.sql`
8. `sql/03_Operaciones_Financieras/21_prestamos.sql`
9. `sql/03_Operaciones_Financieras/22_vistas_reportes.sql`
10. `sql/03_Operaciones_Financieras/23_permisos_servicio.sql`
11. `sql/04_Carga_Masiva_ETL/00_etl_estructura.sql` (el ETL también puede crear estas tablas automáticamente)
12. `sql/05_Dashboards_BI/30_vistas_dashboards.sql` (fuentes de los tableros BI).
13. Ejecutar el ETL explicado abajo.

`13_pruebas_seguridad.sql`, `25_verificaciones_acid.sql`, `aislamiento_sesion_A.sql` y `aislamiento_sesion_B.sql` son pruebas y se ejecutan aparte. `24_datos_demo_y_pruebas.sql` es opcional: contiene llamadas de demostración que no deben repetirse sin revisar referencias únicas y estado de las cuentas.

### Advertencia de credenciales
El script `12_vistas_roles.sql` crea usuarios con contraseñas de ejemplo `CAMBIAR_...`. Antes de ejecutarlo, reemplaza todas esas contraseñas por valores propios y guarda las credenciales fuera del ZIP. El paquete no incluye contraseñas reales.

## Ejecutar ETL (integrante 4)
El ETL usa dos fuentes:
- `datos/fuente_asociados.csv`: 1,200 registros con datos de asociados.
- `datos/fuente_cuentas.xlsx`: 1,200 registros que relacionan cada ID de origen con número de cuenta, agencia, tipo y estado.

Abre PowerShell en la carpeta raíz del proyecto (la carpeta que contiene `etl`, `sql`, `datos` y `app`) y configura tu conexión local:
```powershell
$env:COOPDB_HOST="127.0.0.1"
$env:COOPDB_PORT="3306"
$env:COOPDB_USER="root"
$env:COOPDB_PASSWORD="TU_CLAVE_MYSQL"
$env:COOPDB_DATA_KEY="UNA_CLAVE_PRIVADA_LARGA_PARA_AES"
python .\etl\ejecutar_etl.py
```
La variable `COOPDB_DATA_KEY` es obligatoria. No se guarda en el código ni en el ZIP. El proceso genera DPI de demostración ficticios a partir del ID de origen y los cifra con `AES_ENCRYPT`; no son DPI reales ni deben usarse en producción.

### Qué hace el ETL
1. Lee CSV y Excel.
2. Limpia espacios, normaliza nombres, correo, códigos y estados; convierte fechas y valida campos.
3. Verifica agencias y tipos de cuenta contra los catálogos de MySQL.
4. Registra cada fila rechazada en `etl_rechazos`, con fuente, número de fila, clave, motivo y contenido original.
5. Carga staging y después las tablas principales `asociados` y `cuentas`.
6. Crea `etl_historico_cuentas` mediante `CREATE TABLE AS SELECT`.

La importación abre las cuentas con saldo cero. No inserta movimientos, no modifica saldos existentes y no sustituye las operaciones financieras del integrante 3, que deben ejecutarse mediante sus procedimientos almacenados. La importación de asociados genera `codigo` `ETL-...`; las cuentas generan `numero_cuenta` `ETL-CTA-...` para identificar el lote.

### Verificación
Ejecutar `sql/04_Carga_Masiva_ETL/01_verificacion_etl.sql`. Con el dataset proporcionado se esperan hasta 1,200 asociados y 1,200 cuentas importadas y 1,200 filas en histórico, siempre que los catálogos estén creados y activos y que la ejecución termine correctamente. La cantidad de rechazos se reporta desde la tabla `etl_rechazos`; no se debe asumir cero sin consultar. El histórico se recrea en cada ejecución para reflejar la nueva fotografía del lote; respalda esa tabla antes de volver a ejecutar si necesitas conservar cortes anteriores.

## Aplicaciones C#
Los proyectos recibidos se conservan en `app/`. Sus manuales indican que hay partes pendientes de integración y pruebas. Cada `.csproj` se compila por separado en Visual Studio/.NET 8; no se ha creado una única aplicación unificada porque los módulos entregados son ejecutables separados y no existe una solución `.sln` integrada ni contratos de navegación compartidos.

## Importante: estado de validación
Este ZIP es una integración de archivos y un flujo ETL preparado. No afirmamos que la base de datos completa esté validada en tu equipo: hace falta ejecutar los scripts en tu instancia MySQL, sustituir contraseñas de ejemplo, ejecutar el ETL y capturar evidencias. La ejecución de los scripts de seguridad requiere privilegios administrativos.


## Dashboards BI
Se agregan cuatro vistas de consulta en `sql/05_Dashboards_BI/30_vistas_dashboards.sql`.
Las tres vistas principales son captación por agencia/mes, colocación de préstamos por mes y cartera vencida por rango de días. La vista `v_bi_indicadores_generales` incluye saldo promedio e índice de morosidad como indicadores calculados.

Para Power BI: Obtener datos > MySQL database, indicar servidor y base `coopdb_core`, seleccionar las vistas `v_bi_captacion_agencia_mes`, `v_bi_colocacion_prestamos_mes`, `v_bi_cartera_mora` y `v_bi_indicadores_generales`. Crear gráficos y filtros con los campos descritos en el Manual de Usuario. El archivo `.pbix` y las capturas deben generarse en el equipo del grupo después de conectar Power BI; no se adjunta un tablero falso o sin conexión real.

## Corrección aplicada en esta revisión
Se corrigió en `etl/ejecutar_etl.py` la ruta de `00_etl_estructura.sql`, que apuntaba a una carpeta inexistente (`04_integrante4`). Ahora apunta a `sql/04_Carga_Masiva_ETL/00_etl_estructura.sql`.

## Estado honesto de validación
La revisión estática confirmó la existencia de los archivos fuente, 1,200 filas en el CSV y 1,200 filas en el Excel, además de que el script Python compila sintácticamente. Esto no sustituye la ejecución contra MySQL ni la compilación de los proyectos .NET. Las evidencias de conexión, importación, restauración, permisos, bloqueo de usuario, transacciones concurrentes y dashboards deben capturarse en el equipo del grupo.
