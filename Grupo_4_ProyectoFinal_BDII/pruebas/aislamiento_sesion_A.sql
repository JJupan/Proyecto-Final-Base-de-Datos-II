-- Sesion A Workbench, misma cuenta que en sesion B. NO ejecutar en producción.
-- Reemplazar 1 por ID de cuenta DEMO con saldo suficiente.
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT cuenta_id,saldo FROM coopdb_core.cuentas WHERE cuenta_id=1 FOR UPDATE;
-- Mantener transaccion abierta mientras se prueba sesion B; luego ejecutar:
-- COMMIT;
-- Para simular retiro real NO actualizar saldo a mano: ejecutar CALL sp_retirar fuera de esta transaccion.
