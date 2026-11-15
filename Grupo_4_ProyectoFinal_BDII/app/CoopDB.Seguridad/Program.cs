using System;
using System.Data;
using System.Linq;
using MySqlConnector;

// Consola de referencia para probar seguridad; integrar AuthService en el backend común.
// BCrypt incorpora salt aleatorio individual. Ninguna clave se almacena en texto plano.
var cs = new MySqlConnectionStringBuilder {
 Server = Environment.GetEnvironmentVariable("COOPDB_HOST") ?? "127.0.0.1",
 Port = uint.TryParse(Environment.GetEnvironmentVariable("COOPDB_PORT"), out var port) ? port : 3306,
 Database = "coopdb_seguridad",
 UserID = Environment.GetEnvironmentVariable("COOPDB_AUTH_USER") ?? "",
 Password = Environment.GetEnvironmentVariable("COOPDB_AUTH_PASSWORD") ?? "",
 SslMode = Enum.TryParse<MySqlSslMode>(Environment.GetEnvironmentVariable("COOPDB_SSL_MODE"), true, out var ssl) ? ssl : MySqlSslMode.None,
 Pooling = true, MaximumPoolSize = 10
};
if (string.IsNullOrWhiteSpace(cs.UserID) || string.IsNullOrEmpty(cs.Password)) {
 Console.WriteLine("Configure COOPDB_AUTH_USER y COOPDB_AUTH_PASSWORD."); return;
}
await using var db = new MySqlConnection(cs.ConnectionString);
await db.OpenAsync();
Console.WriteLine("CoopDB SEGURIDAD | 1: crear ADMIN inicial  2: iniciar sesión");
var opcion = Console.ReadLine()?.Trim();
if (opcion == "1") {
 // Bootstrap permitido únicamente cuando la tabla de usuarios está VACÍA.
 await using var count = new MySqlCommand("SELECT COUNT(*) FROM usuarios_app", db);
 var total = Convert.ToInt64(await count.ExecuteScalarAsync());
 if (total != 0) { Console.WriteLine("Ya hay usuarios. Solo un ADMIN puede crear nuevas cuentas."); return; }
 Console.Write("Nombre usuario inicial: "); var login = Console.ReadLine()?.Trim() ?? "";
 Console.Write("Nombre completo: "); var nombre = Console.ReadLine()?.Trim() ?? "";
 var pass = LeerClave("Contraseña: ");
 if (!Valido(login,nombre,pass)) { Console.WriteLine("Datos inválidos: clave de 12+ caracteres, con mayúscula, minúscula, número y símbolo."); return; }
 await CrearUsuario(db, login,nombre,pass,"ADMIN"); Console.WriteLine("ADMIN inicial creado."); return;
}
if (opcion != "2") return;
Console.Write("Usuario: "); var usuario = Console.ReadLine()?.Trim() ?? "";
var password = LeerClave("Contraseña: ");
var resultado = await Autenticar(db,usuario,password);
if (!resultado.Ok) { Console.WriteLine(resultado.Mensaje); return; }
Console.WriteLine($"Sesión iniciada: {usuario}; roles: {string.Join(", ",resultado.Roles)}");
if (!resultado.Roles.Contains("ADMIN")) return;
Console.WriteLine("Administración: 1 crear usuario  2 asignar rol  3 desactivar usuario  4 desbloquear usuario  (otro: salir)");
var accion = Console.ReadLine()?.Trim();
if (accion == "1") {
 Console.Write("Usuario nuevo: "); var u=Console.ReadLine()?.Trim()??"";
 Console.Write("Nombre completo: "); var n=Console.ReadLine()?.Trim()??"";
 var p=LeerClave("Clave nueva: ");
 Console.Write("Rol (ADMIN/CAJERO/AUDITOR/GERENTE): "); var rol=(Console.ReadLine()??"").Trim().ToUpperInvariant();
 if (!Valido(u,n,p) || !new[]{"ADMIN","CAJERO","AUDITOR","GERENTE"}.Contains(rol)) {Console.WriteLine("Datos o rol no válidos.");return;}
 await CrearUsuario(db,u,n,p,rol); Console.WriteLine("Usuario creado.");
} else if (accion == "2") {
 Console.Write("ID usuario: "); if (!long.TryParse(Console.ReadLine(),out var id)) return;
 Console.Write("Rol: "); var rol=(Console.ReadLine()??"").Trim().ToUpperInvariant();
 if (!new[]{"ADMIN","CAJERO","AUDITOR","GERENTE"}.Contains(rol)) return;
 await using var cmd=new MySqlCommand("INSERT IGNORE INTO usuario_rol(usuario_id,rol_id) SELECT @id,rol_id FROM roles_app WHERE nombre=@rol",db);
 cmd.Parameters.AddWithValue("@id",id);cmd.Parameters.AddWithValue("@rol",rol);
 Console.WriteLine(await cmd.ExecuteNonQueryAsync()>0?"Rol asignado.":"Sin cambios (revisar ID/rol). ");
} else if (accion == "3") {
 Console.Write("ID usuario a desactivar: ");if (!long.TryParse(Console.ReadLine(),out var id))return;
 await using var actor=new MySqlCommand("SET @coopdb_actor = @actor",db);actor.Parameters.AddWithValue("@actor",usuario);await actor.ExecuteNonQueryAsync();
 await using var cmd=new MySqlCommand("coopdb_seguridad.sp_desactivar_usuario",db){CommandType=CommandType.StoredProcedure};
 cmd.Parameters.AddWithValue("@p_usuario_id",id);await cmd.ExecuteNonQueryAsync();Console.WriteLine("Usuario desactivado.");
} else if (accion == "4") {
 Console.Write("ID usuario a desbloquear: ");if (!long.TryParse(Console.ReadLine(),out var id))return;
 await using var cmd=new MySqlCommand("UPDATE usuarios_app SET bloqueado=0,intentos_fallidos=0 WHERE usuario_id=@id AND activo=1",db);
 cmd.Parameters.AddWithValue("@id",id);Console.WriteLine(await cmd.ExecuteNonQueryAsync()>0?"Desbloqueado.":"No encontrado / inactivo.");
}

