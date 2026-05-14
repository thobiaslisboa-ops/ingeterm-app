import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'clients_screen.dart';
import 'maintenances_screen.dart';
import 'users_screen.dart';
import 'maintenance_detail_screen.dart';
import '../widgets/connectivity_status_widget.dart';
import '../models/maintenance_model.dart';
import '../providers/user_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  Future<void> _signOut() async {
    final userProvider = context.read<UserProvider>();
    final navigator = Navigator.of(context);
    await FirebaseAuth.instance.signOut();
    userProvider.clearUser();
    navigator.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<UserProvider>().isAdmin;

    final tabs = <Widget>[
      _TaskListTab(
        onNewMaintenance: () => setState(() => _currentIndex = 1),
        onSignOut: _signOut,
      ),
      const MaintenancesScreen(),
      const ClientsScreen(),
      if (isAdmin) const UsersScreen(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment),
        label: 'Trabajo',
      ),
      const NavigationDestination(
        icon: Icon(Icons.build_circle_outlined),
        selectedIcon: Icon(Icons.build_circle),
        label: 'Mantenciones',
      ),
      const NavigationDestination(
        icon: Icon(Icons.business_outlined),
        selectedIcon: Icon(Icons.business),
        label: 'Clientes',
      ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Usuarios',
        ),
    ];

    // Acotar índice si el usuario cambió de rol entre sesiones
    final safeIndex = _currentIndex.clamp(0, tabs.length - 1);

    return ConnectivityStatusWidget(
      child: Scaffold(
        body: IndexedStack(
          index: safeIndex,
          children: tabs,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: destinations,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab: Lista de trabajo del día
// ══════════════════════════════════════════════════════════════════════════════
class _TaskListTab extends StatefulWidget {
  final VoidCallback? onNewMaintenance;
  final Future<void> Function()? onSignOut;
  const _TaskListTab({this.onNewMaintenance, this.onSignOut});

  @override
  State<_TaskListTab> createState() => _TaskListTabState();
}

class _TaskListTabState extends State<_TaskListTab> {
  final _db = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _maintenancesStream;

  @override
  void initState() {
    super.initState();
    // El filtro por tecnicoId se aplica en memoria en build()
    _maintenancesStream = _db
        .collectionGroup('maintenances')
        .where('tipo', isEqualTo: 'orden_trabajo')
        .snapshots();
  }

  DateTime get _now => DateTime.now();
  DateTime get _todayStart => DateTime(_now.year, _now.month, _now.day);
  DateTime get _todayEnd => _todayStart.add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEEE', 'es').format(_now).toUpperCase();
    final dateStr = DateFormat("d 'de' MMMM y", 'es').format(_now);
    final userProvider = context.watch<UserProvider>();
    final isAdmin = userProvider.isAdmin;
    final currentUid = userProvider.uid;
    final nombreUsuario = userProvider.nombreCompleto;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Marca de agua centrada
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Opacity(
                  opacity: 0.15,
                  child: Image.asset(
                    'assets/images/logo_vertical.jpg',
                    width: 260,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _maintenancesStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  debugPrint('🔴 HomeScreen Firestore error: ${snap.error}');
                }
                final allDocs = snap.data?.docs ?? [];

                // Filtrar por tecnicoId para técnicos (client-side)
                final byUser = isAdmin
                    ? allDocs
                    : allDocs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return data['tecnicoId'] == currentUid;
                      }).toList();

                // Solo órdenes activas (programada o enEjecucion)
                final docs = byUser.where((d) {
                  final estado =
                      (d.data() as Map<String, dynamic>)['estado'] as String? ??
                          '';
                  return estado == 'programada' || estado == 'enEjecucion';
                }).toList();

                // Solo las que tienen fechaProgramada
                final withDate = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>?;
                  return data?['fechaProgramada'] != null;
                }).toList();

                // HOY
                final hoy = withDate.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final fecha =
                      (data['fechaProgramada'] as Timestamp).toDate();
                  return !fecha.isBefore(_todayStart) &&
                      fecha.isBefore(_todayEnd);
                }).toList()
                  ..sort(_sortByFecha);

                // VENCIDAS
                final vencidas = withDate.where((d) {
                  final fecha =
                      ((d.data() as Map<String, dynamic>)['fechaProgramada']
                              as Timestamp)
                          .toDate();
                  return fecha.isBefore(_todayStart);
                }).toList()
                  ..sort(_sortByFecha);

                // ESTA SEMANA (días 1–7)
                final estaSemana = withDate.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final fecha =
                      (data['fechaProgramada'] as Timestamp).toDate();
                  final diff = fecha.difference(_todayStart).inDays;
                  return diff > 0 && diff <= 7;
                }).toList()
                  ..sort(_sortByFecha);

                // 30 DÍAS
                final treintaDias = withDate.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final fecha =
                      (data['fechaProgramada'] as Timestamp).toDate();
                  final diff = fecha.difference(_todayStart).inDays;
                  return diff > 0 && diff <= 30;
                }).toList()
                  ..sort(_sortByFecha);

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            // ── Header azul ────────────────────────────────
                            Container(
                              color: const Color(0xFF1A5DB5),
                              padding: EdgeInsets.fromLTRB(
                                20,
                                MediaQuery.of(context).padding.top + 16,
                                12,
                                20,
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [
                                  // Fecha
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dayName,
                                          style: const TextStyle(
                                            color: Color.fromRGBO(
                                                255, 255, 255, 0.7),
                                            fontSize: 13,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dateStr,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Logo
                                  Image.asset(
                                    'assets/images/logo_icon.png',
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 4),
                                  // Menú de perfil / cerrar sesión
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.account_circle_outlined,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    tooltip: 'Perfil',
                                    onSelected: (value) async {
                                      if (value == 'signout') {
                                        await widget.onSignOut?.call();
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem<String>(
                                        enabled: false,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nombreUsuario.isNotEmpty
                                                  ? nombreUsuario
                                                  : 'Usuario',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              isAdmin
                                                  ? 'Administrador'
                                                  : 'Técnico',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      PopupMenuItem<String>(
                                        value: 'signout',
                                        child: Row(children: [
                                          Icon(Icons.logout,
                                              color: Colors.red[700],
                                              size: 20),
                                          const SizedBox(width: 10),
                                          const Text('Cerrar sesión'),
                                        ]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Línea naranja
                            Container(
                                height: 4,
                                color: const Color(0xFFE8690A)),
                            // Contadores
                            Container(
                              color: const Color(0xFFF5F5F5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              child: Row(
                                children: [
                                  _counterChip('${vencidas.length}',
                                      'VENCIDAS',
                                      const Color(0xFFE24B4A)),
                                  const SizedBox(width: 8),
                                  _counterChip(
                                      '${hoy.length}',
                                      'HOY',
                                      const Color(0xFFE8690A)),
                                  const SizedBox(width: 8),
                                  _counterChip(
                                      '${estaSemana.length}',
                                      'ESTA\nSEMANA',
                                      const Color(0xFF1A5DB5)),
                                  const SizedBox(width: 8),
                                  _counterChip(
                                      '${treintaDias.length}',
                                      '30 DÍAS',
                                      const Color(0xFF1A5DB5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Botón Nueva mantención ─────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: widget.onNewMaintenance,
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Nueva mantención'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8690A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (hoy.isNotEmpty) ...[
                        _sectionLabel('HOY', const Color(0xFFE8690A)),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _maintenanceCard(hoy[i]),
                            childCount: hoy.length,
                          ),
                        ),
                      ],

                      if (vencidas.isNotEmpty) ...[
                        _sectionLabel(
                            'VENCIDAS', const Color(0xFFE24B4A)),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _maintenanceCard(vencidas[i]),
                            childCount: vencidas.length,
                          ),
                        ),
                      ],

                      if (treintaDias.isNotEmpty) ...[
                        _sectionLabel(
                            'PRÓXIMAS', Colors.grey.shade600),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) =>
                                _maintenanceCard(treintaDias[i]),
                            childCount: treintaDias.length,
                          ),
                        ),
                      ],

                      const SliverToBoxAdapter(
                          child: SizedBox(height: 32)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets auxiliares ──────────────────────────────────────────────────

  Widget _counterChip(String count, String label, Color numColor) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: TextStyle(
                color: numColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _maintenanceCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final titulo = data['titulo'] as String? ?? 'Sin título';
    final clienteNombre = data['clienteNombre'] as String? ?? '';
    final equipoNombre = data['equipoNombre'] as String? ?? '';
    final estado = estadoMantencionFromString(data['estado'] as String?);

    final horaMap = data['horaProgramada'] as Map<String, dynamic>?;
    final String horaStr = horaMap != null
        ? '${((horaMap['hour'] as int?) ?? 0).toString().padLeft(2, '0')}:'
            '${((horaMap['minute'] as int?) ?? 0).toString().padLeft(2, '0')}'
        : '';

    final Color estadoColor;
    switch (estado) {
      case EstadoMantencion.programada:
        estadoColor = const Color(0xFF1A5DB5);
        break;
      case EstadoMantencion.enEjecucion:
        estadoColor = const Color(0xFFE8690A);
        break;
      case EstadoMantencion.finalizada:
        estadoColor = Colors.green.shade600;
        break;
      case EstadoMantencion.cerrada:
        estadoColor = Colors.grey.shade600;
        break;
    }

    final segments = doc.reference.path.split('/');
    final cId = segments.length > 1 ? segments[1] : '';
    final eId = segments.length > 3 ? segments[3] : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (cId.isEmpty || eId.isEmpty) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MaintenanceDetailScreen(
                maintenanceId: doc.id,
                clienteId: cId,
                equipoId: eId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: estadoColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      estado.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: estadoColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.business_outlined,
                      size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        if (clienteNombre.isNotEmpty) clienteNombre,
                        if (equipoNombre.isNotEmpty) equipoNombre,
                      ].join(' · '),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (horaStr.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Icon(Icons.access_time,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      horaStr,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _sectionLabel(String title, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  int _sortByFecha(DocumentSnapshot a, DocumentSnapshot b) {
    final ta =
        ((a.data() as Map<String, dynamic>)['fechaProgramada'] as Timestamp)
            .toDate();
    final tb =
        ((b.data() as Map<String, dynamic>)['fechaProgramada'] as Timestamp)
            .toDate();
    return ta.compareTo(tb);
  }
}
