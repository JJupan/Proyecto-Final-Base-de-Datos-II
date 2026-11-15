-- Verificación de instalación y relaciones; ejecutar después de 00 y 01.
SELECT table_schema, COUNT(*) AS total_tablas
FROM information_schema.tables
WHERE table_schema IN ('coopdb_core','coopdb_seguridad') AND table_type='BASE TABLE'
GROUP BY table_schema;
SELECT table_name, column_name, referenced_table_name, referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema='coopdb_core' AND referenced_table_name IS NOT NULL
ORDER BY table_name, column_name;
SELECT codigo, nombre FROM coopdb_core.agencias ORDER BY codigo;
SELECT codigo, nombre FROM coopdb_core.tipos_movimiento ORDER BY codigo;
-- Lista de asociados, sin revelar DPI ni NIT:
SELECT asociado_id, codigo, nombres, apellidos, activo
FROM coopdb_core.asociados ORDER BY asociado_id DESC LIMIT 20;
