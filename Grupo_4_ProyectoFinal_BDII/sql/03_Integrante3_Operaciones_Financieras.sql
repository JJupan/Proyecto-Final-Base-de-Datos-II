-- ============================================================
-- COOPDB | OPERACIONES FINANCIERAS
-- ============================================================

-- ============================================================
-- OPERACIONES DE AHORRO Y TRANSFERENCIAS
-- ============================================================

USE coopdb_core;
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_abrir_cuenta$$
CREATE PROCEDURE sp_abrir_cuenta(
    IN p_numero VARCHAR(24),
    IN p_asociado BIGINT UNSIGNED,
    IN p_agencia INT UNSIGNED,
    IN p_tipo SMALLINT UNSIGNED,
    OUT p_cuenta BIGINT UNSIGNED
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_asociado INT DEFAULT 0;
    DECLARE v_tipo INT DEFAULT 0;
    DECLARE v_agencia INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_numero IS NULL OR CHAR_LENGTH(TRIM(p_numero)) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Numero de cuenta requerido';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*)
    INTO v_asociado
    FROM asociados
    WHERE asociado_id = p_asociado
      AND activo = 1
      AND agencia_id = p_agencia;

    SELECT COUNT(*)
    INTO v_tipo
    FROM tipos_cuenta
    WHERE tipo_cuenta_id = p_tipo
      AND activa = 1;

    SELECT COUNT(*)
    INTO v_agencia
    FROM agencias
    WHERE agencia_id = p_agencia
      AND activa = 1;

    IF v_asociado <> 1 OR v_tipo <> 1 OR v_agencia <> 1 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Asociado, agencia o tipo no valido';
    END IF;

    INSERT INTO cuentas(
        numero_cuenta,
        asociado_id,
        agencia_id,
        tipo_cuenta_id,
        saldo,
        estado
    )
    VALUES(
        TRIM(p_numero),
        p_asociado,
        p_agencia,
        p_tipo,
        0,
        'ACTIVA'
    );

    SET p_cuenta = LAST_INSERT_ID();

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS sp_depositar$$
CREATE PROCEDURE sp_depositar(
    IN p_cuenta BIGINT UNSIGNED,
    IN p_monto DECIMAL(18,2),
    IN p_referencia VARCHAR(70),
    OUT p_movimiento BIGINT UNSIGNED
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_saldo DECIMAL(18,2);
    DECLARE v_estado VARCHAR(12);
    DECLARE v_tipo SMALLINT UNSIGNED;

    DECLARE EXIT HANDLER FOR NOT FOUND
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cuenta o tipo de movimiento no encontrado';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_monto IS NULL OR p_monto <= 0
       OR p_referencia IS NULL OR TRIM(p_referencia) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Monto o referencia invalida';
    END IF;

    START TRANSACTION;

    SELECT saldo, estado
    INTO v_saldo, v_estado
    FROM cuentas
    WHERE cuenta_id = p_cuenta
    FOR UPDATE;

    IF v_estado <> 'ACTIVA' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cuenta no activa';
    END IF;

    SELECT tipo_movimiento_id
    INTO v_tipo
    FROM tipos_movimiento
    WHERE codigo = 'DEPOSITO';

    UPDATE cuentas
    SET saldo = saldo + p_monto
    WHERE cuenta_id = p_cuenta;

    INSERT INTO movimientos(
        cuenta_id,
        tipo_movimiento_id,
        monto,
        saldo_posterior,
        referencia,
        descripcion
    )
    VALUES(
        p_cuenta,
        v_tipo,
        p_monto,
        v_saldo + p_monto,
        p_referencia,
        'Deposito de ahorro'
    );

    SET p_movimiento = LAST_INSERT_ID();

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS sp_retirar$$
CREATE PROCEDURE sp_retirar(
    IN p_cuenta BIGINT UNSIGNED,
    IN p_monto DECIMAL(18,2),
    IN p_referencia VARCHAR(70),
    OUT p_movimiento BIGINT UNSIGNED
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_saldo DECIMAL(18,2);
    DECLARE v_estado VARCHAR(12);
    DECLARE v_tipo SMALLINT UNSIGNED;

    DECLARE EXIT HANDLER FOR NOT FOUND
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cuenta o tipo no encontrado';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_monto IS NULL OR p_monto <= 0
       OR p_referencia IS NULL OR TRIM(p_referencia) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Monto o referencia invalida';
    END IF;

    START TRANSACTION;

    SELECT saldo, estado
    INTO v_saldo, v_estado
    FROM cuentas
    WHERE cuenta_id = p_cuenta
    FOR UPDATE;

    IF v_estado <> 'ACTIVA' OR v_saldo < p_monto THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cuenta no activa o fondos insuficientes';
    END IF;

    SELECT tipo_movimiento_id
    INTO v_tipo
    FROM tipos_movimiento
    WHERE codigo = 'RETIRO';

    UPDATE cuentas
    SET saldo = saldo - p_monto
    WHERE cuenta_id = p_cuenta;

    INSERT INTO movimientos(
        cuenta_id,
        tipo_movimiento_id,
        monto,
        saldo_posterior,
        referencia,
        descripcion
    )
    VALUES(
        p_cuenta,
        v_tipo,
        p_monto,
        v_saldo - p_monto,
        p_referencia,
        'Retiro de ahorro'
    );

    SET p_movimiento = LAST_INSERT_ID();

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS sp_transferir$$
CREATE PROCEDURE sp_transferir(
    IN p_origen BIGINT UNSIGNED,
    IN p_destino BIGINT UNSIGNED,
    IN p_monto DECIMAL(18,2),
    IN p_referencia VARCHAR(70),
    OUT p_transferencia BIGINT UNSIGNED
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_saldo_o DECIMAL(18,2);
    DECLARE v_saldo_d DECIMAL(18,2);
    DECLARE v_estado_o VARCHAR(12);
    DECLARE v_estado_d VARCHAR(12);
    DECLARE v_id_bajo BIGINT UNSIGNED;
    DECLARE v_id_alto BIGINT UNSIGNED;
    DECLARE v_dummy BIGINT UNSIGNED;
    DECLARE v_tipo_o SMALLINT UNSIGNED;
    DECLARE v_tipo_d SMALLINT UNSIGNED;
    DECLARE v_mov_o BIGINT UNSIGNED;
    DECLARE v_mov_d BIGINT UNSIGNED;

    DECLARE EXIT HANDLER FOR NOT FOUND
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cuenta o catalogo no encontrado';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_origen IS NULL OR p_destino IS NULL
       OR p_origen = p_destino
       OR p_monto IS NULL OR p_monto <= 0
       OR p_referencia IS NULL OR TRIM(p_referencia) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Datos de transferencia invalidos';
    END IF;

    SET v_id_bajo = LEAST(p_origen, p_destino);
    SET v_id_alto = GREATEST(p_origen, p_destino);

    START TRANSACTION;

    SELECT cuenta_id
    INTO v_dummy
    FROM cuentas
    WHERE cuenta_id = v_id_bajo
    FOR UPDATE;

    SELECT cuenta_id
    INTO v_dummy
    FROM cuentas
    WHERE cuenta_id = v_id_alto
    FOR UPDATE;

    SELECT saldo, estado
    INTO v_saldo_o, v_estado_o
    FROM cuentas
    WHERE cuenta_id = p_origen;

    SELECT saldo, estado
    INTO v_saldo_d, v_estado_d
    FROM cuentas
    WHERE cuenta_id = p_destino;

    IF v_estado_o <> 'ACTIVA'
       OR v_estado_d <> 'ACTIVA'
       OR v_saldo_o < p_monto THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cuenta inactiva o fondos insuficientes';
    END IF;

    SELECT tipo_movimiento_id
    INTO v_tipo_o
    FROM tipos_movimiento
    WHERE codigo = 'TRANSF-OUT';

    SELECT tipo_movimiento_id
    INTO v_tipo_d
    FROM tipos_movimiento
    WHERE codigo = 'TRANSF-IN';

    UPDATE cuentas
    SET saldo = saldo - p_monto
    WHERE cuenta_id = p_origen;

    UPDATE cuentas
    SET saldo = saldo + p_monto
    WHERE cuenta_id = p_destino;

    INSERT INTO movimientos(
        cuenta_id,
        tipo_movimiento_id,
        monto,
        saldo_posterior,
        referencia,
        descripcion
    )
    VALUES(
        p_origen,
        v_tipo_o,
        p_monto,
        v_saldo_o - p_monto,
        p_referencia,
        'Transferencia enviada'
    );

    SET v_mov_o = LAST_INSERT_ID();

    INSERT INTO movimientos(
        cuenta_id,
        tipo_movimiento_id,
        monto,
        saldo_posterior,
        referencia,
        descripcion
    )
    VALUES(
        p_destino,
        v_tipo_d,
        p_monto,
        v_saldo_d + p_monto,
        p_referencia,
        'Transferencia recibida'
    );

    SET v_mov_d = LAST_INSERT_ID();

    INSERT INTO transferencias(
        movimiento_origen_id,
        movimiento_destino_id,
        referencia
    )
    VALUES(
        v_mov_o,
        v_mov_d,
        p_referencia
    );

    SET p_transferencia = LAST_INSERT_ID();

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS sp_estado_cuenta$$
CREATE PROCEDURE sp_estado_cuenta(
    IN p_cuenta BIGINT UNSIGNED,
    IN p_desde DATE,
    IN p_hasta DATE
)
SQL SECURITY DEFINER
BEGIN
    IF p_desde IS NULL OR p_hasta IS NULL OR p_desde > p_hasta THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fechas invalidas';
    END IF;

    SELECT
        m.movimiento_id,
        m.ocurrido_en,
        t.codigo AS tipo,
        t.naturaleza,
        m.monto,
        m.saldo_posterior,
        m.referencia,
        m.descripcion
    FROM movimientos m
    JOIN tipos_movimiento t
        ON m.tipo_movimiento_id = t.tipo_movimiento_id
    WHERE m.cuenta_id = p_cuenta
      AND m.ocurrido_en >= p_desde
      AND m.ocurrido_en < DATE_ADD(p_hasta, INTERVAL 1 DAY)
    ORDER BY m.ocurrido_en, m.movimiento_id;
END$$

DELIMITER ;


-- ============================================================
-- SOLICITUDES Y OPERACIONES DE PRESTAMOS
-- ============================================================

USE coopdb_core;
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_solicitar_prestamo$$
CREATE PROCEDURE sp_solicitar_prestamo(
    IN p_asociado BIGINT UNSIGNED,
    IN p_agencia INT UNSIGNED,
    IN p_tipo SMALLINT UNSIGNED,
    IN p_monto DECIMAL(18,2),
    IN p_plazo SMALLINT UNSIGNED,
    OUT p_solicitud BIGINT UNSIGNED
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_max SMALLINT UNSIGNED;
    DECLARE v_activo BOOLEAN;
    DECLARE v_asociado INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR NOT FOUND
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Tipo de prestamo no encontrado';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_monto IS NULL OR p_monto <= 0
       OR p_plazo IS NULL OR p_plazo = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Monto o plazo invalido';
    END IF;

    START TRANSACTION;

    SELECT plazo_max_meses, activo
    INTO v_max, v_activo
    FROM tipos_prestamo
    WHERE tipo_prestamo_id = p_tipo;

    SELECT COUNT(*)
    INTO v_asociado
    FROM asociados a
    JOIN agencias g ON g.agencia_id = a.agencia_id
    WHERE a.asociado_id = p_asociado
      AND a.agencia_id = p_agencia
      AND a.activo = 1
      AND g.activa = 1;

    IF NOT v_activo OR p_plazo > v_max OR v_asociado <> 1 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Asociado o condiciones de prestamo no validas';
    END IF;

    INSERT INTO solicitudes_prestamo(
        asociado_id,
        agencia_id,
        tipo_prestamo_id,
        monto_solicitado,
        plazo_meses
    )
    VALUES(
        p_asociado,
        p_agencia,
        p_tipo,
        p_monto,
        p_plazo
    );

    SET p_solicitud = LAST_INSERT_ID();

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS sp_resolver_solicitud$$
CREATE PROCEDURE sp_resolver_solicitud(
    IN p_solicitud BIGINT UNSIGNED,
    IN p_aprobar BOOLEAN,
    IN p_numero VARCHAR(24),
    IN p_observacion VARCHAR(200),
    OUT p_prestamo BIGINT UNSIGNED
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_estado VARCHAR(12);
    DECLARE v_monto DECIMAL(18,2);
    DECLARE v_tipo SMALLINT UNSIGNED;
    DECLARE v_tasa DECIMAL(7,4);

    DECLARE EXIT HANDLER FOR NOT FOUND
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Solicitud o tipo inexistente';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_prestamo = NULL;

    START TRANSACTION;

    SELECT estado, monto_solicitado, tipo_prestamo_id
    INTO v_estado, v_monto, v_tipo
    FROM solicitudes_prestamo
    WHERE solicitud_id = p_solicitud
    FOR UPDATE;

    IF v_estado <> 'PENDIENTE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Solicitud ya resuelta';
    END IF;

    IF p_aprobar THEN

        IF p_numero IS NULL OR TRIM(p_numero) = '' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Numero de prestamo requerido';
        END IF;

        SELECT tasa_anual
        INTO v_tasa
        FROM tipos_prestamo
        WHERE tipo_prestamo_id = v_tipo;

        INSERT INTO prestamos(
            solicitud_id,
            numero_prestamo,
            monto_aprobado,
            tasa_anual_aplicada,
            saldo_pendiente,
            estado
        )
        VALUES(
            p_solicitud,
            p_numero,
            v_monto,
            v_tasa,
            v_monto,
            'APROBADO'
        );

        SET p_prestamo = LAST_INSERT_ID();

        UPDATE solicitudes_prestamo
        SET estado = 'APROBADA',
            resuelta_en = NOW(),
            observacion = p_observacion
        WHERE solicitud_id = p_solicitud;

    ELSE

        UPDATE solicitudes_prestamo
        SET estado = 'RECHAZADA',
            resuelta_en = NOW(),
            observacion = p_observacion
        WHERE solicitud_id = p_solicitud;

    END IF;

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS sp_desembolsar_prestamo$$
CREATE PROCEDURE sp_desembolsar_prestamo(
    IN p_prestamo BIGINT UNSIGNED,
    IN p_cuenta BIGINT UNSIGNED,
    IN p_referencia VARCHAR(70),
    OUT p_movimiento BIGINT UNSIGNED
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_estado VARCHAR(12);
    DECLARE v_monto DECIMAL(18,2);
    DECLARE v_solicitud BIGINT UNSIGNED;
    DECLARE v_asociado BIGINT UNSIGNED;
    DECLARE v_cuenta_asociado BIGINT UNSIGNED;
    DECLARE v_saldo DECIMAL(18,2);
    DECLARE v_estado_cuenta VARCHAR(12);
    DECLARE v_tipo SMALLINT UNSIGNED;
    DECLARE v_plazo SMALLINT UNSIGNED;
    DECLARE v_tasa DECIMAL(7,4);
    DECLARE v_i INT DEFAULT 1;
    DECLARE v_capital DECIMAL(18,2);
    DECLARE v_resto DECIMAL(18,2);
    DECLARE v_interes DECIMAL(18,2);

    DECLARE EXIT HANDLER FOR NOT FOUND
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Prestamo o cuenta no encontrado';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_referencia IS NULL OR TRIM(p_referencia) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Referencia requerida';
    END IF;

    START TRANSACTION;

    SELECT estado, monto_aprobado, solicitud_id, tasa_anual_aplicada
    INTO v_estado, v_monto, v_solicitud, v_tasa
    FROM prestamos
    WHERE prestamo_id = p_prestamo
    FOR UPDATE;

    IF v_estado <> 'APROBADO' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Prestamo ya desembolsado o no aprobado';
    END IF;

    SELECT asociado_id, plazo_meses
    INTO v_asociado, v_plazo
    FROM solicitudes_prestamo
    WHERE solicitud_id = v_solicitud;

    SELECT asociado_id, saldo, estado
    INTO v_cuenta_asociado, v_saldo, v_estado_cuenta
    FROM cuentas
    WHERE cuenta_id = p_cuenta
    FOR UPDATE;

    IF v_asociado <> v_cuenta_asociado OR v_estado_cuenta <> 'ACTIVA' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cuenta no pertenece al asociado o no activa';
    END IF;

    SELECT tipo_movimiento_id
    INTO v_tipo
    FROM tipos_movimiento
    WHERE codigo = 'DESEMBOLSO';

    UPDATE cuentas
    SET saldo = saldo + v_monto
    WHERE cuenta_id = p_cuenta;

    INSERT INTO movimientos(
        cuenta_id,
        tipo_movimiento_id,
        monto,
        saldo_posterior,
        referencia,
        descripcion
    )
    VALUES(
        p_cuenta,
        v_tipo,
        v_monto,
        v_saldo + v_monto,
        p_referencia,
        CONCAT('Desembolso prestamo ', p_prestamo)
    );

    SET p_movimiento = LAST_INSERT_ID();

    SET v_capital = ROUND(v_monto / v_plazo, 2);
    SET v_resto = v_monto;

    WHILE v_i <= v_plazo DO

        SET v_interes = ROUND(v_resto * (v_tasa / 100) / 12, 2);

        INSERT INTO cuotas_prestamo(
            prestamo_id,
            numero_cuota,
            fecha_vencimiento,
            capital_programado,
            interes_programado
        )
        VALUES(
            p_prestamo,
            v_i,
            DATE_ADD(CURDATE(), INTERVAL v_i MONTH),
            IF(v_i = v_plazo, v_resto, v_capital),
            v_interes
        );

        SET v_resto = v_resto - IF(v_i = v_plazo, v_resto, v_capital);
        SET v_i = v_i + 1;

    END WHILE;

    UPDATE prestamos
    SET estado = 'VIGENTE',
        fecha_desembolso = NOW()
    WHERE prestamo_id = p_prestamo;

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS sp_pagar_cuota$$
CREATE PROCEDURE sp_pagar_cuota(
    IN p_prestamo BIGINT UNSIGNED,
    IN p_cuenta_origen BIGINT UNSIGNED,
    IN p_monto DECIMAL(18,2),
    IN p_referencia VARCHAR(70),
    OUT p_pago BIGINT UNSIGNED
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_estado VARCHAR(12);
    DECLARE v_saldo_capital DECIMAL(18,2);
    DECLARE v_solicitud BIGINT UNSIGNED;
    DECLARE v_asociado BIGINT UNSIGNED;
    DECLARE v_cuenta_asociado BIGINT UNSIGNED;
    DECLARE v_cuenta_estado VARCHAR(12);
    DECLARE v_cuenta_saldo DECIMAL(18,2);
    DECLARE v_tipo SMALLINT UNSIGNED;
    DECLARE v_pendiente DECIMAL(18,2);
    DECLARE v_restante DECIMAL(18,2);
    DECLARE v_cuota BIGINT UNSIGNED;
    DECLARE v_debe_cap DECIMAL(18,2);
    DECLARE v_debe_int DECIMAL(18,2);
    DECLARE v_cap DECIMAL(18,2);
    DECLARE v_int DECIMAL(18,2);
    DECLARE v_total_cap DECIMAL(18,2) DEFAULT 0;

    DECLARE EXIT HANDLER FOR NOT FOUND
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Prestamo o cuenta inexistente';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_monto IS NULL OR p_monto <= 0
       OR p_referencia IS NULL OR TRIM(p_referencia) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Monto o referencia invalida';
    END IF;

    START TRANSACTION;

    SELECT estado, saldo_pendiente, solicitud_id
    INTO v_estado, v_saldo_capital, v_solicitud
    FROM prestamos
    WHERE prestamo_id = p_prestamo
    FOR UPDATE;

    IF v_estado <> 'VIGENTE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Prestamo no vigente';
    END IF;

    SELECT asociado_id
    INTO v_asociado
    FROM solicitudes_prestamo
    WHERE solicitud_id = v_solicitud;

    IF p_cuenta_origen IS NOT NULL THEN

        SELECT asociado_id, estado, saldo
        INTO v_cuenta_asociado, v_cuenta_estado, v_cuenta_saldo
        FROM cuentas
        WHERE cuenta_id = p_cuenta_origen
        FOR UPDATE;

        IF v_cuenta_asociado <> v_asociado
           OR v_cuenta_estado <> 'ACTIVA'
           OR v_cuenta_saldo < p_monto THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cuenta no valida o fondos insuficientes';
        END IF;

    END IF;

    SELECT COALESCE(SUM(
        c.capital_programado + c.interes_programado
        - COALESCE(x.cap, 0)
        - COALESCE(x.inte, 0)
    ), 0)
    INTO v_pendiente
    FROM cuotas_prestamo c
    LEFT JOIN (
        SELECT cuota_id,
               SUM(capital_pagado) cap,
               SUM(interes_pagado) inte
        FROM aplicaciones_pago
        GROUP BY cuota_id
    ) x ON x.cuota_id = c.cuota_id
    WHERE c.prestamo_id = p_prestamo;

    IF p_monto > v_pendiente THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Pago excede deuda pendiente';
    END IF;

    INSERT INTO pagos_prestamo(
        prestamo_id,
        cuenta_origen_id,
        monto_total,
        referencia
    )
    VALUES(
        p_prestamo,
        p_cuenta_origen,
        p_monto,
        p_referencia
    );

    SET p_pago = LAST_INSERT_ID();

    IF p_cuenta_origen IS NOT NULL THEN

        SELECT tipo_movimiento_id
        INTO v_tipo
        FROM tipos_movimiento
        WHERE codigo = 'PAGO-PREST';

        UPDATE cuentas
        SET saldo = saldo - p_monto
        WHERE cuenta_id = p_cuenta_origen;

        INSERT INTO movimientos(
            cuenta_id,
            tipo_movimiento_id,
            monto,
            saldo_posterior,
            referencia,
            descripcion
        )
        VALUES(
            p_cuenta_origen,
            v_tipo,
            p_monto,
            v_cuenta_saldo - p_monto,
            p_referencia,
            CONCAT('Pago prestamo ', p_prestamo)
        );

    END IF;

    SET v_restante = p_monto;

    WHILE v_restante > 0 DO

        SET v_cuota = NULL;

        SELECT
            c.cuota_id,
            c.capital_programado - COALESCE(x.cap, 0),
            c.interes_programado - COALESCE(x.inte, 0)
        INTO v_cuota, v_debe_cap, v_debe_int
        FROM cuotas_prestamo c
        LEFT JOIN (
            SELECT cuota_id,
                   SUM(capital_pagado) cap,
                   SUM(interes_pagado) inte
            FROM aplicaciones_pago
            GROUP BY cuota_id
        ) x ON c.cuota_id = x.cuota_id
        WHERE c.prestamo_id = p_prestamo
          AND c.capital_programado + c.interes_programado
              - COALESCE(x.cap, 0)
              - COALESCE(x.inte, 0) > 0
        ORDER BY c.numero_cuota
        LIMIT 1;

        IF v_cuota IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No existe cuota pendiente';
        END IF;

        SET v_int = LEAST(v_restante, v_debe_int);
        SET v_cap = LEAST(v_restante - v_int, v_debe_cap);

        IF v_int + v_cap <= 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error en aplicacion de pago';
        END IF;

        INSERT INTO aplicaciones_pago(
            pago_id,
            cuota_id,
            capital_pagado,
            interes_pagado
        )
        VALUES(
            p_pago,
            v_cuota,
            v_cap,
            v_int
        );

        SET v_total_cap = v_total_cap + v_cap;
        SET v_restante = ROUND(v_restante - v_cap - v_int, 2);

        UPDATE cuotas_prestamo
        SET estado = IF(
            v_cap = v_debe_cap AND v_int = v_debe_int,
            'PAGADA',
            'PARCIAL'
        )
        WHERE cuota_id = v_cuota;

    END WHILE;

    UPDATE prestamos
    SET saldo_pendiente = saldo_pendiente - v_total_cap
    WHERE prestamo_id = p_prestamo;

    IF (
        SELECT COUNT(*)
        FROM cuotas_prestamo
        WHERE prestamo_id = p_prestamo
          AND estado <> 'PAGADA'
    ) = 0 THEN
        UPDATE prestamos
        SET estado = 'PAGADO'
        WHERE prestamo_id = p_prestamo;
    END IF;

    COMMIT;
END$$

DELIMITER ;


-- ============================================================
-- VISTAS DE CONSULTA Y REPORTES
-- ============================================================

USE coopdb_core;

CREATE OR REPLACE VIEW v_resumen_cuentas AS
SELECT
    c.cuenta_id,
    c.numero_cuenta,
    a.codigo AS codigo_asociado,
    CONCAT(a.nombres, ' ', a.apellidos) AS nombre_asociado,
    c.agencia_id,
    c.saldo,
    c.estado,
    tc.nombre AS tipo_cuenta
FROM cuentas c
JOIN asociados a ON a.asociado_id = c.asociado_id
JOIN tipos_cuenta tc ON tc.tipo_cuenta_id = c.tipo_cuenta_id;


CREATE OR REPLACE VIEW v_cartera_prestamos AS
SELECT
    p.prestamo_id,
    p.numero_prestamo,
    s.asociado_id,
    s.agencia_id,
    p.monto_aprobado,
    p.saldo_pendiente,
    p.tasa_anual_aplicada,
    p.estado,
    s.plazo_meses,
    p.fecha_desembolso
FROM prestamos p
JOIN solicitudes_prestamo s ON s.solicitud_id = p.solicitud_id;


CREATE OR REPLACE VIEW v_cuotas_pendientes AS
SELECT
    c.prestamo_id,
    c.numero_cuota,
    c.fecha_vencimiento,
    c.estado,
    c.capital_programado - COALESCE(x.cap, 0) AS capital_pendiente,
    c.interes_programado - COALESCE(x.inte, 0) AS interes_pendiente
FROM cuotas_prestamo c
LEFT JOIN (
    SELECT
        cuota_id,
        SUM(capital_pagado) cap,
        SUM(interes_pagado) inte
    FROM aplicaciones_pago
    GROUP BY cuota_id
) x ON x.cuota_id = c.cuota_id;


-- ============================================================
-- ROLES Y PERMISOS DEL MODULO FINANCIERO
-- ============================================================

CREATE ROLE IF NOT EXISTS 'r_coopdb_finanzas';

CREATE USER IF NOT EXISTS 'coopdb_finanzas'@'localhost'
IDENTIFIED BY 'CAMBIAR_Finanzas_8N!47xRm#2026';

GRANT EXECUTE ON PROCEDURE coopdb_core.sp_abrir_cuenta
TO 'r_coopdb_finanzas';

GRANT EXECUTE ON PROCEDURE coopdb_core.sp_depositar
TO 'r_coopdb_finanzas';

GRANT EXECUTE ON PROCEDURE coopdb_core.sp_retirar
TO 'r_coopdb_finanzas';

GRANT EXECUTE ON PROCEDURE coopdb_core.sp_transferir
TO 'r_coopdb_finanzas';

GRANT EXECUTE ON PROCEDURE coopdb_core.sp_estado_cuenta
TO 'r_coopdb_finanzas';

GRANT EXECUTE ON PROCEDURE coopdb_core.sp_solicitar_prestamo
TO 'r_coopdb_finanzas';

GRANT EXECUTE ON PROCEDURE coopdb_core.sp_resolver_solicitud
TO 'r_coopdb_finanzas';

GRANT EXECUTE ON PROCEDURE coopdb_core.sp_desembolsar_prestamo
TO 'r_coopdb_finanzas';

GRANT EXECUTE ON PROCEDURE coopdb_core.sp_pagar_cuota
TO 'r_coopdb_finanzas';

GRANT 'r_coopdb_finanzas' TO 'coopdb_finanzas'@'localhost';

SET DEFAULT ROLE 'r_coopdb_finanzas'
TO 'coopdb_finanzas'@'localhost';