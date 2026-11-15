# PowerShell / Windows. Requiere mysql.exe y mysqldump.exe accesibles en PATH.
# No almacena la contraseña en archivos ni en la línea de comandos.
# Configurar una cuenta de backup con permisos suficientes (SELECT, SHOW VIEW, TRIGGER, EVENT, etc.).
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$out = "coopdb_backup_$stamp.sql"
Write-Host 'Ingrese credenciales de MySQL cuando mysqldump lo solicite.'
& mysqldump --host=127.0.0.1 --user=root --password --single-transaction --routines --triggers --events --databases coopdb_core coopdb_seguridad --result-file=$out
if ($LASTEXITCODE -ne 0) { throw 'Backup falló; no continúe.' }
Write-Host "Backup creado: $out"
Write-Host 'IMPORTANTE: restaurar únicamente en ambiente aislado para evitar sobrescribir datos existentes.'
Write-Host 'Para restaurar en instancia de PRUEBA aislada (puerto distinto):'
Write-Host "mysql --host=127.0.0.1 --port=3307 --user=root --password < $out"
Write-Host 'En PowerShell la redirección de entrada puede requerir cmd /c o Get-Content; ver README.'
