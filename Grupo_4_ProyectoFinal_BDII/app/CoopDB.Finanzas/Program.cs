using System.Data;
using MySqlConnector;

// Prototipo de interfaz de consola, compatible con MySqlConnector usado en integrantes 1 y 2.
// En producción, estas operaciones y sus secretos deben permanecer en un backend de confianza.
var b = new MySqlConnectionStringBuilder
{
    Server = Environment.GetEnvironmentVariable("COOPDB_HOST") ?? "127.0.0.1",
    Port = uint.TryParse(Environment.GetEnvironmentVariable("COOPDB_PORT"), out var p) ? p : 3306,
    Database = "coopdb_core",
    UserID = Environment.GetEnvironmentVariable("COOPDB_FIN_USER") ?? "",
    Password = Environment.GetEnvironmentVariable("COOPDB_FIN_PASSWORD") ?? "",
    SslMode = (Environment.GetEnvironmentVariable("COOPDB_MODE") ?? "local") == "tls"
        ? MySqlSslMode.Required : MySqlSslMode.Disabled,
    Pooling = true, MaximumPoolSize = 10
};
if (string.IsNullOrWhiteSpace(b.UserID) || string.IsNullOrEmpty(b.Password))
{
    Console.WriteLine("Configure COOPDB_FIN_USER y COOPDB_FIN_PASSWORD. Consulte .env.example");
    return;
}

