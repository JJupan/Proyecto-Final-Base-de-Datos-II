-- Consultas de control para capturas reales. Ejecutar DESPUES de datos demo.
USE coopdb_core;
-- A: Tres transacciones multitabla implementadas:
-- sp_transferir (2 cuentas + 2 movimientos + transferencia)
-- sp_desembolsar_prestamo (cuenta + movimiento + cuotas + prestamo)
-- sp_pagar_cuota (pago + aplicaciones + cuotas + prestamo + cuenta/movimiento opcionales).
SELECT c.numero_cuenta,c.saldo,c.estado FROM cuentas c WHERE c.numero_cuenta LIKE 'FIN-DEMO-%';
SELECT m.movimiento_id,c.numero_cuenta,t.codigo,m.monto,m.saldo_posterior,m.referencia
FROM movimientos m JOIN cuentas c ON m.cuenta_id=c.cuenta_id
JOIN tipos_movimiento t ON m.tipo_movimiento_id=t.tipo_movimiento_id
WHERE m.referencia LIKE 'DEMO-%' ORDER BY m.movimiento_id;
SELECT tr.transferencia_id,tr.referencia,mo.monto AS monto_saliente,md.monto AS monto_entrante
FROM transferencias tr JOIN movimientos mo ON tr.movimiento_origen_id=mo.movimiento_id
JOIN movimientos md ON tr.movimiento_destino_id=md.movimiento_id
WHERE tr.referencia LIKE 'DEMO-%';
SELECT p.numero_prestamo,p.estado,p.monto_aprobado,p.saldo_pendiente,
 (SELECT COALESCE(SUM(ap.capital_pagado),0) FROM aplicaciones_pago ap
 JOIN cuotas_prestamo c ON c.cuota_id=ap.cuota_id WHERE c.prestamo_id=p.prestamo_id) AS capital_pagado
FROM prestamos p WHERE p.numero_prestamo LIKE 'PREST-DEMO-%';
SELECT p.numero_prestamo,COUNT(*) AS total_cuotas,
 ROUND(SUM(c.capital_programado),2) AS suma_capital_programado,p.monto_aprobado
FROM prestamos p JOIN cuotas_prestamo c ON c.prestamo_id=p.prestamo_id
WHERE p.numero_prestamo LIKE 'PREST-DEMO-%' GROUP BY p.prestamo_id;
-- B: Prueba controlada de rechazo/ROLLBACK: ejecutar por separado y capturar error.
-- SET @id_cuenta=(SELECT cuenta_id FROM cuentas WHERE numero_cuenta='FIN-DEMO-0002');
-- SELECT saldo FROM cuentas WHERE cuenta_id=@id_cuenta;
-- CALL sp_retirar(@id_cuenta,999999,'DEMO-RECHAZO-001',@id_movimiento);
-- SELECT saldo FROM cuentas WHERE cuenta_id=@id_cuenta;
-- El saldo no debe cambiar y la referencia DEMO-RECHAZO-001 no debe existir.
-- C: Durabilidad: tras deposito con COMMIT, reiniciar instancia de prueba y
-- ejecutar las mismas SELECT; las filas confirmadas deben persistir.
