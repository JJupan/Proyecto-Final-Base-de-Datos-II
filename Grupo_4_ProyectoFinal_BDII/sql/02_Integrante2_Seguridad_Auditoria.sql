/* 
   INTEGRANTE 2: SEGURIDAD Y AUDITORÍA
   Ejecutar después del Integrante 1.
   ============================================================ */


/* ============================================================
   1. CREACIÓN DEL ESQUEMA DE SEGURIDAD
   ============================================================ */

CREATE DATABASE IF NOT EXISTS coopdb_seguridad
CHARACTER SET utf8mb4
COLLATE utf8mb4_0900_ai_ci;

USE coopdb_seguridad;


/* ============================================================
   2. CREACIÓN DE TABLAS
   ============================================================ */

CREATE TABLE IF NOT EXISTS roles_app (
    rol_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL UNIQUE,
    descripcion VARCHAR(150) NOT NULL
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS usuarios_app (
    usuario_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre_usuario VARCHAR(60) NOT NULL UNIQUE,
    nombre_completo VARCHAR(130) NOT NULL,
    clave_hash VARCHAR(100) NOT NULL
        COMMENT 'Hash bcrypt con salt individual',
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    bloqueado BOOLEAN NOT NULL DEFAULT FALSE,
    intentos_fallidos TINYINT UNSIGNED NOT NULL DEFAULT 0,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso DATETIME NULL,

    CONSTRAINT chk_intentos
    CHECK (intentos_fallidos <= 3)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS usuario_rol (
    usuario_id BIGINT UNSIGNED NOT NULL,
    rol_id SMALLINT UNSIGNED NOT NULL,

    PRIMARY KEY (usuario_id, rol_id),

    CONSTRAINT fk_ur_usuario
    FOREIGN KEY (usuario_id)
    REFERENCES usuarios_app(usuario_id),

    CONSTRAINT fk_ur_rol
    FOREIGN KEY (rol_id)
    REFERENCES roles_app(rol_id)
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

    INDEX ix_bitacora_fecha (fecha_hora),
    INDEX ix_bitacora_tabla (tabla_afectada)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS eventos_acceso (
    evento_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    nombre_usuario VARCHAR(60) NOT NULL,

    resultado ENUM(
        'EXITO',
        'FALLO',
        'BLOQUEO',
        'DENEGADO'
    ) NOT NULL,

    detalle VARCHAR(180) NULL,

    INDEX ix_eventos_usuario_fecha (
        nombre_usuario,
        fecha_hora
    )
) ENGINE=InnoDB;


/* ============================================================
   3. INSERTAR ROLES DE LA APLICACIÓN
   ============================================================ */

INSERT INTO roles_app (nombre, descripcion)
VALUES
('ADMIN', 'Administra usuarios y roles de la aplicación'),
('CAJERO', 'Consulta asociados, saldos y operaciones permitidas'),
('AUDITOR', 'Consulta bitácora sin modificarla'),
('GERENTE', 'Supervisa reportes y bitácora')

ON DUPLICATE KEY UPDATE
descripcion = VALUES(descripcion);


/* ============================================================
   4. TRIGGERS DE AUDITORÍA
   ============================================================ */

DELIMITER $$


/* Auditoría de cambios en saldos de cuentas */

DROP TRIGGER IF EXISTS coopdb_core.trg_audit_saldo$$

CREATE TRIGGER coopdb_core.trg_audit_saldo
AFTER UPDATE ON coopdb_core.cuentas
FOR EACH ROW
BEGIN

    IF NOT (OLD.saldo <=> NEW.saldo) THEN

        INSERT INTO coopdb_seguridad.bitacora_auditoria (
            usuario_bd,
            usuario_app,
            tabla_afectada,
            operacion,
            registro_id,
            valor_anterior,
            valor_nuevo
        )
        VALUES (
            USER(),
            @coopdb_actor,
            'coopdb_core.cuentas',
            'UPDATE_SALDO',
            CAST(NEW.cuenta_id AS CHAR),
            JSON_OBJECT('saldo', OLD.saldo),
            JSON_OBJECT('saldo', NEW.saldo)
        );

    END IF;

END$$


/* Auditoría de cambios en tasas de préstamos */

DROP TRIGGER IF EXISTS coopdb_core.trg_audit_tasa$$

CREATE TRIGGER coopdb_core.trg_audit_tasa
AFTER UPDATE ON coopdb_core.tipos_prestamo
FOR EACH ROW
BEGIN

    IF NOT (OLD.tasa_anual <=> NEW.tasa_anual) THEN

        INSERT INTO coopdb_seguridad.bitacora_auditoria (
            usuario_bd,
            usuario_app,
            tabla_afectada,
            operacion,
            registro_id,
            valor_anterior,
            valor_nuevo
        )
        VALUES (
            USER(),
            @coopdb_actor,
            'coopdb_core.tipos_prestamo',
            'UPDATE_TASA',
            CAST(NEW.tipo_prestamo_id AS CHAR),
            JSON_OBJECT('tasa_anual', OLD.tasa_anual),
            JSON_OBJECT('tasa_anual', NEW.tasa_anual)
        );

    END IF;

END$$


/* Auditoría de cambios en usuarios */

DROP TRIGGER IF EXISTS coopdb_seguridad.trg_audit_usuarios$$

CREATE TRIGGER coopdb_seguridad.trg_audit_usuarios
AFTER UPDATE ON coopdb_seguridad.usuarios_app
FOR EACH ROW
BEGIN

    IF NOT (OLD.activo <=> NEW.activo)
       OR NOT (OLD.bloqueado <=> NEW.bloqueado) THEN

        INSERT INTO coopdb_seguridad.bitacora_auditoria (
            usuario_bd,
            usuario_app,
            tabla_afectada,
            operacion,
            registro_id,
            valor_anterior,
            valor_nuevo
        )
        VALUES (
            USER(),
            @coopdb_actor,
            'coopdb_seguridad.usuarios_app',
            'UPDATE_ESTADO',
            CAST(NEW.usuario_id AS CHAR),

            JSON_OBJECT(
                'activo', OLD.activo,
                'bloqueado', OLD.bloqueado
            ),

            JSON_OBJECT(
                'activo', NEW.activo,
                'bloqueado', NEW.bloqueado
            )
        );

    END IF;

END$$


/* ============================================================
   5. PROCEDIMIENTOS ALMACENADOS
   ============================================================ */


/* Registrar eventos de acceso */

DROP PROCEDURE IF EXISTS
coopdb_seguridad.sp_registrar_evento_acceso$$

CREATE PROCEDURE coopdb_seguridad.sp_registrar_evento_acceso(
    IN p_usuario VARCHAR(60),
    IN p_resultado VARCHAR(15),
    IN p_detalle VARCHAR(180)
)
SQL SECURITY DEFINER
BEGIN

    IF p_resultado NOT IN (
        'EXITO',
        'FALLO',
        'BLOQUEO',
        'DENEGADO'
    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Resultado de acceso no permitido';

    END IF;

    INSERT INTO coopdb_seguridad.eventos_acceso (
        nombre_usuario,
        resultado,
        detalle
    )
    VALUES (
        p_usuario,
        p_resultado,
        p_detalle
    );

END$$


/* Desactivar un usuario */

DROP PROCEDURE IF EXISTS
coopdb_seguridad.sp_desactivar_usuario$$

CREATE PROCEDURE coopdb_seguridad.sp_desactivar_usuario(
    IN p_usuario_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM coopdb_seguridad.usuarios_app
        WHERE usuario_id = p_usuario_id
    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Usuario no encontrado';

    END IF;

    UPDATE coopdb_seguridad.usuarios_app
    SET activo = FALSE
    WHERE usuario_id = p_usuario_id;

END$$


DELIMITER ;


/* ============================================================
   6. CREACIÓN DE VISTAS
   ============================================================ */


/* Vista de saldos para cajeros */

CREATE OR REPLACE
SQL SECURITY DEFINER
VIEW coopdb_seguridad.v_saldos_cajero AS

SELECT
    c.cuenta_id,
    c.numero_cuenta,
    a.codigo AS codigo_asociado,
    CONCAT(a.nombres, ' ', a.apellidos) AS asociado,
    c.saldo,
    c.estado,
    c.agencia_id

FROM coopdb_core.cuentas c

INNER JOIN coopdb_core.asociados a
ON a.asociado_id = c.asociado_id;


/* Vista de información pública de asociados */

CREATE OR REPLACE
SQL SECURITY DEFINER
VIEW coopdb_seguridad.v_asociados_publicos AS

SELECT
    asociado_id,
    codigo,
    nombres,
    apellidos,
    agencia_id,
    activo

FROM coopdb_core.asociados;


/* Vista de consulta de auditoría */

CREATE OR REPLACE
SQL SECURITY DEFINER
VIEW coopdb_seguridad.v_bitacora_consulta AS

SELECT
    auditoria_id,
    fecha_hora,
    usuario_bd,
    usuario_app,
    tabla_afectada,
    operacion,
    registro_id,
    valor_anterior,
    valor_nuevo

FROM coopdb_seguridad.bitacora_auditoria;


/* ============================================================
   7. CREACIÓN DE ROLES DE MYSQL
   ============================================================ */

CREATE ROLE IF NOT EXISTS
    'r_coopdb_cajero',
    'r_coopdb_auditor',
    'r_coopdb_gerente',
    'r_coopdb_admin',
    'r_coopdb_auth';


/* ============================================================
   8. CREACIÓN DE USUARIOS MYSQL
   ============================================================ */

CREATE USER IF NOT EXISTS
'coopdb_cajero'@'localhost'
IDENTIFIED BY 'Cajero123';

ALTER USER
'coopdb_cajero'@'localhost'
IDENTIFIED BY 'Cajero123';


CREATE USER IF NOT EXISTS
'coopdb_auditor'@'localhost'
IDENTIFIED BY 'Auditor123';

ALTER USER
'coopdb_auditor'@'localhost'
IDENTIFIED BY 'Auditor123';


CREATE USER IF NOT EXISTS
'coopdb_gerente'@'localhost'
IDENTIFIED BY 'Gerente123';

ALTER USER
'coopdb_gerente'@'localhost'
IDENTIFIED BY 'Gerente123';


CREATE USER IF NOT EXISTS
'coopdb_admin'@'localhost'
IDENTIFIED BY 'Admin123';

ALTER USER
'coopdb_admin'@'localhost'
IDENTIFIED BY 'Admin123';


/* Usuario de servicio para autenticación de la aplicación */

CREATE USER IF NOT EXISTS
'coopdb_auth'@'localhost'
IDENTIFIED BY 'Auth123';

ALTER USER
'coopdb_auth'@'localhost'
IDENTIFIED BY 'Auth123';


/* ============================================================
   9. ASIGNACIÓN DE PERMISOS A LOS ROLES
   ============================================================ */


/* Permisos del cajero */

GRANT SELECT
ON coopdb_seguridad.v_saldos_cajero
TO 'r_coopdb_cajero';

GRANT SELECT
ON coopdb_seguridad.v_asociados_publicos
TO 'r_coopdb_cajero';


/* Permisos del auditor */

GRANT SELECT
ON coopdb_seguridad.v_bitacora_consulta
TO 'r_coopdb_auditor';


/* Permisos del gerente */

GRANT SELECT
ON coopdb_seguridad.v_bitacora_consulta
TO 'r_coopdb_gerente';

GRANT SELECT
ON coopdb_seguridad.v_saldos_cajero
TO 'r_coopdb_gerente';

GRANT SELECT
ON coopdb_seguridad.v_asociados_publicos
TO 'r_coopdb_gerente';


/* Permisos del administrador */

GRANT SELECT, INSERT, UPDATE
ON coopdb_seguridad.usuarios_app
TO 'r_coopdb_admin';

GRANT SELECT, INSERT, DELETE
ON coopdb_seguridad.usuario_rol
TO 'r_coopdb_admin';

GRANT SELECT
ON coopdb_seguridad.roles_app
TO 'r_coopdb_admin';

GRANT SELECT
ON coopdb_seguridad.v_bitacora_consulta
TO 'r_coopdb_admin';

GRANT EXECUTE
ON PROCEDURE coopdb_seguridad.sp_desactivar_usuario
TO 'r_coopdb_admin';

GRANT EXECUTE
ON PROCEDURE coopdb_seguridad.sp_registrar_evento_acceso
TO 'r_coopdb_admin';


/* Permisos del servicio de autenticación */

GRANT SELECT, INSERT, UPDATE
ON coopdb_seguridad.usuarios_app
TO 'r_coopdb_auth';

GRANT SELECT, INSERT, DELETE
ON coopdb_seguridad.usuario_rol
TO 'r_coopdb_auth';

GRANT SELECT
ON coopdb_seguridad.roles_app
TO 'r_coopdb_auth';

GRANT EXECUTE
ON PROCEDURE coopdb_seguridad.sp_registrar_evento_acceso
TO 'r_coopdb_auth';

GRANT EXECUTE
ON PROCEDURE coopdb_seguridad.sp_desactivar_usuario
TO 'r_coopdb_auth';


/* ============================================================
   10. ASIGNACIÓN DE ROLES A LOS USUARIOS
   ============================================================ */

GRANT 'r_coopdb_cajero'
TO 'coopdb_cajero'@'localhost';

GRANT 'r_coopdb_auditor'
TO 'coopdb_auditor'@'localhost';

GRANT 'r_coopdb_gerente'
TO 'coopdb_gerente'@'localhost';

GRANT 'r_coopdb_admin'
TO 'coopdb_admin'@'localhost';

GRANT 'r_coopdb_auth'
TO 'coopdb_auth'@'localhost';


/* Establecer roles predeterminados */

SET DEFAULT ROLE 'r_coopdb_cajero'
TO 'coopdb_cajero'@'localhost';

SET DEFAULT ROLE 'r_coopdb_auditor'
TO 'coopdb_auditor'@'localhost';

SET DEFAULT ROLE 'r_coopdb_gerente'
TO 'coopdb_gerente'@'localhost';

SET DEFAULT ROLE 'r_coopdb_admin'
TO 'coopdb_admin'@'localhost';

SET DEFAULT ROLE 'r_coopdb_auth'
TO 'coopdb_auth'@'localhost';


/* ============================================================
   11. CONSULTAS DE VERIFICACIÓN
   ============================================================ */


/* Verificar esquemas */

SHOW DATABASES LIKE 'coopdb%';


/* Verificar usuarios */

SELECT
    user,
    host
FROM mysql.user
WHERE user LIKE 'coopdb_%';


/* Verificar roles de aplicación */

SELECT *
FROM coopdb_seguridad.roles_app;


/* Verificar usuarios de aplicación */

SELECT
    usuario_id,
    nombre_usuario,
    nombre_completo,
    activo,
    bloqueado,
    intentos_fallidos
FROM coopdb_seguridad.usuarios_app;


/* Verificar vistas */

SELECT *
FROM coopdb_seguridad.v_asociados_publicos
LIMIT 10;

SELECT *
FROM coopdb_seguridad.v_saldos_cajero
LIMIT 10;


/* Verificar bitácora */

SELECT *
FROM coopdb_seguridad.v_bitacora_consulta
ORDER BY auditoria_id DESC
LIMIT 10;


/* Verificar eventos de acceso */

SELECT *
FROM coopdb_seguridad.eventos_acceso
ORDER BY evento_id DESC
LIMIT 10;


/* Verificar triggers */

SELECT
    TRIGGER_NAME,
    EVENT_OBJECT_TABLE,
    TRIGGER_SCHEMA
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA IN (
    'coopdb_core',
    'coopdb_seguridad'
);


/* Verificar procedimientos */

SELECT
    ROUTINE_NAME,
    ROUTINE_TYPE
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'coopdb_seguridad'
AND ROUTINE_TYPE = 'PROCEDURE';


/* FIN DEL SCRIPT DEL INTEGRANTE 2 */