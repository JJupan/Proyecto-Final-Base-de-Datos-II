-- CoopDB | Vistas para tres dashboards | MySQL 8.0+
-- Ejecutar después de los módulos 1 y 3.
-- Estas vistas son fuentes para Power BI / Tableau / Metabase.
USE coopdb_core;

-- DASHBOARD 1: captación de ahorro por agencia y mes.
-- Se consideran depósitos y transferencias recibidas, no retiros ni salidas.
CREATE OR REPLACE VIEW v_bi_captacion_agencia_mes AS
SELECT
    g.agencia_id,
    g.codigo AS codigo_agencia,
    g.nombre AS agencia,
    DATE_FORMAT(m.ocurrido_en, '%Y-%m-01') AS mes,
    COUNT(*) AS cantidad_movimientos_entrada,
    SUM(m.monto) AS monto_captado,
    COUNT(DISTINCT c.asociado_id) AS asociados_con_actividad
FROM movimientos m
JOIN cuentas c ON c.cuenta_id = m.cuenta_id
JOIN agencias g ON g.agencia_id = c.agencia_id
JOIN tipos_movimiento tm ON tm.tipo_movimiento_id = m.tipo_movimiento_id
WHERE tm.naturaleza = 'ENTRADA'
  AND tm.codigo IN ('DEPOSITO','TRANSF-IN')
GROUP BY g.agencia_id, g.codigo, g.nombre, DATE_FORMAT(m.ocurrido_en, '%Y-%m-01');

-- DASHBOARD 2: colocación de préstamos por mes y agencia.
CREATE OR REPLACE VIEW v_bi_colocacion_prestamos_mes AS
SELECT
    g.agencia_id,
    g.codigo AS codigo_agencia,
    g.nombre AS agencia,
    DATE_FORMAT(p.fecha_desembolso, '%Y-%m-01') AS mes,
    COUNT(*) AS prestamos_desembolsados,
    SUM(p.monto_aprobado) AS monto_colocado,
    AVG(p.monto_aprobado) AS monto_promedio,
    SUM(p.saldo_pendiente) AS saldo_cartera
FROM prestamos p
JOIN solicitudes_prestamo s ON s.solicitud_id = p.solicitud_id
JOIN agencias g ON g.agencia_id = s.agencia_id
WHERE p.fecha_desembolso IS NOT NULL
GROUP BY g.agencia_id, g.codigo, g.nombre, DATE_FORMAT(p.fecha_desembolso, '%Y-%m-01');

-- DASHBOARD 3: cartera vencida por rangos de días.
-- El saldo vencido se calcula con capital e interés de cuotas vencidas pendientes.
CREATE OR REPLACE VIEW v_bi_cartera_mora AS
SELECT
    g.agencia_id,
    g.codigo AS codigo_agencia,
    g.nombre AS agencia,
    p.prestamo_id,
    p.numero_prestamo,
    p.estado AS estado_prestamo,
    DATEDIFF(CURDATE(), c.fecha_vencimiento) AS dias_mora,
    CASE
      WHEN DATEDIFF(CURDATE(), c.fecha_vencimiento) BETWEEN 1 AND 30 THEN '01-30 días'
      WHEN DATEDIFF(CURDATE(), c.fecha_vencimiento) BETWEEN 31 AND 60 THEN '31-60 días'
      WHEN DATEDIFF(CURDATE(), c.fecha_vencimiento) BETWEEN 61 AND 90 THEN '61-90 días'
      WHEN DATEDIFF(CURDATE(), c.fecha_vencimiento) > 90 THEN 'Más de 90 días'
      ELSE 'No vencida'
    END AS rango_mora,
    GREATEST(c.capital_programado - COALESCE(ap.capital_pagado,0),0)
      + GREATEST(c.interes_programado - COALESCE(ap.interes_pagado,0),0) AS saldo_cuota_vencida
FROM cuotas_prestamo c
JOIN prestamos p ON p.prestamo_id = c.prestamo_id
JOIN solicitudes_prestamo s ON s.solicitud_id = p.solicitud_id
JOIN agencias g ON g.agencia_id = s.agencia_id
LEFT JOIN (
    SELECT cuota_id, SUM(capital_pagado) AS capital_pagado,
           SUM(interes_pagado) AS interes_pagado
    FROM aplicaciones_pago GROUP BY cuota_id
) ap ON ap.cuota_id = c.cuota_id
WHERE c.fecha_vencimiento < CURDATE()
  AND (c.capital_programado - COALESCE(ap.capital_pagado,0)
       + c.interes_programado - COALESCE(ap.interes_pagado,0)) > 0;

-- INDICADORES CALCULADOS adicionales para tarjetas KPI.
CREATE OR REPLACE VIEW v_bi_indicadores_generales AS
SELECT
    (SELECT COUNT(*) FROM asociados WHERE activo = 1) AS asociados_activos,
    (SELECT COUNT(*) FROM cuentas WHERE estado = 'ACTIVA') AS cuentas_activas,
    (SELECT COALESCE(SUM(saldo),0) FROM cuentas WHERE estado = 'ACTIVA') AS ahorro_total,
    (SELECT COALESCE(AVG(saldo),0) FROM cuentas WHERE estado = 'ACTIVA') AS saldo_promedio_cuenta,
    (SELECT COALESCE(SUM(saldo_pendiente),0) FROM prestamos
       WHERE estado IN ('VIGENTE','APROBADO')) AS cartera_pendiente,
    (SELECT COALESCE(SUM(saldo_cuota_vencida),0) FROM v_bi_cartera_mora)
       AS cartera_vencida,
    CASE
      WHEN (SELECT COALESCE(SUM(saldo_pendiente),0) FROM prestamos
            WHERE estado IN ('VIGENTE','APROBADO')) = 0 THEN 0
      ELSE ROUND(
        100 * (SELECT COALESCE(SUM(saldo_cuota_vencida),0) FROM v_bi_cartera_mora)
        / (SELECT SUM(saldo_pendiente) FROM prestamos
           WHERE estado IN ('VIGENTE','APROBADO')), 2)
    END AS indice_morosidad_porcentaje;

-- DASHBOARD 4 opcional: asociados por departamento (útil como visual adicional).
CREATE OR REPLACE VIEW v_bi_asociados_departamento AS
SELECT
    COALESCE(NULLIF(TRIM(direccion),''),'Sin dato') AS departamento,
    COUNT(*) AS cantidad_asociados
FROM asociados
WHERE activo = 1
GROUP BY COALESCE(NULLIF(TRIM(direccion),''),'Sin dato');
