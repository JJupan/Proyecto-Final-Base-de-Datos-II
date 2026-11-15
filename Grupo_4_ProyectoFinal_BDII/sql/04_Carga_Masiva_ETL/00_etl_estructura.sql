-- CoopDB | Integrante 4 | MySQL 8.0+
-- Ejecutar despues de los modulos 1, 2 y 3. No modifica saldos ni movimientos.
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
