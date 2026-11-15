# CoopDB — Integrante 2: Seguridad y auditoría

**Compatible con el ZIP del integrante 1.** Motor: MySQL 8.0+; app de demostración: C# .NET 8 (consola local); paquetes MySqlConnector y BCrypt.Net-Next.

## Orden de instalación en MySQL Workbench
1. Ejecutar **integrante 1 / sql / 00_crear_estructura.sql** si no se ha hecho.
2. Ejecutar `sql/10_seguridad_tablas.sql` (crea tablas de seguridad y roles de aplicación).
3. Ejecutar `sql/11_auditoria_procedimientos.sql` (3 triggers y 2 procedimientos).
4. **Editar antes** de ejecutar `sql/12_vistas_roles.sql`: sustituir las contraseñas `CAMBIAR_...` por secretos únicos fuertes. Ejecutar con cuenta administradora de MySQL (privilegios CREATE USER, CREATE ROLE, GRANT, etc.).
5. Ejecutar `sql/13_pruebas_seguridad.sql`, luego probar permisos desde cuentas cajero, auditor y gerente por separado.
6. NO ejecutar los scripts de creación del integrante 1 otra vez en una base con datos reales sin respaldo.

## Aplicación de consola de seguridad
En Windows, instalar .NET SDK 8; en PowerShell dentro de `app/CoopDB.Seguridad`:

```powershell
$env:COOPDB_HOST="127.0.0.1"
$env:COOPDB_PORT="3306"
$env:COOPDB_AUTH_USER="coopdb_auth"
$env:COOPDB_AUTH_PASSWORD="TU_CLAVE_SERVICIO"
$env:COOPDB_SSL_MODE="None"
dotnet restore
dotnet run
```

Se ejecuta `1` SOLO para crear el primer administrador cuando `usuarios_app` está vacía. Luego `2` inicia sesión. Tres contraseñas incorrectas bloquean la cuenta hasta que un administrador la desbloquee. Al entrar con ADMIN, hay opciones para crear cuentas, asignar un rol, desactivar y desbloquear.

**No se ha probado contra una instancia de MySQL real en este entorno.** Requiere ejecución y capturas en el equipo del grupo. El aplicativo del integrante 1 es WinForms independiente y **todavía no incorpora el formulario de login**; el programa entregado es un módulo demostrable para incorporar al punto de entrada del proyecto general. Nunca conectar credenciales `coopdb_auth` desde una app cliente distribuida a terceros; mover el módulo a un backend de confianza.

## Roles MySQL vs. roles aplicación
- Usuarios MySQL (`coopdb_cajero`, `coopdb_auditor`, `coopdb_gerente`, `coopdb_admin`) demuestran RBAC en servidor, con permisos diferenciados.
- Usuarios de `coopdb_seguridad.usuarios_app` son personas que inician sesión; se enlazan con roles de `roles_app` usando `usuario_rol`.
- El servicio local `coopdb_auth` se usa únicamente para el prototipo de autenticación; una solución real debería emplear API backend con permisos separados para login y administración, sin exponer estas credenciales.

## Cifrado de 2 campos
Las columnas `coopdb_core.asociados.dpi_cifrado` y `nit_cifrado` fueron creadas por el integrante 1; su `Program.cs` ejecuta `AES_ENCRYPT(@dpi,@clave)` y `AES_ENCRYPT(@nit,@clave)` con parámetros. `COOPDB_DATA_KEY` debe mantenerse en secreto. Para el trabajo, ambas columnas constituyen la evidencia de cifrado; usar datos ficticios. Para producción conviene usar cifrado autenticado moderno con gestión de claves y rotación.

## Prueba contra SQL Injection
Ejemplo de entrada hostil **solo contra datos locales de prueba**: `admin' OR '1'='1` en campo de usuario. La consulta `WHERE nombre_usuario=@login` utiliza parámetros `MySqlCommand.Parameters` y trata la entrada como texto, sin cambiar la estructura SQL. Ver `Program.cs` y módulo de asociados del integrante 1.

## Backups y restauración
Revisar `backup/backup_restauracion.ps1`. Genera un dump con `--single-transaction`, triggers y rutinas, **pero NO restaura automáticamente**. Se debe crear una INSTANCIA separada de MySQL, por ejemplo en puerto 3307, y restaurar allí:

```powershell
cmd /c "mysql --host=127.0.0.1 --port=3307 --user=root --password < coopdb_backup_FECHA.sql"
```

Reemplazar el nombre del archivo. El dump contiene `CREATE DATABASE` de `coopdb_core` y `coopdb_seguridad`, por eso NUNCA se debe restaurar en el mismo servidor productivo. Se recomienda respaldo completo diario, prueba de restauración mensual, cifrado de respaldos, control de acceso y retención de 30 días según las políticas que acuerde el grupo. Evidenciar conteos de filas antes y después en instancia aislada. Las cuentas/GRANTS de MySQL se respaldan por separado con un procedimiento administrado; `mysqldump` de estas dos bases no incluye cuentas MySQL.

## Auditoría
- `trg_audit_saldo`: cambios en `coopdb_core.cuentas.saldo`.
- `trg_audit_tasa`: cambios en `coopdb_core.tipos_prestamo.tasa_anual`.
- `trg_audit_usuarios`: activación y bloqueo de cuentas de aplicación.
- `sp_registrar_evento_acceso` y `sp_desactivar_usuario`: procedimientos almacenados.
- `v_bitacora_consulta`: solo para auditor, gerente y administrador por RBAC.
- La variable `@coopdb_actor` es contexto de sesión **informativo y no una identidad confiable por sí sola**; `usuario_bd` toma `USER()`.

## Limitaciones de integración
1. El login de consola no sustituye un login WinForms integrado; el integrante principal debe enlazar el formulario de asociados tras una autenticación exitosa y validar permisos de cada operación.
2. Para módulo de operaciones monetarias usar cuenta de servicio y procedimientos transaccionales de mínimo privilegio; la cuenta de cajero propuesta solo consulta vistas.
3. Usar usuarios locales MySQL para demostraciones; si MySQL es remoto, adaptar `@'localhost'` al host exacto y exigir TLS.
4. El código no sustituye controles de producción (rate limiting por IP, MFA, gestión de sesiones, rotación de secretos, KMS).
5. No entregar contraseñas reales ni respaldo que contenga datos personales auténticos.
