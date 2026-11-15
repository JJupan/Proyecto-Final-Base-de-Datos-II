-- Ejecutar con cuenta administradora de MySQL. CAMBIAR todas las contraseñas ANTES de ejecutar.
-- Los dos esquemas MySQL son coopdb_core y coopdb_seguridad.
CREATE OR REPLACE SQL SECURITY DEFINER VIEW coopdb_seguridad.v_saldos_cajero AS
SELECT c.cuenta_id,c.numero_cuenta,a.codigo AS codigo_asociado,
       CONCAT(a.nombres,' ',a.apellidos) AS asociado,
       c.saldo,c.estado,c.agencia_id
FROM coopdb_core.cuentas c JOIN coopdb_core.asociados a ON a.asociado_id=c.asociado_id;
CREATE OR REPLACE SQL SECURITY DEFINER VIEW coopdb_seguridad.v_asociados_publicos AS
SELECT asociado_id,codigo,nombres,apellidos,agencia_id,activo
FROM coopdb_core.asociados;
CREATE OR REPLACE SQL SECURITY DEFINER VIEW coopdb_seguridad.v_bitacora_consulta AS
SELECT auditoria_id,fecha_hora,usuario_bd,usuario_app,tabla_afectada,operacion,
       registro_id,valor_anterior,valor_nuevo
FROM coopdb_seguridad.bitacora_auditoria;
CREATE ROLE IF NOT EXISTS 'r_coopdb_cajero','r_coopdb_auditor','r_coopdb_gerente','r_coopdb_admin';
-- Cuentas de demostración; sustituir las claves largas de ejemplo y guardarlas fuera del proyecto.
CREATE USER IF NOT EXISTS 'coopdb_cajero'@'localhost' IDENTIFIED BY 'CAMBIAR_Cajero_8V!42nWz#2026';
CREATE USER IF NOT EXISTS 'coopdb_auditor'@'localhost' IDENTIFIED BY 'CAMBIAR_Auditor_4L!93mXq#2026';
CREATE USER IF NOT EXISTS 'coopdb_gerente'@'localhost' IDENTIFIED BY 'CAMBIAR_Gerente_6P!17kTr#2026';
CREATE USER IF NOT EXISTS 'coopdb_admin'@'localhost' IDENTIFIED BY 'CAMBIAR_Admin_5R!28vNp#2026';
-- Reaplicar con ALTER USER si las cuentas ya existían; CREATE IF NOT EXISTS no actualiza contraseñas.
GRANT SELECT ON coopdb_seguridad.v_saldos_cajero TO 'r_coopdb_cajero';
GRANT SELECT ON coopdb_seguridad.v_asociados_publicos TO 'r_coopdb_cajero';
GRANT SELECT ON coopdb_seguridad.v_bitacora_consulta TO 'r_coopdb_auditor','r_coopdb_gerente';
GRANT SELECT ON coopdb_seguridad.v_saldos_cajero TO 'r_coopdb_gerente';
GRANT SELECT ON coopdb_seguridad.v_asociados_publicos TO 'r_coopdb_gerente';
GRANT SELECT,INSERT,UPDATE ON coopdb_seguridad.usuarios_app TO 'r_coopdb_admin';
GRANT SELECT,INSERT,DELETE ON coopdb_seguridad.usuario_rol TO 'r_coopdb_admin';
GRANT SELECT ON coopdb_seguridad.roles_app TO 'r_coopdb_admin';
GRANT SELECT ON coopdb_seguridad.v_bitacora_consulta TO 'r_coopdb_admin';
GRANT EXECUTE ON PROCEDURE coopdb_seguridad.sp_desactivar_usuario TO 'r_coopdb_admin';
GRANT EXECUTE ON PROCEDURE coopdb_seguridad.sp_registrar_evento_acceso TO 'r_coopdb_admin';
GRANT 'r_coopdb_cajero' TO 'coopdb_cajero'@'localhost';
GRANT 'r_coopdb_auditor' TO 'coopdb_auditor'@'localhost';
GRANT 'r_coopdb_gerente' TO 'coopdb_gerente'@'localhost';
GRANT 'r_coopdb_admin' TO 'coopdb_admin'@'localhost';
SET DEFAULT ROLE 'r_coopdb_cajero' TO 'coopdb_cajero'@'localhost';
SET DEFAULT ROLE 'r_coopdb_auditor' TO 'coopdb_auditor'@'localhost';
SET DEFAULT ROLE 'r_coopdb_gerente' TO 'coopdb_gerente'@'localhost';
SET DEFAULT ROLE 'r_coopdb_admin' TO 'coopdb_admin'@'localhost';
-- Cuenta de SERVICIO de la app (no confundir con cuentas humanas). Solo para prototipo local.
CREATE USER IF NOT EXISTS 'coopdb_auth'@'localhost' IDENTIFIED BY 'CAMBIAR_Servicio_9G!63qUa#2026';
CREATE ROLE IF NOT EXISTS 'r_coopdb_auth';
GRANT SELECT,INSERT,UPDATE ON coopdb_seguridad.usuarios_app TO 'r_coopdb_auth';
GRANT SELECT,INSERT,DELETE ON coopdb_seguridad.usuario_rol TO 'r_coopdb_auth';
GRANT SELECT ON coopdb_seguridad.roles_app TO 'r_coopdb_auth';
GRANT EXECUTE ON PROCEDURE coopdb_seguridad.sp_registrar_evento_acceso TO 'r_coopdb_auth';
GRANT EXECUTE ON PROCEDURE coopdb_seguridad.sp_desactivar_usuario TO 'r_coopdb_auth';
GRANT 'r_coopdb_auth' TO 'coopdb_auth'@'localhost';
SET DEFAULT ROLE 'r_coopdb_auth' TO 'coopdb_auth'@'localhost';
-- IMPORTANTE: cuenta de servicio solo en backend de confianza, nunca distribuida en cliente público.
