-- Sesion B Workbench, ejecutar mientras sesion A mantiene FOR UPDATE sobre la misma cuenta.
-- Reemplazar 1 por el MISMO ID de cuenta DEMO de sesion A.
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET SESSION innodb_lock_wait_timeout=15;
START TRANSACTION;
SELECT cuenta_id,saldo FROM coopdb_core.cuentas WHERE cuenta_id=1 FOR UPDATE;
-- Esta consulta espera hasta que A ejecute COMMIT/ROLLBACK (o agote timeout).
-- Terminar con ROLLBACK si corresponde.
