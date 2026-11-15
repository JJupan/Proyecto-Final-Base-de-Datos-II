-- CoopDB | Integrante 1 | MySQL 8.0+ | Ejecutar antes de cualquier otro script
-- NOTA: MySQL utiliza SCHEMA y DATABASE como sinónimos.
-- Se reserva coopdb_seguridad para el módulo del integrante 2.
CREATE DATABASE IF NOT EXISTS coopdb_core CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE IF NOT EXISTS coopdb_seguridad CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE coopdb_core;

CREATE TABLE IF NOT EXISTS agencias (
  agencia_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(12) NOT NULL UNIQUE,
  nombre VARCHAR(100) NOT NULL,
  departamento VARCHAR(70) NOT NULL,
  municipio VARCHAR(70) NOT NULL,
  direccion VARCHAR(180) NULL,
  activa BOOLEAN NOT NULL DEFAULT TRUE,
  creada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS asociados (
  asociado_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(18) NOT NULL UNIQUE,
  agencia_id INT UNSIGNED NOT NULL,
  nombres VARCHAR(100) NOT NULL,
  apellidos VARCHAR(100) NOT NULL,
  fecha_nacimiento DATE NULL,
  telefono VARCHAR(25) NULL,
  correo VARCHAR(130) NULL,
  direccion VARCHAR(200) NULL,
  -- Cifrado AES en la capa de acceso; nunca almacenar DPI/NIT en texto plano.
  dpi_cifrado VARBINARY(256) NOT NULL,
  dpi_hash BINARY(32) NOT NULL UNIQUE,
  nit_cifrado VARBINARY(256) NULL,
  fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  actualizado_en DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_asociados_agencias FOREIGN KEY (agencia_id) REFERENCES agencias(agencia_id),
  INDEX ix_asociados_nombre (apellidos, nombres),
  INDEX ix_asociados_agencia_activo (agencia_id, activo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS beneficiarios (
  beneficiario_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  asociado_id BIGINT UNSIGNED NOT NULL,
  nombres VARCHAR(100) NOT NULL,
  apellidos VARCHAR(100) NOT NULL,
  parentesco VARCHAR(60) NOT NULL,
  porcentaje DECIMAL(5,2) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT chk_beneficiario_porcentaje CHECK (porcentaje > 0 AND porcentaje <= 100),
  CONSTRAINT fk_beneficiarios_asociados FOREIGN KEY (asociado_id) REFERENCES asociados(asociado_id),
  INDEX ix_beneficiarios_asociado (asociado_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tipos_cuenta (
  tipo_cuenta_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(15) NOT NULL UNIQUE,
  nombre VARCHAR(80) NOT NULL,
  tasa_interes_anual DECIMAL(7,4) NOT NULL DEFAULT 0,
  activa BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT chk_tasa_cuenta CHECK (tasa_interes_anual >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cuentas (
  cuenta_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  numero_cuenta VARCHAR(24) NOT NULL UNIQUE,
  asociado_id BIGINT UNSIGNED NOT NULL,
  agencia_id INT UNSIGNED NOT NULL,
  tipo_cuenta_id SMALLINT UNSIGNED NOT NULL,
  saldo DECIMAL(18,2) NOT NULL DEFAULT 0,
  estado ENUM('ACTIVA','BLOQUEADA','CERRADA') NOT NULL DEFAULT 'ACTIVA',
  abierta_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_cuentas_asociados FOREIGN KEY (asociado_id) REFERENCES asociados(asociado_id),
  CONSTRAINT fk_cuentas_agencias FOREIGN KEY (agencia_id) REFERENCES agencias(agencia_id),
  CONSTRAINT fk_cuentas_tipos FOREIGN KEY (tipo_cuenta_id) REFERENCES tipos_cuenta(tipo_cuenta_id),
  CONSTRAINT chk_cuentas_saldo CHECK (saldo >= 0),
  INDEX ix_cuentas_asociado (asociado_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tipos_movimiento (
  tipo_movimiento_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(20) NOT NULL UNIQUE,
  descripcion VARCHAR(100) NOT NULL,
  naturaleza ENUM('ENTRADA','SALIDA') NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS movimientos (
  movimiento_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cuenta_id BIGINT UNSIGNED NOT NULL,
  tipo_movimiento_id SMALLINT UNSIGNED NOT NULL,
  monto DECIMAL(18,2) NOT NULL,
  saldo_posterior DECIMAL(18,2) NOT NULL,
  referencia VARCHAR(70) NOT NULL,
  descripcion VARCHAR(200) NULL,
  ocurrido_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_movimientos_cuentas FOREIGN KEY (cuenta_id) REFERENCES cuentas(cuenta_id),
  CONSTRAINT fk_movimientos_tipos FOREIGN KEY (tipo_movimiento_id) REFERENCES tipos_movimiento(tipo_movimiento_id),
  CONSTRAINT chk_movimiento_monto CHECK (monto > 0),
  CONSTRAINT chk_movimiento_saldo CHECK (saldo_posterior >= 0),
  UNIQUE KEY uq_movimiento_referencia_cuenta_tipo (referencia, cuenta_id, tipo_movimiento_id),
  INDEX ix_movimientos_cuenta_fecha (cuenta_id, ocurrido_en)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS transferencias (
  transferencia_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  movimiento_origen_id BIGINT UNSIGNED NOT NULL UNIQUE,
  movimiento_destino_id BIGINT UNSIGNED NOT NULL UNIQUE,
  referencia VARCHAR(70) NOT NULL UNIQUE,
  realizada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_transferencia_origen FOREIGN KEY (movimiento_origen_id) REFERENCES movimientos(movimiento_id),
  CONSTRAINT fk_transferencia_destino FOREIGN KEY (movimiento_destino_id) REFERENCES movimientos(movimiento_id),
  CONSTRAINT chk_transferencia_movimientos CHECK (movimiento_origen_id <> movimiento_destino_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tipos_prestamo (
  tipo_prestamo_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(15) NOT NULL UNIQUE,
  nombre VARCHAR(80) NOT NULL,
  tasa_anual DECIMAL(7,4) NOT NULL,
  plazo_max_meses SMALLINT UNSIGNED NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT chk_tipo_prestamo_tasa CHECK (tasa_anual >= 0),
  CONSTRAINT chk_tipo_prestamo_plazo CHECK (plazo_max_meses > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS solicitudes_prestamo (
  solicitud_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  asociado_id BIGINT UNSIGNED NOT NULL,
  agencia_id INT UNSIGNED NOT NULL,
  tipo_prestamo_id SMALLINT UNSIGNED NOT NULL,
  monto_solicitado DECIMAL(18,2) NOT NULL,
  plazo_meses SMALLINT UNSIGNED NOT NULL,
  estado ENUM('PENDIENTE','APROBADA','RECHAZADA') NOT NULL DEFAULT 'PENDIENTE',
  solicitada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resuelta_en DATETIME NULL,
  observacion VARCHAR(200) NULL,
  CONSTRAINT fk_solicitudes_asociado FOREIGN KEY (asociado_id) REFERENCES asociados(asociado_id),
  CONSTRAINT fk_solicitudes_agencia FOREIGN KEY (agencia_id) REFERENCES agencias(agencia_id),
  CONSTRAINT fk_solicitudes_tipo FOREIGN KEY (tipo_prestamo_id) REFERENCES tipos_prestamo(tipo_prestamo_id),
  CONSTRAINT chk_solicitud_monto CHECK (monto_solicitado > 0),
  CONSTRAINT chk_solicitud_plazo CHECK (plazo_meses > 0),
  INDEX ix_solicitudes_asociado (asociado_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS prestamos (
  prestamo_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  solicitud_id BIGINT UNSIGNED NOT NULL UNIQUE,
  numero_prestamo VARCHAR(24) NOT NULL UNIQUE,
  monto_aprobado DECIMAL(18,2) NOT NULL,
  tasa_anual_aplicada DECIMAL(7,4) NOT NULL,
  saldo_pendiente DECIMAL(18,2) NOT NULL,
  estado ENUM('APROBADO','VIGENTE','PAGADO','CANCELADO') NOT NULL DEFAULT 'APROBADO',
  fecha_aprobacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_desembolso DATETIME NULL,
  CONSTRAINT fk_prestamos_solicitud FOREIGN KEY (solicitud_id) REFERENCES solicitudes_prestamo(solicitud_id),
  CONSTRAINT chk_prestamo_monto CHECK (monto_aprobado > 0),
  CONSTRAINT chk_prestamo_saldo CHECK (saldo_pendiente >= 0),
  CONSTRAINT chk_prestamo_tasa CHECK (tasa_anual_aplicada >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cuotas_prestamo (
  cuota_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  prestamo_id BIGINT UNSIGNED NOT NULL,
  numero_cuota SMALLINT UNSIGNED NOT NULL,
  fecha_vencimiento DATE NOT NULL,
  capital_programado DECIMAL(18,2) NOT NULL,
  interes_programado DECIMAL(18,2) NOT NULL,
  estado ENUM('PENDIENTE','PARCIAL','PAGADA') NOT NULL DEFAULT 'PENDIENTE',
  CONSTRAINT fk_cuotas_prestamo FOREIGN KEY (prestamo_id) REFERENCES prestamos(prestamo_id),
  CONSTRAINT chk_cuota_capital CHECK (capital_programado >= 0),
  CONSTRAINT chk_cuota_interes CHECK (interes_programado >= 0),
  UNIQUE KEY uq_prestamo_numero_cuota (prestamo_id, numero_cuota),
  INDEX ix_cuotas_vencimiento (fecha_vencimiento, estado)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pagos_prestamo (
  pago_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  prestamo_id BIGINT UNSIGNED NOT NULL,
  cuenta_origen_id BIGINT UNSIGNED NULL,
  monto_total DECIMAL(18,2) NOT NULL,
  referencia VARCHAR(70) NOT NULL UNIQUE,
  pagado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_pagos_prestamo FOREIGN KEY (prestamo_id) REFERENCES prestamos(prestamo_id),
  CONSTRAINT fk_pagos_cuenta_origen FOREIGN KEY (cuenta_origen_id) REFERENCES cuentas(cuenta_id),
  CONSTRAINT chk_pago_monto CHECK (monto_total > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS aplicaciones_pago (
  aplicacion_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pago_id BIGINT UNSIGNED NOT NULL,
  cuota_id BIGINT UNSIGNED NOT NULL,
  capital_pagado DECIMAL(18,2) NOT NULL DEFAULT 0,
  interes_pagado DECIMAL(18,2) NOT NULL DEFAULT 0,
  CONSTRAINT fk_aplicaciones_pago FOREIGN KEY (pago_id) REFERENCES pagos_prestamo(pago_id),
  CONSTRAINT fk_aplicaciones_cuota FOREIGN KEY (cuota_id) REFERENCES cuotas_prestamo(cuota_id),
  CONSTRAINT chk_aplicacion_capital CHECK (capital_pagado >= 0),
  CONSTRAINT chk_aplicacion_interes CHECK (interes_pagado >= 0),
  CONSTRAINT chk_aplicacion_positivo CHECK (capital_pagado + interes_pagado > 0),
  UNIQUE KEY uq_aplicacion_pago_cuota (pago_id, cuota_id)
) ENGINE=InnoDB;

-- IMPORTANTE: La suma de porcentajes de beneficiarios, las operaciones de saldo,
-- los pagos y la correspondencia pago-cuota-prestamo se validan en la lógica transaccional.
-- No ejecutar UPDATE saldo directo fuera de transacciones controladas.
