-- EJECUTAR DESPUÉS DE Integrante1/sql/00_crear_estructura.sql | MySQL 8.0+
CREATE DATABASE IF NOT EXISTS coopdb_seguridad CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE coopdb_seguridad;
CREATE TABLE IF NOT EXISTS roles_app (
 rol_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 nombre VARCHAR(30) NOT NULL UNIQUE,
 descripcion VARCHAR(150) NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS usuarios_app (
 usuario_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 nombre_usuario VARCHAR(60) NOT NULL UNIQUE,
 nombre_completo VARCHAR(130) NOT NULL,
 clave_hash VARCHAR(100) NOT NULL COMMENT 'Hash bcrypt con salt individual (incluido en formato bcrypt)',
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 bloqueado BOOLEAN NOT NULL DEFAULT FALSE,
 intentos_fallidos TINYINT UNSIGNED NOT NULL DEFAULT 0,
 creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 ultimo_acceso DATETIME NULL,
 CONSTRAINT chk_intentos CHECK (intentos_fallidos <= 3)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS usuario_rol (
 usuario_id BIGINT UNSIGNED NOT NULL,
 rol_id SMALLINT UNSIGNED NOT NULL,
 PRIMARY KEY(usuario_id, rol_id),
 CONSTRAINT fk_ur_usuario FOREIGN KEY(usuario_id) REFERENCES usuarios_app(usuario_id),
 CONSTRAINT fk_ur_rol FOREIGN KEY(rol_id) REFERENCES roles_app(rol_id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS bitacora_auditoria (
 auditoria_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 fecha_hora DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 usuario_bd VARCHAR(255) NOT NULL,
 usuario_app VARCHAR(60) NULL,
 tabla_afectada VARCHAR(100) NOT NULL,
 operacion VARCHAR(25) NOT NULL,
 registro_id VARCHAR(60) NULL,
 valor_anterior JSON NULL,
 valor_nuevo JSON NULL,
 INDEX ix_bitacora_fecha(fecha_hora), INDEX ix_bitacora_tabla(tabla_afectada)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS eventos_acceso (
 evento_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 nombre_usuario VARCHAR(60) NOT NULL,
 resultado ENUM('EXITO','FALLO','BLOQUEO','DENEGADO') NOT NULL,
 detalle VARCHAR(180) NULL,
 INDEX ix_eventos_usuario_fecha(nombre_usuario, fecha_hora)
) ENGINE=InnoDB;
INSERT INTO roles_app(nombre,descripcion) VALUES
 ('ADMIN','Administra usuarios y roles de la aplicación'),
 ('CAJERO','Consulta asociados, saldos y operaciones permitidas'),
 ('AUDITOR','Consulta bitácora sin modificarla'),
 ('GERENTE','Supervisa reportes y bitácora')
ON DUPLICATE KEY UPDATE descripcion=VALUES(descripcion);
