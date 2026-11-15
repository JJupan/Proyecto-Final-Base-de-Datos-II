using System;
using System.Data;
using System.Drawing;
using System.Threading.Tasks;
using System.Windows.Forms;
using MySqlConnector;

namespace CoopDB.Asociados;

internal static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new AsociadosForm());
    }
}

public static class Configuracion
{
    public static string CadenaConexion()
    {
        // Dos variantes: COOPDB_MODE=local (por defecto) o tls.
        var modo = Environment.GetEnvironmentVariable("COOPDB_MODE") ?? "local";
        var servidor = Environment.GetEnvironmentVariable("COOPDB_HOST") ?? "127.0.0.1";
        var puerto = uint.TryParse(Environment.GetEnvironmentVariable("COOPDB_PORT"), out var p) ? p : 3306;
        var usuario = Environment.GetEnvironmentVariable("COOPDB_USER") ?? "";
        var clave = Environment.GetEnvironmentVariable("COOPDB_PASSWORD") ?? "";
        if (string.IsNullOrWhiteSpace(usuario) || string.IsNullOrEmpty(clave))
            throw new InvalidOperationException("Configure COOPDB_USER y COOPDB_PASSWORD (ver .env.example).");
        var builder = new MySqlConnectionStringBuilder
        {
            Server = servidor, Port = puerto, Database = "coopdb_core",
            UserID = usuario, Password = clave,
            SslMode = modo.Equals("tls", StringComparison.OrdinalIgnoreCase)
                ? MySqlSslMode.Required : MySqlSslMode.Disabled,
            Pooling = true, MaximumPoolSize = 20,
            ConnectionTimeout = 10, DefaultCommandTimeout = 30
        };
        if (modo != "local" && modo != "tls")
            throw new InvalidOperationException("COOPDB_MODE debe ser local o tls.");
        return builder.ConnectionString;
    }

    public static string ClaveDatos()
    {
        var key = Environment.GetEnvironmentVariable("COOPDB_DATA_KEY");
        if (string.IsNullOrWhiteSpace(key) || key.Length < 24)
            throw new InvalidOperationException("Configure COOPDB_DATA_KEY con al menos 24 caracteres; no la incluya en Git.");
        return key;
    }
}

public sealed class AsociadosForm : Form
{
    private readonly DataGridView tabla = new() { Dock = DockStyle.Fill, ReadOnly = true, MultiSelect = false,
        SelectionMode = DataGridViewSelectionMode.FullRowSelect, AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill,
        AllowUserToAddRows = false };
    private readonly TextBox codigo = new() { Width = 180 };
    private readonly TextBox nombres = new() { Width = 180 };
    private readonly TextBox apellidos = new() { Width = 180 };
    private readonly TextBox dpi = new() { Width = 180, MaxLength = 13 };
    private readonly TextBox nit = new() { Width = 180 };
    private readonly TextBox telefono = new() { Width = 180 };
    private readonly TextBox correo = new() { Width = 180 };
    private readonly TextBox filtro = new() { Width = 250 };
    private readonly ComboBox agencias = new() { Width = 180, DropDownStyle = ComboBoxStyle.DropDownList };
    private long? seleccionado;

