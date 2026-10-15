import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/cliente.dart';

/// Vista del módulo de Clientes (Pantalla estilo Eleventa Punto de Venta).
/// Permite administrar, buscar, crear, modificar y eliminar clientes.
/// Aplica para ambos perfiles (Usuario y Administrador).
/// Solo requiere nombres, apellidos y teléfono, sin restricciones.
class ClientesView extends StatefulWidget {
  const ClientesView({super.key});

  @override
  State<ClientesView> createState() => _ClientesViewState();
}

class _ClientesViewState extends State<ClientesView> {
  // Controladores de texto para el formulario
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _buscarController = TextEditingController();

  // Lista de clientes en memoria (inicia con clientes de demostración estilo eleventa)
  final List<Cliente> _clientes = [
    Cliente(
      folio: 1,
      nombres: 'Alejandro',
      apellidos: 'Morales Silva',
      telefono: '55 1234 5678',
    ),
    Cliente(
      folio: 2,
      nombres: 'María',
      apellidos: 'García Ruiz',
      telefono: '55 9876 5432',
    ),
    Cliente(
      folio: 3,
      nombres: 'Carlos',
      apellidos: 'Hernández',
      telefono: '55 4433 2211',
    ),
  ];

  // Folio seleccionado actualmente (null si se está creando un nuevo cliente)
  int? _folioSeleccionado = 1;

  // Texto del buscador
  String _filtroBusqueda = '';

  @override
  void initState() {
    super.initState();
    // Cargar por defecto el primer cliente en el formulario si existe
    if (_clientes.isNotEmpty) {
      _cargarClienteEnFormulario(_clientes.first);
    }
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _telefonoController.dispose();
    _buscarController.dispose();
    super.dispose();
  }

  /// Clientes filtrados por el término de búsqueda
  List<Cliente> get _clientesFiltrados {
    final query = _filtroBusqueda.trim().toLowerCase();
    if (query.isEmpty) {
      return _clientes;
    }
    return _clientes.where((c) {
      final folioStr = c.folio.toString();
      final nombre = c.nombres.toLowerCase();
      final apellido = c.apellidos.toLowerCase();
      final telefono = c.telefono.toLowerCase();
      return folioStr.contains(query) ||
          nombre.contains(query) ||
          apellido.contains(query) ||
          telefono.contains(query);
    }).toList();
  }

  Cliente? get _clienteActual {
    if (_folioSeleccionado == null) return null;
    try {
      return _clientes.firstWhere((c) => c.folio == _folioSeleccionado);
    } catch (_) {
      return null;
    }
  }

  /// Carga los datos de un cliente en los campos de edición
  void _cargarClienteEnFormulario(Cliente cliente) {
    setState(() {
      _folioSeleccionado = cliente.folio;
      _nombresController.text = cliente.nombres;
      _apellidosController.text = cliente.apellidos;
      _telefonoController.text = cliente.telefono;
    });
  }

  /// Cambia el modo a "Nuevo Cliente" limpiando los campos
  void _iniciarNuevoCliente() {
    setState(() {
      _folioSeleccionado = null;
      _nombresController.clear();
      _apellidosController.clear();
      _telefonoController.clear();
    });
    _mostrarMensaje('Formulario listo para nuevo cliente');
  }

  /// Guarda el cliente (creación o actualización) sin restricciones
  void _guardarCliente() {
    final nombres = _nombresController.text.trim();
    final apellidos = _apellidosController.text.trim();
    final telefono = _telefonoController.text.trim();

    // Sin restricciones: si no se escribe nombre, se asigna uno por defecto
    final nombreFinal = nombres.isNotEmpty
        ? nombres
        : (apellidos.isNotEmpty ? apellidos : 'Cliente Nuevo');

    setState(() {
      if (_folioSeleccionado == null) {
        // Crear nuevo cliente: calculamos el siguiente folio
        final siguienteFolio = _clientes.isEmpty
            ? 1
            : (_clientes.map((c) => c.folio).reduce((a, b) => a > b ? a : b) + 1);

        final nuevo = Cliente(
          folio: siguienteFolio,
          nombres: nombreFinal,
          apellidos: apellidos,
          telefono: telefono,
        );

        _clientes.add(nuevo);
        _folioSeleccionado = siguienteFolio;
        _mostrarMensaje('Cliente "$nombreFinal" registrado con éxito');
      } else {
        // Actualizar cliente existente
        final index = _clientes.indexWhere((c) => c.folio == _folioSeleccionado);
        if (index != -1) {
          _clientes[index].nombres = nombreFinal;
          _clientes[index].apellidos = apellidos;
          _clientes[index].telefono = telefono;
          _mostrarMensaje('Cliente "$nombreFinal" actualizado con éxito');
        }
      }
    });
  }

