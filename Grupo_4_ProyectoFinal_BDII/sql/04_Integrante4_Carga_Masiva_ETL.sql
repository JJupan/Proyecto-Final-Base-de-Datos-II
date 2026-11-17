/* ================================================================
   COOPDB - INTEGRANTE 4: CARGA MASIVA Y ETL
   SECCIÓN A: ESTRUCTURA ETL
   ================================================================ */

USE coopdb_core;

CREATE TABLE IF NOT EXISTS etl_stg_asociados (
    id_cliente_origen BIGINT NOT NULL PRIMARY KEY,
    codigo VARCHAR(18) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    correo VARCHAR(130) NULL,
    telefono VARCHAR(25) NULL,
    fecha_registro DATE NULL,
    departamento_origen VARCHAR(70) NULL,
    activo TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS etl_stg_cuentas (
    id_cliente_origen BIGINT NOT NULL PRIMARY KEY,
    numero_cuenta VARCHAR(24) NOT NULL,
    codigo_agencia VARCHAR(12) NOT NULL,
    codigo_tipo_cuenta VARCHAR(15) NOT NULL,
    estado_cuenta VARCHAR(12) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS etl_rechazos (
    rechazo_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    fuente VARCHAR(100) NOT NULL,
    numero_fila INT NOT NULL,
    clave_origen VARCHAR(80) NULL,
    motivo VARCHAR(500) NOT NULL,
    registro_json JSON NULL,
    rechazado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX ix_etl_rechazos_fuente (fuente),
    INDEX ix_etl_rechazos_fecha (rechazado_en)
) ENGINE=InnoDB;


/* EVIDENCIA 1: TABLAS CREADAS */

SHOW TABLES LIKE 'etl_%';

DESCRIBE etl_stg_asociados;

DESCRIBE etl_stg_cuentas;

DESCRIBE etl_rechazos;


/* ================================================================
   SECCIÓN B: VERIFICACIÓN POSTERIOR AL ETL
   Ejecutar únicamente después de que Python termine correctamente.
   ================================================================ */

USE coopdb_core;


/* EVIDENCIA 2: ASOCIADOS CARGADOS */

SELECT COUNT(*) AS asociados_etl
FROM asociados
WHERE codigo LIKE 'ETL-%';


/* EVIDENCIA 3: CUENTAS CARGADAS */

SELECT COUNT(*) AS cuentas_etl
FROM cuentas
WHERE numero_cuenta LIKE 'ETL-CTA-%';


/* EVIDENCIA 4: REGISTROS HISTÓRICOS */

SELECT COUNT(*) AS historico_etl
FROM etl_historico_cuentas;


/* EVIDENCIA 5: REGISTROS RECHAZADOS */

SELECT
    fuente,
    COUNT(*) AS rechazados
FROM etl_rechazos
GROUP BY fuente;


/* EVIDENCIA 6: DETALLE DE RECHAZOS */

SELECT
    fuente,
    numero_fila,
    clave_origen,
    motivo,
    rechazado_en
FROM etl_rechazos
ORDER BY rechazo_id DESC
LIMIT 50;


/* EVIDENCIA 7: RESUMEN HISTÓRICO POR AGENCIA Y TIPO DE CUENTA */

SELECT
    agencia,
    tipo_cuenta,
    COUNT(*) AS cuentas,
    SUM(saldo_capturado) AS saldo_total
FROM etl_historico_cuentas
GROUP BY agencia, tipo_cuenta
ORDER BY agencia, tipo_cuenta;


/* EVIDENCIA 8: MUESTRA DEL HISTÓRICO */

SELECT *
FROM etl_historico_cuentas
ORDER BY fecha_captura DESC
LIMIT 25;