    public AsociadosForm()
    {
        Text = "CoopDB | Gestión de asociados";
        Size = new Size(1120, 680);
        StartPosition = FormStartPosition.CenterScreen;
        var arriba = new FlowLayoutPanel { Dock = DockStyle.Top, Height = 160, AutoScroll = true, Padding = new Padding(10) };
        void Campo(string etiqueta, Control control)
        {
            var cont = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, Width = 205, Height = 65 };
            cont.Controls.Add(new Label { Text = etiqueta, AutoSize = true });
            cont.Controls.Add(control);
            arriba.Controls.Add(cont);
        }
        Campo("Código de asociado", codigo);
        Campo("Nombres", nombres);
        Campo("Apellidos", apellidos);
        Campo("DPI (solo para registro)", dpi);
        Campo("NIT (opcional)", nit);
        Campo("Teléfono", telefono);
        Campo("Correo", correo);
        Campo("Agencia", agencias);
        var acciones = new FlowLayoutPanel { Dock = DockStyle.Top, Height = 44, Padding = new Padding(10, 3, 10, 3) };
        var guardar = new Button { Text = "Guardar / editar", AutoSize = true };
        var nuevo = new Button { Text = "Nuevo", AutoSize = true };
        var eliminar = new Button { Text = "Desactivar", AutoSize = true };
        var buscar = new Button { Text = "Buscar", AutoSize = true };
        var reactivar = new Button { Text = "Reactivar", AutoSize = true };
        acciones.Controls.AddRange(new Control[] { guardar, nuevo, eliminar, reactivar, filtro, buscar });
        Controls.Add(tabla);
        Controls.Add(acciones);
        Controls.Add(arriba);
        guardar.Click += async (_, _) => await EjecutarAsync(GuardarAsync);
        nuevo.Click += (_, _) => Limpiar();
        eliminar.Click += async (_, _) => await EjecutarAsync(() => CambiarEstadoAsync(false));
        reactivar.Click += async (_, _) => await EjecutarAsync(() => CambiarEstadoAsync(true));
        buscar.Click += async (_, _) => await EjecutarAsync(CargarTablaAsync);
        tabla.SelectionChanged += (_, _) => CargarSeleccion();
        Shown += async (_, _) => await EjecutarAsync(async () => { await CargarAgenciasAsync(); await CargarTablaAsync(); });
    }

    private static async Task<MySqlConnection> AbrirAsync()
    {
        var conexion = new MySqlConnection(Configuracion.CadenaConexion());
        await conexion.OpenAsync();
        return conexion;
    }

    private async Task EjecutarAsync(Func<Task> accion)
    {
        try { await accion(); }
        catch (Exception ex) { MessageBox.Show(ex.Message, "CoopDB", MessageBoxButtons.OK, MessageBoxIcon.Warning); }
    }

    private async Task CargarAgenciasAsync()
    {
        await using var conexion = await AbrirAsync();
        await using var cmd = new MySqlCommand("SELECT agencia_id, nombre FROM agencias WHERE activa=1 ORDER BY nombre", conexion);
        var dt = new DataTable();
        using var reader = await cmd.ExecuteReaderAsync();
        dt.Load(reader);
        agencias.DataSource = dt;
        agencias.DisplayMember = "nombre";
        agencias.ValueMember = "agencia_id";
    }

    private async Task CargarTablaAsync()
    {
        await using var conexion = await AbrirAsync();
        const string sql = """
            SELECT a.asociado_id, a.codigo, a.nombres, a.apellidos, a.telefono,
                   a.correo, a.agencia_id, g.nombre AS agencia, a.activo
            FROM asociados a JOIN agencias g ON g.agencia_id = a.agencia_id
            WHERE (@texto='' OR a.codigo LIKE CONCAT('%',@texto,'%')
               OR a.nombres LIKE CONCAT('%',@texto,'%') OR a.apellidos LIKE CONCAT('%',@texto,'%'))
            ORDER BY a.asociado_id DESC LIMIT 200
            """;
        await using var cmd = new MySqlCommand(sql, conexion);
        cmd.Parameters.AddWithValue("@texto", filtro.Text.Trim());
        var dt = new DataTable();
        using (var reader = await cmd.ExecuteReaderAsync()) dt.Load(reader);
        tabla.DataSource = dt;
        if (tabla.Columns.Contains("asociado_id")) tabla.Columns["asociado_id"]!.Visible = false;
        if (tabla.Columns.Contains("agencia_id")) tabla.Columns["agencia_id"]!.Visible = false;
    }

    private void CargarSeleccion()
    {
        if (tabla.CurrentRow?.DataBoundItem is not DataRowView row) return;
        seleccionado = Convert.ToInt64(row["asociado_id"]);
        codigo.Text = Convert.ToString(row["codigo"]) ?? "";
        nombres.Text = Convert.ToString(row["nombres"]) ?? "";
        apellidos.Text = Convert.ToString(row["apellidos"]) ?? "";
        telefono.Text = Convert.ToString(row["telefono"]) ?? "";
        correo.Text = Convert.ToString(row["correo"]) ?? "";
        agencias.SelectedValue = row["agencia_id"];
        dpi.Clear(); nit.Clear(); // Nunca recuperar DPI/NIT a la interfaz de listado.
    }

    private async Task GuardarAsync()
    {
        if (string.IsNullOrWhiteSpace(codigo.Text) || string.IsNullOrWhiteSpace(nombres.Text)
            || string.IsNullOrWhiteSpace(apellidos.Text) || agencias.SelectedValue is null)
            throw new InvalidOperationException("Código, nombres, apellidos y agencia son obligatorios.");
        var nuevo = seleccionado is null;
        if (nuevo && (dpi.Text.Length != 13 || !System.Linq.Enumerable.All(dpi.Text, char.IsDigit)))
            throw new InvalidOperationException("Para un nuevo asociado ingrese DPI de 13 dígitos.");
        await using var conexion = await AbrirAsync();
        // Los comandos son parametrizados para prevenir inyección SQL.
        var sql = nuevo ? """
            INSERT INTO asociados (codigo, agencia_id, nombres, apellidos, telefono, correo, dpi_cifrado, dpi_hash, nit_cifrado)
            VALUES (@codigo,@agencia,@nombres,@apellidos,@telefono,@correo,
                    AES_ENCRYPT(@dpi,@clave),UNHEX(SHA2(@dpi,256)),
                    CASE WHEN @nit='' THEN NULL ELSE AES_ENCRYPT(@nit,@clave) END)
            """ : """
            UPDATE asociados SET codigo=@codigo, agencia_id=@agencia, nombres=@nombres,
                apellidos=@apellidos, telefono=@telefono, correo=@correo
            WHERE asociado_id=@id
            """;
        await using var cmd = new MySqlCommand(sql, conexion);
        cmd.Parameters.AddWithValue("@codigo", codigo.Text.Trim());
        cmd.Parameters.AddWithValue("@agencia", Convert.ToInt32(agencias.SelectedValue));
        cmd.Parameters.AddWithValue("@nombres", nombres.Text.Trim());
        cmd.Parameters.AddWithValue("@apellidos", apellidos.Text.Trim());
        cmd.Parameters.AddWithValue("@telefono", string.IsNullOrWhiteSpace(telefono.Text) ? DBNull.Value : telefono.Text.Trim());
        cmd.Parameters.AddWithValue("@correo", string.IsNullOrWhiteSpace(correo.Text) ? DBNull.Value : correo.Text.Trim());
        if (nuevo)
        {
            cmd.Parameters.AddWithValue("@dpi", dpi.Text.Trim());
            cmd.Parameters.AddWithValue("@nit", nit.Text.Trim());
            cmd.Parameters.AddWithValue("@clave", Configuracion.ClaveDatos());
        }
        else cmd.Parameters.AddWithValue("@id", seleccionado!.Value);
        await cmd.ExecuteNonQueryAsync();
        MessageBox.Show(nuevo ? "Asociado registrado." : "Asociado actualizado.");
        Limpiar();
        await CargarTablaAsync();
    }

    private async Task CambiarEstadoAsync(bool activo)
    {
        if (seleccionado is null) throw new InvalidOperationException("Seleccione un asociado.");
        if (!activo && MessageBox.Show("¿Desactivar este asociado sin borrar su historial?", "Confirmación",
                MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
        await using var conexion = await AbrirAsync();
        await using var cmd = new MySqlCommand("UPDATE asociados SET activo=@activo WHERE asociado_id=@id", conexion);
        cmd.Parameters.AddWithValue("@activo", activo);
        cmd.Parameters.AddWithValue("@id", seleccionado.Value);
        await cmd.ExecuteNonQueryAsync();
        Limpiar();
        await CargarTablaAsync();
    }

    private void Limpiar()
    {
        seleccionado = null;
        foreach (var campo in new[] { codigo, nombres, apellidos, dpi, nit, telefono, correo }) campo.Clear();
        tabla.ClearSelection();
    }
}
