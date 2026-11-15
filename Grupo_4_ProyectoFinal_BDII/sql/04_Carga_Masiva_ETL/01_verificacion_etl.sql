USE coopdb_core;
SELECT COUNT(*) AS asociados_etl FROM asociados WHERE codigo LIKE 'ETL-%';
SELECT COUNT(*) AS cuentas_etl FROM cuentas WHERE numero_cuenta LIKE 'ETL-CTA-%';
SELECT COUNT(*) AS historico_etl FROM etl_historico_cuentas;
SELECT fuente, COUNT(*) AS rechazados FROM etl_rechazos GROUP BY fuente;
SELECT fuente, numero_fila, clave_origen, motivo, rechazado_en
FROM etl_rechazos ORDER BY rechazo_id DESC LIMIT 50;
SELECT agencia, tipo_cuenta, COUNT(*) AS cuentas, SUM(saldo_capturado) AS saldo_total
FROM etl_historico_cuentas GROUP BY agencia,tipo_cuenta ORDER BY agencia,tipo_cuenta;
SELECT * FROM etl_historico_cuentas ORDER BY fecha_captura DESC LIMIT 25;
