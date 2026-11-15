-- SOLO ENTORNO DE PRUEBAS LOCAL. Datos ficticios, NUNCA DPI reales.
-- No ejecutar en base con datos reales. Script reutilizable parcialmente:
-- las referencias de transacciones de ejemplo deben ser UNICAS en cada repeticion.
USE coopdb_core;
SET @clave_demo = 'CLAVE_FICTICIA_SOLO_ENTORNO_DEMO_2026';
SET @agencia=(SELECT agencia_id FROM agencias WHERE codigo='CENTRAL');
SET @tipo_ahorro=(SELECT tipo_cuenta_id FROM tipos_cuenta WHERE codigo='AHO-NORMAL');
SET @tipo_prestamo=(SELECT tipo_prestamo_id FROM tipos_prestamo WHERE codigo='PERSONAL');
INSERT INTO asociados(codigo,agencia_id,nombres,apellidos,dpi_cifrado,dpi_hash,nit_cifrado)
VALUES('DEMO-FIN-001',@agencia,'Ana','Prueba',AES_ENCRYPT('0000000000001',@clave_demo),UNHEX(SHA2('0000000000001',256)),AES_ENCRYPT('CF-001',@clave_demo))
ON DUPLICATE KEY UPDATE codigo=VALUES(codigo);
INSERT INTO asociados(codigo,agencia_id,nombres,apellidos,dpi_cifrado,dpi_hash,nit_cifrado)
VALUES('DEMO-FIN-002',@agencia,'Luis','Ejemplo',AES_ENCRYPT('0000000000002',@clave_demo),UNHEX(SHA2('0000000000002',256)),AES_ENCRYPT('CF-002',@clave_demo))
ON DUPLICATE KEY UPDATE codigo=VALUES(codigo);
SET @ana=(SELECT asociado_id FROM asociados WHERE codigo='DEMO-FIN-001');
SET @luis=(SELECT asociado_id FROM asociados WHERE codigo='DEMO-FIN-002');
-- Si ya hay cuentas demo, omitir las dos CALL de apertura.
CALL sp_abrir_cuenta('FIN-DEMO-0001',@ana,@agencia,@tipo_ahorro,@cta1);
CALL sp_abrir_cuenta('FIN-DEMO-0002',@luis,@agencia,@tipo_ahorro,@cta2);
SELECT @cta1 AS cuenta_ana, @cta2 AS cuenta_luis;
CALL sp_depositar(@cta1,1500,'DEMO-DEP-001',@mov);
CALL sp_transferir(@cta1,@cta2,250,'DEMO-TRF-001',@transferencia);
CALL sp_retirar(@cta2,50,'DEMO-RET-001',@mov);
SELECT numero_cuenta,saldo FROM cuentas WHERE cuenta_id IN (@cta1,@cta2);
-- Solicitud -> aprobacion -> desembolso -> 12 cuotas -> pago.
CALL sp_solicitar_prestamo(@ana,@agencia,@tipo_prestamo,1200,12,@solicitud);
CALL sp_resolver_solicitud(@solicitud,TRUE,'PREST-DEMO-0001','Aprobado en demostracion',@prestamo);
CALL sp_desembolsar_prestamo(@prestamo,@cta1,'DEMO-DES-001',@mov);
SELECT prestamo_id,numero_cuota,fecha_vencimiento,capital_programado,interes_programado
FROM cuotas_prestamo WHERE prestamo_id=@prestamo ORDER BY numero_cuota;
CALL sp_pagar_cuota(@prestamo,@cta1,115,'DEMO-PAG-001',@pago);
SELECT * FROM v_cartera_prestamos WHERE prestamo_id=@prestamo;
SELECT * FROM v_cuotas_pendientes WHERE prestamo_id=@prestamo ORDER BY numero_cuota;
CALL sp_estado_cuenta(@cta1,CURDATE(),CURDATE());
-- Prueba NEGATIVA que debe mostrar SQLSTATE 45000 sin alterar saldos:
-- SELECT saldo FROM cuentas WHERE cuenta_id=@cta2;
-- CALL sp_retirar(@cta2,999999,'DEMO-FALLO-001',@mov);
-- SELECT saldo FROM cuentas WHERE cuenta_id=@cta2;
-- Auditoria (requiere los triggers del integrante 2):
-- SELECT * FROM coopdb_seguridad.v_bitacora_consulta ORDER BY auditoria_id DESC LIMIT 15;
