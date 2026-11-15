-- Ejecutar después de 10_seguridad_tablas.sql y el DDL principal
DELIMITER $$
DROP TRIGGER IF EXISTS coopdb_core.trg_audit_saldo$$
CREATE TRIGGER coopdb_core.trg_audit_saldo AFTER UPDATE ON coopdb_core.cuentas
FOR EACH ROW
BEGIN
 IF NOT (OLD.saldo <=> NEW.saldo) THEN
  INSERT INTO coopdb_seguridad.bitacora_auditoria
    (usuario_bd,usuario_app,tabla_afectada,operacion,registro_id,valor_anterior,valor_nuevo)
  VALUES (USER(),@coopdb_actor,'coopdb_core.cuentas','UPDATE_SALDO',CAST(NEW.cuenta_id AS CHAR),
          JSON_OBJECT('saldo',OLD.saldo),JSON_OBJECT('saldo',NEW.saldo));
 END IF;
END$$
DROP TRIGGER IF EXISTS coopdb_core.trg_audit_tasa$$
CREATE TRIGGER coopdb_core.trg_audit_tasa AFTER UPDATE ON coopdb_core.tipos_prestamo
FOR EACH ROW
BEGIN
 IF NOT (OLD.tasa_anual <=> NEW.tasa_anual) THEN
  INSERT INTO coopdb_seguridad.bitacora_auditoria
    (usuario_bd,usuario_app,tabla_afectada,operacion,registro_id,valor_anterior,valor_nuevo)
  VALUES (USER(),@coopdb_actor,'coopdb_core.tipos_prestamo','UPDATE_TASA',CAST(NEW.tipo_prestamo_id AS CHAR),
          JSON_OBJECT('tasa_anual',OLD.tasa_anual),JSON_OBJECT('tasa_anual',NEW.tasa_anual));
 END IF;
END$$
DROP TRIGGER IF EXISTS coopdb_seguridad.trg_audit_usuarios$$
CREATE TRIGGER coopdb_seguridad.trg_audit_usuarios AFTER UPDATE ON coopdb_seguridad.usuarios_app
FOR EACH ROW
BEGIN
 IF NOT (OLD.activo <=> NEW.activo) OR NOT (OLD.bloqueado <=> NEW.bloqueado) THEN
  INSERT INTO coopdb_seguridad.bitacora_auditoria
    (usuario_bd,usuario_app,tabla_afectada,operacion,registro_id,valor_anterior,valor_nuevo)
  VALUES (USER(),@coopdb_actor,'coopdb_seguridad.usuarios_app','UPDATE_ESTADO',CAST(NEW.usuario_id AS CHAR),
    JSON_OBJECT('activo',OLD.activo,'bloqueado',OLD.bloqueado),
    JSON_OBJECT('activo',NEW.activo,'bloqueado',NEW.bloqueado));
 END IF;
END$$
DROP PROCEDURE IF EXISTS coopdb_seguridad.sp_registrar_evento_acceso$$
CREATE PROCEDURE coopdb_seguridad.sp_registrar_evento_acceso(
 IN p_usuario VARCHAR(60),IN p_resultado VARCHAR(15),IN p_detalle VARCHAR(180))
SQL SECURITY DEFINER
BEGIN
 IF p_resultado NOT IN ('EXITO','FALLO','BLOQUEO','DENEGADO') THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Resultado de acceso no permitido';
 END IF;
 INSERT INTO coopdb_seguridad.eventos_acceso(nombre_usuario,resultado,detalle)
 VALUES(p_usuario,p_resultado,p_detalle);
END$$
DROP PROCEDURE IF EXISTS coopdb_seguridad.sp_desactivar_usuario$$
CREATE PROCEDURE coopdb_seguridad.sp_desactivar_usuario(IN p_usuario_id BIGINT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 IF NOT EXISTS(SELECT 1 FROM coopdb_seguridad.usuarios_app WHERE usuario_id=p_usuario_id) THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Usuario no encontrado';
 END IF;
 UPDATE coopdb_seguridad.usuarios_app SET activo=FALSE WHERE usuario_id=p_usuario_id;
END$$
DELIMITER ;
-- Los procedimientos exigen autorización en la aplicación y GRANT EXECUTE mínimo en BD.
-- No conceder EXECUTE del procedimiento de desactivación a cajero/auditor.
