# CoopDB — Integrante 3: Operaciones financieras y transacciones

Entrega compatible con `CoopDB_Integrante1_ZIP_DER_Actualizado.zip` y `CoopDB_Integrante2_Seguridad_Auditoria.zip`.
Motor: MySQL 8.0+ InnoDB, Workbench. App local de muestra: C# .NET 8 y MySqlConnector 2.3.7.

## Orden de instalación

1. Ejecutar scripts del integrante 1: `00_crear_estructura.sql` y `01_catalogos_demo.sql`.
2. Ejecutar integrante 2: `10_seguridad_tablas.sql`, `11_auditoria_procedimientos.sql`, `12_vistas_roles.sql` (con contraseñas sustituidas).
3. Ejecutar `sql/20_operaciones_ahorro.sql` (5 procedimientos), `sql/21_prestamos.sql` (4 procedimientos), `sql/22_vistas_reportes.sql` (3 vistas).
4. Ejecutar `sql/23_permisos_servicio.sql` como administrador, **cambiar contraseña de ejemplo ANTES** de ejecutar.
5. **Solo en una base de pruebas vacía**, ejecutar `sql/24_datos_demo_y_pruebas.sql`. No debe repetirse sin cambiar referencias únicas.
6. Ejecutar `pruebas/25_verificaciones_acid.sql` y capturar las consultas de comprobación.
7. Ejecutar demostraciones de aislamiento con 2 conexiones distintas: `pruebas/aislamiento_sesion_A.sql` y `aislamiento_sesion_B.sql`.

## Ejecutar aplicación C#

Abrir PowerShell en `app/CoopDB.Finanzas`, con SDK .NET 8 instalado:

```powershell
$env:COOPDB_HOST="127.0.0.1"
$env:COOPDB_PORT="3306"
$env:COOPDB_FIN_USER="coopdb_finanzas"
$env:COOPDB_FIN_PASSWORD="CLAVE_REAL_CONFIGURADA_EN_MYSQL"
$env:COOPDB_MODE="local"
$env:COOPDB_ACTOR="demo_finanzas"
dotnet restore
dotnet run
```

No se debe compartir la clave real. `COOPDB_ACTOR` es una etiqueta de prueba; en la aplicación integrada debe venir de la sesión autenticada del integrante 2. Los procedimientos se crean con `SQL SECURITY DEFINER` y **requieren autorización de roles en el backend**; el usuario técnico para demostración tiene facultades amplias, por lo que debe separarse por función antes de uso real.

## Operaciones

- Apertura de cuentas con saldo cero y validación de titular/agencia/tipo.
- Depósitos y retiros mediante actualización de saldo + registro del movimiento, transacción única.
- Transferencias con bloqueo de dos cuentas en orden ascendente, dos movimientos y una transferencia, transacción única.
- Estado de cuenta por fechas inclusivas.
- Solicitud, aprobación/rechazo, desembolso y plan de pagos de capital constante, interés mensual sobre saldo.
- Pagos en efectivo externo (`p_cuenta_origen=NULL`) o debitando cuenta de ahorro del mismo asociado, distribución primero a interés vencible según orden de cuota, luego capital. Los intereses son programados; este prototipo no calcula mora ni intereses diarios.

## Observaciones

El proyecto del integrante 1 ya trae tablas y catálogos necesarios; no duplicar estructura.
El integrante 2 ya trae trigger de saldo, que audita las actualizaciones hechas por procedimientos del integrante 3.
Este paquete se preparó sin conectar a una instancia real de MySQL; **faltan ejecución y capturas reales**. No se inventaron resultados de ACID ni de restauraciones/reinicios.
Consultar el manual técnico y `pruebas/GUION_EVIDENCIAS.md`.