static bool Valido(string u,string n,string p) => u.Length is >= 3 and <= 60 && n.Length is >= 3 and <= 130
 && p.Length >= 12 && p.Any(char.IsUpper) && p.Any(char.IsLower) && p.Any(char.IsDigit) && p.Any(c=>!char.IsLetterOrDigit(c));
static string LeerClave(string texto) {
 Console.Write(texto);var chars=new System.Text.StringBuilder();ConsoleKeyInfo k;
 while ((k=Console.ReadKey(intercept:true)).Key!=ConsoleKey.Enter) {
  if (k.Key==ConsoleKey.Backspace && chars.Length>0) chars.Length--;
  else if (!char.IsControl(k.KeyChar)) chars.Append(k.KeyChar);
 }
 Console.WriteLine();return chars.ToString();
}
static async Task CrearUsuario(MySqlConnection db,string u,string n,string pass,string rol) {
 await using var tx=await db.BeginTransactionAsync();
 await using var add=new MySqlCommand("INSERT INTO usuarios_app(nombre_usuario,nombre_completo,clave_hash) VALUES(@u,@n,@h)",db,tx);
 add.Parameters.AddWithValue("@u",u);add.Parameters.AddWithValue("@n",n);
 add.Parameters.AddWithValue("@h",BCrypt.Net.BCrypt.HashPassword(pass,workFactor:12));
 await add.ExecuteNonQueryAsync();var id=add.LastInsertedId;
 await using var assign=new MySqlCommand("INSERT INTO usuario_rol(usuario_id,rol_id) SELECT @id,rol_id FROM roles_app WHERE nombre=@rol",db,tx);
 assign.Parameters.AddWithValue("@id",id);assign.Parameters.AddWithValue("@rol",rol);
 if(await assign.ExecuteNonQueryAsync()!=1) throw new InvalidOperationException("Rol no existe.");
 await tx.CommitAsync();
}
static async Task<(bool Ok,string Mensaje,string[] Roles)> Autenticar(MySqlConnection db,string login,string clave) {
 // FOR UPDATE serializa los intentos sobre una misma cuenta (evita carreras).
 await using var tx=await db.BeginTransactionAsync(IsolationLevel.ReadCommitted);
 await using var cmd=new MySqlCommand("SELECT usuario_id,clave_hash,activo,bloqueado,intentos_fallidos FROM usuarios_app WHERE nombre_usuario=@login FOR UPDATE",db,tx);
 cmd.Parameters.AddWithValue("@login",login);
 long id=0;string? hash=null;bool activo=false,bloqueado=false;int intentos=0;
 await using (var reader=await cmd.ExecuteReaderAsync()) {
  if(await reader.ReadAsync()) {
   id=reader.GetInt64(0);hash=reader.GetString(1);activo=reader.GetBoolean(2);bloqueado=reader.GetBoolean(3);intentos=reader.GetInt32(4);
  }
 }
 // Hash fijo de prueba para no distinguir usuario inexistente por tiempo de respuesta.
 var dummy="$2a$12$Zbq3nxfM1u5I7mx8GiVupe8aQkXvmqvCG9zlZ4oG2etbX3lD2dYQu";
 bool correcta=false;
 try {correcta=BCrypt.Net.BCrypt.Verify(clave,hash??dummy);}catch {correcta=false;}
 string estado;
 if(hash==null || !activo || bloqueado) estado="DENEGADO";
 else if(correcta) estado="EXITO";
 else estado=intentos>=2?"BLOQUEO":"FALLO";
 if(id!=0 && activo && !bloqueado) {
  var sql=correcta ? "UPDATE usuarios_app SET intentos_fallidos=0,ultimo_acceso=NOW() WHERE usuario_id=@id"
                   : "UPDATE usuarios_app SET intentos_fallidos=LEAST(3,intentos_fallidos+1),bloqueado=(intentos_fallidos+1>=3) WHERE usuario_id=@id";
  await using var update=new MySqlCommand(sql,db,tx);update.Parameters.AddWithValue("@id",id);await update.ExecuteNonQueryAsync();
 }
 await using(var ev=new MySqlCommand("coopdb_seguridad.sp_registrar_evento_acceso",db,tx){CommandType=CommandType.StoredProcedure}) {
  ev.Parameters.AddWithValue("@p_usuario",login.Length>60?login[..60]:login);
  ev.Parameters.AddWithValue("@p_resultado",estado);ev.Parameters.AddWithValue("@p_detalle","Intento de acceso por consola de prueba");await ev.ExecuteNonQueryAsync();
 }
 string[] roles=[];
 if(estado=="EXITO") {
  await using var q=new MySqlCommand("SELECT r.nombre FROM usuario_rol ur JOIN roles_app r ON r.rol_id=ur.rol_id WHERE ur.usuario_id=@id",db,tx);
  q.Parameters.AddWithValue("@id",id);
  await using var reader=await q.ExecuteReaderAsync();var lista=new System.Collections.Generic.List<string>();
  while(await reader.ReadAsync()) lista.Add(reader.GetString(0));roles=lista.ToArray();
 }
 await tx.CommitAsync();
 return (estado=="EXITO",estado=="EXITO"?"Acceso autorizado.":"Credenciales incorrectas o usuario bloqueado/inactivo.",roles);
}
