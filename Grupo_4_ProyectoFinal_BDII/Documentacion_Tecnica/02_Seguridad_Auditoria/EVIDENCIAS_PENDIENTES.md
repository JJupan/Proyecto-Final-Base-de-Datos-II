# Evidencias que deben capturarse en MySQL Workbench y en la aplicación
No se han ejecutado consultas contra tu MySQL; NO son capturas ni resultados fabricados.

1. SHOW DATABASES LIKE 'coopdb%': ambos esquemas.
2. Usuarios, SHOW GRANTS FOR 'coopdb_cajero'@'localhost', SHOW GRANTS FOR 'coopdb_auditor'@'localhost'.
3. SELECT a la vista de cajero (sin DPI) y rechazo de SELECT a tabla bitacora_auditoria.
4. Valores dpi_cifrado y nit_cifrado mostrados en HEX (nunca copiar datos personales reales); campos ya existen en Integrante 1.
5. Crear cuenta de prueba con interfaz CLI, login fallido tres veces, estado bloqueado, intento correcto bloqueado.
6. Login correcto de un usuario de prueba no bloqueado y consulta de roles.
7. Ataque de ejemplo con usuario `admin' OR '1'='1` que NO inicia sesión.
8. Modificación de saldo y tasa SOLO con datos de prueba, SELECT a vista de bitácora con valores antiguo/nuevo.
9. Verificación de dos procedimientos en information_schema.ROUTINES.
10. Archivo .sql generado por mysqldump y SELECT COUNT(*) antes/después de restaurar en otra INSTANCIA de prueba.
11. Denegación de DELETE a usuario auditor sobre la tabla de bitácora.
12. Integrar la pantalla de inicio de sesión con el módulo de asociados del integrante 1 antes de presentarlo como aplicación integrada.