  /// Elimina el cliente seleccionado tras confirmación
  void _eliminarCliente() {
    final cliente = _clienteActual;
    if (cliente == null) {
      _mostrarMensaje('Selecciona un cliente para eliminar', esError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Eliminar Cliente'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar al cliente "${cliente.nombreCompleto}" (Folio #${cliente.folio})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _clientes.removeWhere((c) => c.folio == cliente.folio);
                if (_clientes.isNotEmpty) {
                  _cargarClienteEnFormulario(_clientes.first);
                } else {
                  _iniciarNuevoCliente();
                }
              });
              _mostrarMensaje('Cliente eliminado correctamente');
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  /// Diálogo simulado de exportación estilo Eleventa
  void _exportarClientes() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.table_chart_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Exportar Catálogo de Clientes'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total de clientes disponibles: ${_clientes.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Selecciona el formato deseado para exportar:'),
            const SizedBox(height: 12),
            ListTile(
              dense: true,
              leading: const Icon(Icons.file_present_rounded, color: Colors.green),
              title: const Text('Microsoft Excel (.xlsx)'),
              subtitle: const Text('Compatible con Eleventa y Excel'),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarMensaje('Exportando catálogo de clientes a Excel...');
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.receipt_long_rounded, color: Colors.blue),
              title: const Text('Archivo CSV delimitado por comas'),
              subtitle: const Text('Para importación masiva de clientes'),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarMensaje('Exportando catálogo de clientes a CSV...');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? AppColors.error : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Pestaña de sub-opción estilo Eleventa: [ Administración de clientes ]
        _buildPestanaSubOpcion(),

