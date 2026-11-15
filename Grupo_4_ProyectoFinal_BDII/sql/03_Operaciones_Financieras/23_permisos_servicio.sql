-- EJECUTAR COMO ADMINISTRADOR. Sustituir contraseña de ejemplo antes de ejecutar.
-- Para el prototipo local exclusivamente; no incluir credenciales en aplicaciones distribuidas.
CREATE ROLE IF NOT EXISTS 'r_coopdb_finanzas';
CREATE USER IF NOT EXISTS 'coopdb_finanzas'@'localhost'
 IDENTIFIED BY 'CAMBIAR_Finanzas_8N!47xRm#2026';
GRANT EXECUTE ON PROCEDURE coopdb_core.sp_abrir_cuenta TO 'r_coopdb_finanzas';
GRANT EXECUTE ON PROCEDURE coopdb_core.sp_depositar TO 'r_coopdb_finanzas';
GRANT EXECUTE ON PROCEDURE coopdb_core.sp_retirar TO 'r_coopdb_finanzas';
GRANT EXECUTE ON PROCEDURE coopdb_core.sp_transferir TO 'r_coopdb_finanzas';
GRANT EXECUTE ON PROCEDURE coopdb_core.sp_estado_cuenta TO 'r_coopdb_finanzas';
GRANT EXECUTE ON PROCEDURE coopdb_core.sp_solicitar_prestamo TO 'r_coopdb_finanzas';
GRANT EXECUTE ON PROCEDURE coopdb_core.sp_resolver_solicitud TO 'r_coopdb_finanzas';
GRANT EXECUTE ON PROCEDURE coopdb_core.sp_desembolsar_prestamo TO 'r_coopdb_finanzas';
GRANT EXECUTE ON PROCEDURE coopdb_core.sp_pagar_cuota TO 'r_coopdb_finanzas';
GRANT 'r_coopdb_finanzas' TO 'coopdb_finanzas'@'localhost';
SET DEFAULT ROLE 'r_coopdb_finanzas' TO 'coopdb_finanzas'@'localhost';
-- En producción dividir por rol: cajero (depósitos/retiros/pagos), gerente (aprobación), etc.
-- Usar una API que verifique el rol de aplicación en cada operación financiera.
