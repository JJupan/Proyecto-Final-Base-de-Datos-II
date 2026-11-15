USE coopdb_core;
CREATE OR REPLACE VIEW v_resumen_cuentas AS
 SELECT c.cuenta_id,c.numero_cuenta,a.codigo AS codigo_asociado,
 CONCAT(a.nombres,' ',a.apellidos) AS nombre_asociado,c.agencia_id,c.saldo,c.estado,
 tc.nombre AS tipo_cuenta
 FROM cuentas c JOIN asociados a ON a.asociado_id=c.asociado_id
 JOIN tipos_cuenta tc ON tc.tipo_cuenta_id=c.tipo_cuenta_id;
CREATE OR REPLACE VIEW v_cartera_prestamos AS
 SELECT p.prestamo_id,p.numero_prestamo,s.asociado_id,s.agencia_id,
 p.monto_aprobado,p.saldo_pendiente,p.tasa_anual_aplicada,p.estado,
 s.plazo_meses,p.fecha_desembolso
 FROM prestamos p JOIN solicitudes_prestamo s ON s.solicitud_id=p.solicitud_id;
CREATE OR REPLACE VIEW v_cuotas_pendientes AS
 SELECT c.prestamo_id,c.numero_cuota,c.fecha_vencimiento,c.estado,
 c.capital_programado-COALESCE(x.cap,0) AS capital_pendiente,
 c.interes_programado-COALESCE(x.inte,0) AS interes_pendiente
 FROM cuotas_prestamo c LEFT JOIN
 (SELECT cuota_id,SUM(capital_pagado) cap,SUM(interes_pagado) inte FROM aplicaciones_pago GROUP BY cuota_id) x
 ON x.cuota_id=c.cuota_id;