        // 2. Contenido principal con el layout de dos columnas
        Expanded(
          child: Container(
            color: const Color(0xFFF8F9FA),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título principal y subtítulo informativo
                  _buildEncabezadoModulo(),

                  const SizedBox(height: 14),

                  // Área de trabajo dividida: Lista a la izquierda | Formulario a la derecha
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna izquierda: Buscador y Lista de Clientes
                        SizedBox(
                          width: 320,
                          child: _buildPanelIzquierdo(),
                        ),

                        const SizedBox(width: 20),

                        // Columna derecha: Barra de herramientas superior y Formulario
                        Expanded(
                          child: _buildPanelDerecho(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Pestaña superior: "Administración de clientes"
  Widget _buildPestanaSubOpcion() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFD9DDE2), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                width: 1.2,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_pin_outlined,
                  size: 17,
                  color: AppColors.clientesIcon,
                ),
                SizedBox(width: 8),
                Text(
                  'Administración de clientes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Encabezado con título institucional y descripción
  Widget _buildEncabezadoModulo() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRACION DE CLIENTES',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Administra a todos los clientes de tu negocio (crédito, facturación, etc.) de forma centralizada.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  /// Panel Izquierdo: Buscador, Tabla con Folio/Nombre y botón Exportar
  Widget _buildPanelIzquierdo() {
    final clientes = _clientesFiltrados;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Campo de búsqueda con lupa
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _buscarController,
                onChanged: (val) {
                  setState(() {
                    _filtroBusqueda = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar cliente...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                  suffixIcon: _filtroBusqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _buscarController.clear();
                            setState(() => _filtroBusqueda = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.clientesIcon, width: 1.5),
                  ),
                ),
              ),
            ),
          ),

          // Encabezado de la tabla: Folio | Nombre
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
                bottom: BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    'Folio',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Nombre',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de clientes
          Expanded(
            child: clientes.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No se encontraron clientes',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: clientes.length,
                    itemBuilder: (context, index) {
                      final cliente = clientes[index];
                      final bool seleccionado = _folioSeleccionado == cliente.folio;

                      return InkWell(
                        onTap: () => _cargarClienteEnFormulario(cliente),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: seleccionado
                                ? const Color(0xFF38526E) // Azul pizarra de eleventa
                                : (index.isEven ? Colors.white : const Color(0xFFF8FAFC)),
                            border: const Border(
                              bottom: BorderSide(color: Color(0xFFF1F5F9)),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar circular con la inicial
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: seleccionado
                                      ? Colors.white.withAlpha(50)
                                      : cliente.avatarColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    cliente.inicial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Folio
                              SizedBox(
                                width: 36,
                                child: Text(
                                  cliente.folio.toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: seleccionado ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ),

                              // Nombre y Teléfono
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      cliente.nombreCompleto,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            seleccionado ? FontWeight.w600 : FontWeight.w500,
                                        color: seleccionado ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (cliente.telefono.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone_rounded,
                                            size: 11,
                                            color: seleccionado
                                                ? Colors.white70
                                                : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            cliente.telefono,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: seleccionado
                                                  ? Colors.white70
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Botón inferior Exportar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: _exportarClientes,
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Exportar...', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Panel Derecho: Barra de botones de acción superior y Formulario de Cliente
  Widget _buildPanelDerecho() {
    final bool esModoNuevo = _folioSeleccionado == null;
    final cliente = _clienteActual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de botones superior: [ Nuevo Cliente ] [ Eliminar ] [ Guardar ]
        Row(
          children: [
            // Botón: Nuevo Cliente
            _buildBotonToolbar(
              label: 'Nuevo Cliente',
              icon: Icons.person_add_alt_1_outlined,
              iconColor: const Color(0xFF2563EB),
              onTap: _iniciarNuevoCliente,
            ),
            const SizedBox(width: 8),

            // Botón: Eliminar
            _buildBotonToolbar(
              label: 'Eliminar',
              icon: Icons.close_rounded,
              iconColor: esModoNuevo ? const Color(0xFF94A3B8) : AppColors.error,
              onTap: esModoNuevo ? null : _eliminarCliente,
            ),
            const SizedBox(width: 8),

            // Botón: Guardar
            _buildBotonToolbar(
              label: 'Guardar',
              icon: Icons.check_rounded,
              iconColor: AppColors.success,
              onTap: _guardarCliente,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tarjeta con el formulario
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD1D5DB)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título de la sección
                  Text(
                    esModoNuevo
                        ? 'Nuevo cliente'
                        : 'Modificando cliente: ${cliente?.nombreCompleto ?? ''} (Folio #${cliente?.folio})',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColors.clientesIcon,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Fila 1: Nombres
                  _buildCampoFila(
                    label: 'Nombres',
                    controller: _nombresController,
                    hint: 'Escribe los nombres del cliente',
                    icon: Icons.badge_outlined,
                  ),

                  const SizedBox(height: 18),

                  // Fila 2: Apellidos
                  _buildCampoFila(
                    label: 'Apellidos',
                    controller: _apellidosController,
                    hint: 'Escribe los apellidos del cliente',
                    icon: Icons.person_outline_rounded,
                  ),

                  const SizedBox(height: 18),

                  // Fila 3: Teléfono
                  _buildCampoFila(
                    label: 'Teléfono',
                    controller: _telefonoController,
                    hint: 'Número de teléfono o celular',
                    icon: Icons.phone_outlined,
                    tipoTeclado: TextInputType.text, // Sin restricciones de caracteres
                  ),

                  const SizedBox(height: 36),

                  // Botón grande "Guardar" en la parte inferior del formulario (estilo eleventa)
                  Padding(
                    padding: const EdgeInsets.only(left: 140),
                    child: SizedBox(
                      height: 42,
                      width: 160,
                      child: ElevatedButton.icon(
                        onPressed: _guardarCliente,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'Guardar',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8FAFC),
                          foregroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Botón individual de la barra de acciones superior
  Widget _buildBotonToolbar({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback? onTap,
  }) {
    final bool deshabilitado = onTap == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: deshabilitado ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: deshabilitado ? const Color(0xFF94A3B8) : iconColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: deshabilitado ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fila de campo de entrada con etiqueta a la izquierda alineada estilo Eleventa
  Widget _buildCampoFila({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType tipoTeclado = TextInputType.text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Etiqueta lateral
        SizedBox(
          width: 120,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ),
        const SizedBox(width: 20),

        // Caja de entrada de texto (sin restricciones)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: controller,
              keyboardType: tipoTeclado,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(icon, size: 16, color: const Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: const Color(0xFFFDFDFD),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  borderSide: BorderSide(color: AppColors.clientesIcon, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
