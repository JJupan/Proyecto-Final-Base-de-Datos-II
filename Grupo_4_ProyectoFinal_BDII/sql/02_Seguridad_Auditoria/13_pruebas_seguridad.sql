-- COMPROBACIONES NO DESTRUCTIVAS: ejecutar como administrador en Workbench
SHOW DATABASES LIKE 'coopdb%';
SELECT user, host FROM mysql.user WHERE user LIKE 'coopdb_%';
SELECT * FROM coopdb_seguridad.roles_app;
SELECT * FROM coopdb_seguridad.v_asociados_publicos LIMIT 10;
SELECT * FROM coopdb_seguridad.v_saldos_cajero LIMIT 10;
SELECT * FROM coopdb_seguridad.v_bitacora_consulta ORDER BY auditoria_id DESC LIMIT 10;
SELECT TRIGGER_NAME,EVENT_OBJECT_TABLE FROM information_schema.TRIGGERS
 WHERE TRIGGER_SCHEMA IN ('coopdb_core','coopdb_seguridad');
SELECT ROUTINE_NAME FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA='coopdb_seguridad' AND ROUTINE_TYPE='PROCEDURE';
-- Para provocar trigger real usar un registro de prueba EXISTENTE y una transacción:
-- START TRANSACTION;
-- UPDATE coopdb_core.cuentas SET saldo = saldo + 1 WHERE cuenta_id = <ID_DE_PRUEBA>;
-- SELECT * FROM coopdb_seguridad.v_bitacora_consulta ORDER BY auditoria_id DESC LIMIT 3;
-- ROLLBACK;  -- también revierte la bitácora porque es transaccional.
-- Repetir con COMMIT si se desea conservar evidencia, usando datos ficticios.
-- En sesión con usuario coopdb_cajero: SELECT * FROM coopdb_seguridad.v_saldos_cajero;
-- En sesión con usuario coopdb_cajero: SELECT * FROM coopdb_seguridad.bitacora_auditoria; -- DEBE FALLAR
-- En sesión con usuario coopdb_auditor: DELETE FROM coopdb_seguridad.bitacora_auditoria; -- DEBE FALLAR
