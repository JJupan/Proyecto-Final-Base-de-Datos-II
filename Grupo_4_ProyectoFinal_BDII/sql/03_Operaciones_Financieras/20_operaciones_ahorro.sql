-- CoopDB integrante 3 - ahorro y transferencias | MySQL 8.0+ / InnoDB
-- Requiere integrante 1: 00_crear_estructura.sql y 01_catalogos_demo.sql.
-- Requiere integrante 2 para auditar saldos (trg_audit_saldo).
-- Ejecutar desde usuario administrador en MySQL Workbench.
USE coopdb_core;
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_abrir_cuenta$$
CREATE PROCEDURE sp_abrir_cuenta(IN p_numero VARCHAR(24), IN p_asociado BIGINT UNSIGNED,
  IN p_agencia INT UNSIGNED, IN p_tipo SMALLINT UNSIGNED, OUT p_cuenta BIGINT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_asociado INT DEFAULT 0;
 DECLARE v_tipo INT DEFAULT 0;
 DECLARE v_agencia INT DEFAULT 0;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 IF p_numero IS NULL OR CHAR_LENGTH(TRIM(p_numero)) = 0 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Numero de cuenta requerido'; END IF;
 START TRANSACTION;
 SELECT COUNT(*) INTO v_asociado FROM asociados WHERE asociado_id=p_asociado AND activo=1 AND agencia_id=p_agencia;
 SELECT COUNT(*) INTO v_tipo FROM tipos_cuenta WHERE tipo_cuenta_id=p_tipo AND activa=1;
 SELECT COUNT(*) INTO v_agencia FROM agencias WHERE agencia_id=p_agencia AND activa=1;
 IF v_asociado<>1 OR v_tipo<>1 OR v_agencia<>1 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Asociado, agencia o tipo no valido'; END IF;
 INSERT INTO cuentas(numero_cuenta,asociado_id,agencia_id,tipo_cuenta_id,saldo,estado)
 VALUES(TRIM(p_numero),p_asociado,p_agencia,p_tipo,0,'ACTIVA');
 SET p_cuenta=LAST_INSERT_ID();
 COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_depositar$$
CREATE PROCEDURE sp_depositar(IN p_cuenta BIGINT UNSIGNED, IN p_monto DECIMAL(18,2),
 IN p_referencia VARCHAR(70), OUT p_movimiento BIGINT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_saldo DECIMAL(18,2);
 DECLARE v_estado VARCHAR(12);
 DECLARE v_tipo SMALLINT UNSIGNED;
 DECLARE EXIT HANDLER FOR NOT FOUND BEGIN ROLLBACK; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cuenta o tipo de movimiento no encontrado'; END;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 IF p_monto IS NULL OR p_monto<=0 OR p_referencia IS NULL OR TRIM(p_referencia)='' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Monto o referencia invalida'; END IF;
 START TRANSACTION;
 SELECT saldo,estado INTO v_saldo,v_estado FROM cuentas WHERE cuenta_id=p_cuenta FOR UPDATE;
 IF v_estado<>'ACTIVA' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cuenta no activa'; END IF;
 SELECT tipo_movimiento_id INTO v_tipo FROM tipos_movimiento WHERE codigo='DEPOSITO';
 UPDATE cuentas SET saldo=saldo+p_monto WHERE cuenta_id=p_cuenta;
 INSERT INTO movimientos(cuenta_id,tipo_movimiento_id,monto,saldo_posterior,referencia,descripcion)
 VALUES(p_cuenta,v_tipo,p_monto,v_saldo+p_monto,p_referencia,'Deposito de ahorro');
 SET p_movimiento=LAST_INSERT_ID();
 COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_retirar$$
CREATE PROCEDURE sp_retirar(IN p_cuenta BIGINT UNSIGNED, IN p_monto DECIMAL(18,2),
 IN p_referencia VARCHAR(70), OUT p_movimiento BIGINT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_saldo DECIMAL(18,2); DECLARE v_estado VARCHAR(12);
 DECLARE v_tipo SMALLINT UNSIGNED;
 DECLARE EXIT HANDLER FOR NOT FOUND BEGIN ROLLBACK; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cuenta o tipo no encontrado'; END;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 IF p_monto IS NULL OR p_monto<=0 OR p_referencia IS NULL OR TRIM(p_referencia)='' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Monto o referencia invalida'; END IF;
 START TRANSACTION;
 SELECT saldo,estado INTO v_saldo,v_estado FROM cuentas WHERE cuenta_id=p_cuenta FOR UPDATE;
 IF v_estado<>'ACTIVA' OR v_saldo<p_monto THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cuenta no activa o fondos insuficientes'; END IF;
 SELECT tipo_movimiento_id INTO v_tipo FROM tipos_movimiento WHERE codigo='RETIRO';
 UPDATE cuentas SET saldo=saldo-p_monto WHERE cuenta_id=p_cuenta;
 INSERT INTO movimientos(cuenta_id,tipo_movimiento_id,monto,saldo_posterior,referencia,descripcion)
 VALUES(p_cuenta,v_tipo,p_monto,v_saldo-p_monto,p_referencia,'Retiro de ahorro');
 SET p_movimiento=LAST_INSERT_ID();
 COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_transferir$$
CREATE PROCEDURE sp_transferir(IN p_origen BIGINT UNSIGNED, IN p_destino BIGINT UNSIGNED,
 IN p_monto DECIMAL(18,2), IN p_referencia VARCHAR(70), OUT p_transferencia BIGINT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_saldo_o DECIMAL(18,2); DECLARE v_saldo_d DECIMAL(18,2);
 DECLARE v_estado_o VARCHAR(12); DECLARE v_estado_d VARCHAR(12);
 DECLARE v_id_bajo BIGINT UNSIGNED; DECLARE v_id_alto BIGINT UNSIGNED;
 DECLARE v_dummy BIGINT UNSIGNED;
 DECLARE v_tipo_o SMALLINT UNSIGNED; DECLARE v_tipo_d SMALLINT UNSIGNED;
 DECLARE v_mov_o BIGINT UNSIGNED; DECLARE v_mov_d BIGINT UNSIGNED;
 DECLARE EXIT HANDLER FOR NOT FOUND BEGIN ROLLBACK; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cuenta o catalogo no encontrado'; END;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 IF p_origen IS NULL OR p_destino IS NULL OR p_origen=p_destino OR p_monto IS NULL OR p_monto<=0
 OR p_referencia IS NULL OR TRIM(p_referencia)='' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Datos de transferencia invalidos'; END IF;
 SET v_id_bajo=LEAST(p_origen,p_destino); SET v_id_alto=GREATEST(p_origen,p_destino);
 START TRANSACTION;
 -- Orden fijo de bloqueos evita que dos transferencias inversas se bloqueen mutuamente.
 SELECT cuenta_id INTO v_dummy FROM cuentas WHERE cuenta_id=v_id_bajo FOR UPDATE;
 SELECT cuenta_id INTO v_dummy FROM cuentas WHERE cuenta_id=v_id_alto FOR UPDATE;
 SELECT saldo,estado INTO v_saldo_o,v_estado_o FROM cuentas WHERE cuenta_id=p_origen;
 SELECT saldo,estado INTO v_saldo_d,v_estado_d FROM cuentas WHERE cuenta_id=p_destino;
 IF v_estado_o<>'ACTIVA' OR v_estado_d<>'ACTIVA' OR v_saldo_o<p_monto THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cuenta inactiva o fondos insuficientes'; END IF;
 SELECT tipo_movimiento_id INTO v_tipo_o FROM tipos_movimiento WHERE codigo='TRANSF-OUT';
 SELECT tipo_movimiento_id INTO v_tipo_d FROM tipos_movimiento WHERE codigo='TRANSF-IN';
 UPDATE cuentas SET saldo=saldo-p_monto WHERE cuenta_id=p_origen;
 UPDATE cuentas SET saldo=saldo+p_monto WHERE cuenta_id=p_destino;
 INSERT INTO movimientos(cuenta_id,tipo_movimiento_id,monto,saldo_posterior,referencia,descripcion)
 VALUES(p_origen,v_tipo_o,p_monto,v_saldo_o-p_monto,p_referencia,'Transferencia enviada');
 SET v_mov_o=LAST_INSERT_ID();
 INSERT INTO movimientos(cuenta_id,tipo_movimiento_id,monto,saldo_posterior,referencia,descripcion)
 VALUES(p_destino,v_tipo_d,p_monto,v_saldo_d+p_monto,p_referencia,'Transferencia recibida');
 SET v_mov_d=LAST_INSERT_ID();
 INSERT INTO transferencias(movimiento_origen_id,movimiento_destino_id,referencia)
 VALUES(v_mov_o,v_mov_d,p_referencia);
 SET p_transferencia=LAST_INSERT_ID();
 COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_estado_cuenta$$
CREATE PROCEDURE sp_estado_cuenta(IN p_cuenta BIGINT UNSIGNED, IN p_desde DATE, IN p_hasta DATE)
SQL SECURITY DEFINER
BEGIN
 IF p_desde IS NULL OR p_hasta IS NULL OR p_desde>p_hasta THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fechas invalidas'; END IF;
 SELECT m.movimiento_id,m.ocurrido_en,t.codigo AS tipo,t.naturaleza,m.monto,
 m.saldo_posterior,m.referencia,m.descripcion
 FROM movimientos m JOIN tipos_movimiento t ON m.tipo_movimiento_id=t.tipo_movimiento_id
 WHERE m.cuenta_id=p_cuenta AND m.ocurrido_en>=p_desde
 AND m.ocurrido_en<DATE_ADD(p_hasta, INTERVAL 1 DAY)
 ORDER BY m.ocurrido_en,m.movimiento_id;
END$$
DELIMITER ;
