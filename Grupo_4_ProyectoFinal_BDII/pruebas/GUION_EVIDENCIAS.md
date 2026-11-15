# Evidencias obligatorias — integrante 3

**Estado:** guion de pruebas, NO son resultados ejecutados. Usar MySQL Workbench con datos de prueba.

1. Captura de cuentas creadas con `SELECT cuenta_id,numero_cuenta,saldo,estado FROM coopdb_core.cuentas`.
2. Depósito: ejecutar `CALL sp_depositar(...)`; fotografiar monto, nuevo saldo y fila en movimientos.
3. Retiro: ejecutar `CALL sp_retirar(...)`; repetir con monto mayor al saldo, registrar error y constatar saldo igual (ROLLBACK).
4. Transferencia: antes/después de los saldos de dos cuentas y dos movimientos más fila de transferencia (Atomicidad).
5. Estado de cuenta: ejecutar `CALL sp_estado_cuenta(...)` y capturar resultados por fechas.
6. Solicitar/aprobar: mostrar filas en `solicitudes_prestamo` y `prestamos`.
7. Desembolsar: mostrar saldo del asociado, estado VIGENTE y sus cuotas ordenadas.
8. Pagos: mostrar `pagos_prestamo`, `aplicaciones_pago`, cuota PARCIAL/PAGADA y saldo de capital correcto.
9. Aislamiento: abrir dos pestañas / conexiones reales; usar `aislamiento_sesion_A.sql` y `aislamiento_sesion_B.sql`. Capturar espera de bloqueo.
10. Durabilidad: COMMIT del depósito, confirmar saldo, reiniciar MySQL de forma controlada en entorno de prueba, reconectar y comprobar misma referencia/saldo.
11. Auditoría: revisar trigger `trg_audit_saldo` del integrante 2 y `v_bitacora_consulta`; confirmar cambios de saldos registrados.
12. Verificar ausencia de modificaciones cuando una operación falla; capturar excepción SQLSTATE 45000 y SELECT posterior.

**Nota:** Si `24_datos_demo_y_pruebas.sql` ya se ejecutó, no repetir las aperturas/referencias; las claves UNIQUE impiden duplicaciones. Crear nuevas referencias para otro intento o restaurar una base de pruebas.
