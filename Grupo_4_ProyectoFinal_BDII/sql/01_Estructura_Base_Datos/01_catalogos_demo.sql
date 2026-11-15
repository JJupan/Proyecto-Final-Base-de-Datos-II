-- Datos SEMILLA, seguros para ejecutar más de una vez.
USE coopdb_core;
INSERT INTO agencias (codigo,nombre,departamento,municipio,direccion) VALUES
('CENTRAL','Agencia Central','Guatemala','Guatemala','Zona 1'),
('MIXCO','Agencia Mixco','Guatemala','Mixco','Zona 1')
ON DUPLICATE KEY UPDATE nombre=VALUES(nombre), departamento=VALUES(departamento), municipio=VALUES(municipio);
INSERT INTO tipos_cuenta (codigo,nombre,tasa_interes_anual) VALUES
('AHO-NORMAL','Ahorro regular',2.5000),('AHO-INF','Ahorro infantil',3.0000)
ON DUPLICATE KEY UPDATE nombre=VALUES(nombre);
INSERT INTO tipos_movimiento (codigo,descripcion,naturaleza) VALUES
('DEPOSITO','Depósito en cuenta','ENTRADA'),('RETIRO','Retiro de cuenta','SALIDA'),
('TRANSF-OUT','Transferencia enviada','SALIDA'),('TRANSF-IN','Transferencia recibida','ENTRADA'),
('DESEMBOLSO','Desembolso de préstamo','ENTRADA'),('PAGO-PREST','Pago de préstamo','SALIDA')
ON DUPLICATE KEY UPDATE descripcion=VALUES(descripcion);
INSERT INTO tipos_prestamo (codigo,nombre,tasa_anual,plazo_max_meses) VALUES
('PERSONAL','Préstamo personal',15.0000,60),('VIVIENDA','Préstamo vivienda',9.5000,240)
ON DUPLICATE KEY UPDATE nombre=VALUES(nombre);