static string Texto(string mensaje) { Console.Write(mensaje + ": "); return Console.ReadLine()?.Trim() ?? ""; }
static ulong Id(string msg) => ulong.Parse(Texto(msg));
static decimal Monto(string msg) => decimal.Parse(Texto(msg), System.Globalization.CultureInfo.InvariantCulture);
static DateTime Fecha(string msg) => DateTime.ParseExact(Texto(msg), "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);

async Task Ejecutar(string nombre, params (string, object?)[] argumentos)
{
    await using var cn = new MySqlConnection(b.ConnectionString);
    await cn.OpenAsync();
    await using (var actor = new MySqlCommand("SET @coopdb_actor = @actor", cn))
    {
        // En integración real, el actor se obtiene de la sesión autenticada del backend.
        actor.Parameters.AddWithValue("@actor", Environment.GetEnvironmentVariable("COOPDB_ACTOR") ?? "demo_finanzas");
        await actor.ExecuteNonQueryAsync();
    }
    await using var cmd = new MySqlCommand(nombre, cn) { CommandType = CommandType.StoredProcedure, CommandTimeout = 60 };
    foreach (var (key, val) in argumentos)
        cmd.Parameters.AddWithValue(key, val ?? DBNull.Value);
    var outputs = new[] { "p_cuenta", "p_movimiento", "p_transferencia", "p_solicitud", "p_prestamo", "p_pago" };
    foreach (var param in outputs.Where(x => !argumentos.Any(a => a.Item1 == x)))
    {
        // Solo agregar salidas que correspondan al procedimiento actual.
        bool usar = (nombre, param) switch
        {
            ("sp_abrir_cuenta", "p_cuenta") or ("sp_depositar", "p_movimiento")
            or ("sp_retirar", "p_movimiento") or ("sp_transferir", "p_transferencia")
            or ("sp_solicitar_prestamo", "p_solicitud")
            or ("sp_resolver_solicitud", "p_prestamo")
            or ("sp_desembolsar_prestamo", "p_movimiento")
            or ("sp_pagar_cuota", "p_pago") => true,
            _ => false
        };
        if (usar) { var parameter = cmd.Parameters.Add(param, MySqlDbType.UInt64); parameter.Direction = ParameterDirection.Output; }
    }
    await cmd.ExecuteNonQueryAsync();
    foreach (MySqlParameter o in cmd.Parameters)
        if (o.Direction == ParameterDirection.Output) Console.WriteLine($"{o.ParameterName} = {o.Value}");
    Console.WriteLine("Operación confirmada.");
}

async Task EstadoCuenta()
{
    await using var cn = new MySqlConnection(b.ConnectionString);
    await cn.OpenAsync();
    await using var cmd = new MySqlCommand("sp_estado_cuenta", cn) { CommandType = CommandType.StoredProcedure };
    cmd.Parameters.AddWithValue("p_cuenta", Id("ID cuenta"));
    cmd.Parameters.AddWithValue("p_desde", Fecha("Desde yyyy-MM-dd"));
    cmd.Parameters.AddWithValue("p_hasta", Fecha("Hasta yyyy-MM-dd"));
    await using var r = await cmd.ExecuteReaderAsync();
    while (await r.ReadAsync())
        Console.WriteLine($"{r["ocurrido_en"]} | {r["tipo"]} | Q{r["monto"]} | Saldo Q{r["saldo_posterior"]} | {r["referencia"]}");
}
while (true)
{
    Console.WriteLine("\nCOOPDB - OPERACIONES FINANCIERAS (demostración local)");
    Console.WriteLine("1 Abrir cuenta | 2 Depositar | 3 Retirar | 4 Transferir | 5 Estado de cuenta");
    Console.WriteLine("6 Solicitar préstamo | 7 Aprobar/rechazar | 8 Desembolsar y plan | 9 Pagar cuota | 0 Salir");
    var opcion = Texto("Opción");
    if (opcion == "0") break;
    try
    {
        switch (opcion)
        {
            case "1": await Ejecutar("sp_abrir_cuenta", ("p_numero",Texto("Número")),("p_asociado",Id("Asociado ID")),("p_agencia",Id("Agencia ID")),("p_tipo",Id("Tipo cuenta ID"))); break;
            case "2": await Ejecutar("sp_depositar",("p_cuenta",Id("Cuenta ID")),("p_monto",Monto("Monto (ej. 125.50)")),("p_referencia",Texto("Referencia única"))); break;
            case "3": await Ejecutar("sp_retirar",("p_cuenta",Id("Cuenta ID")),("p_monto",Monto("Monto")),("p_referencia",Texto("Referencia única"))); break;
            case "4": await Ejecutar("sp_transferir",("p_origen",Id("Cuenta origen ID")),("p_destino",Id("Cuenta destino ID")),("p_monto",Monto("Monto")),("p_referencia",Texto("Referencia única"))); break;
            case "5": await EstadoCuenta(); break;
            case "6": await Ejecutar("sp_solicitar_prestamo",("p_asociado",Id("Asociado ID")),("p_agencia",Id("Agencia ID")),("p_tipo",Id("Tipo préstamo ID")),("p_monto",Monto("Monto solicitado")),("p_plazo",Id("Plazo en meses"))); break;
            case "7": await Ejecutar("sp_resolver_solicitud",("p_solicitud",Id("Solicitud ID")),("p_aprobar",Texto("¿Aprobar? s/n").Equals("s",StringComparison.OrdinalIgnoreCase)),("p_numero",Texto("Número préstamo (si aprueba)")),("p_observacion",Texto("Observación"))); break;
            case "8": await Ejecutar("sp_desembolsar_prestamo",("p_prestamo",Id("Préstamo ID")),("p_cuenta",Id("Cuenta destino ID")),("p_referencia",Texto("Referencia única"))); break;
            case "9":
                var origen = Texto("Cuenta origen ID (vacío = efectivo externo)");
                await Ejecutar("sp_pagar_cuota",("p_prestamo",Id("Préstamo ID")),("p_cuenta_origen",string.IsNullOrWhiteSpace(origen) ? null : ulong.Parse(origen)),("p_monto",Monto("Monto")),("p_referencia",Texto("Referencia única"))); break;
            default: Console.WriteLine("Opción desconocida"); break;
        }
    }
    catch (Exception ex) { Console.WriteLine("Error: " + ex.Message); }
}
