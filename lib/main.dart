import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/rbac_models.dart';
import 'core/auth/rbac_provider.dart';
import 'features/buildings/presentation/providers/building_providers.dart';
import 'features/buildings/presentation/screens/buildings_screen.dart';
import 'features/camera_vector/presentation/screens/camera_vector_screen.dart';
import 'features/keys/domain/entities/key_entity.dart';
import 'features/keys/presentation/providers/key_providers.dart';
import 'features/keys/presentation/screens/keys_inventory_screen.dart';
import 'features/loans/presentation/providers/loan_providers.dart';
import 'features/loans/presentation/screens/loans_control_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KeyVectorControlApp()));
}

class KeyVectorControlApp extends StatelessWidget {
  const KeyVectorControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KeyVector Control - Gestión y Reconocimiento Vectorial de Llaves',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
      ),
      home: const MainAdaptiveShell(),
    );
  }
}

class MainAdaptiveShell extends ConsumerStatefulWidget {
  const MainAdaptiveShell({super.key});

  @override
  ConsumerState<MainAdaptiveShell> createState() => _MainAdaptiveShellState();
}

class _MainAdaptiveShellState extends ConsumerState<MainAdaptiveShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final activeUser = ref.watch(activeUserProvider);
    final overdueCount = ref.watch(overdueLoansProvider).length;
    final backendCfg = ref.watch(backendConfigProvider);
    final isWideDesktop = MediaQuery.of(context).size.width >= 900;

    final pages = <Widget>[
      KeysInventoryScreen(
        onOpenVectorizerTab: () => setState(() => _selectedIndex = 1),
      ),
      const CameraVectorScreen(),
      const LoansControlScreen(),
      const BuildingsScreen(),
      const _GerenciaAuditDashboard(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1120),
        elevation: 2,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF38BDF8)),
              ),
              child: const Icon(
                Icons.vpn_key_rounded,
                color: Color(0xFF38BDF8),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KEYVECTOR ERP • RECONOCIMIENTO VECTORIAL Y TRAZABILIDAD DE LLAVES',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Clean Architecture + Riverpod • MySQL/PHP XAMPP REST Gateway (Firebase-Ready)',
                    style: TextStyle(fontSize: 11.5, color: Colors.white60),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Botón de configuración de API Gateway (Fase 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              icon: Icon(
                Icons.dns_outlined,
                size: 16,
                color: backendCfg.syncWithRemoteMysql
                    ? const Color(0xFF00E676)
                    : Colors.amberAccent,
              ),
              label: Text(
                backendCfg.syncWithRemoteMysql ? 'XAMPP REST Online' : 'Modo Híbrido / Local',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () => _showBackendGatewayDialog(context),
            ),
          ),
          const SizedBox(width: 10),
          // Selector interactivo de Rol RBAC (Módulo D)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AppUser>(
                value: activeUser,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: const Color(0xFF1E293B),
                items: kDemoUsers
                    .map(
                      (u) => DropdownMenuItem(
                        value: u,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 16,
                              color: Color(0xFF38BDF8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Rol: ${u.rol.dbValue}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (newUser) {
                  if (newUser != null) {
                    ref.read(activeUserProvider.notifier).state = newUser;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'RBAC actualizado: ${newUser.nombreCompleto} — ${newUser.rol.description}',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isWideDesktop)
            NavigationRail(
              backgroundColor: const Color(0xFF0B1120),
              selectedIndex: _selectedIndex,
              extended: MediaQuery.of(context).size.width >= 1220,
              onDestinationSelected: (idx) =>
                  setState(() => _selectedIndex = idx),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.qr_code_2_rounded),
                  label: Text('Inventario y QR'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.center_focus_strong_rounded),
                  label: Text('Visión Vectorial (X,Y)'),
                ),
                NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: overdueCount > 0,
                    label: Text('$overdueCount'),
                    child: const Icon(Icons.swap_horiz_rounded),
                  ),
                  label: const Text('Préstamos y SMS +30d'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.apartment_rounded),
                  label: Text('Edificios'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.insights_rounded),
                  label: Text('Auditoría Gerencia'),
                ),
              ],
            ),
          if (isWideDesktop) const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: isWideDesktop
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) =>
                  setState(() => _selectedIndex = idx),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.qr_code_2_rounded),
                  label: 'Llaves',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.center_focus_strong_rounded),
                  label: 'Vectorizar',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: overdueCount > 0,
                    label: Text('$overdueCount'),
                    child: const Icon(Icons.swap_horiz_rounded),
                  ),
                  label: 'Préstamos',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.apartment_rounded),
                  label: 'Edificios',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.insights_rounded),
                  label: 'Gerencia',
                ),
              ],
            ),
    );
  }

  void _showBackendGatewayDialog(BuildContext context) {
    final currentCfg = ref.read(backendConfigProvider);
    final urlCtrl = TextEditingController(text: currentCfg.apiBaseUrl);
    bool syncRemote = currentCfg.syncWithRemoteMysql;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Fase 2: Configuración API Gateway (PHP/MySQL & Firebase-Ready)'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'La capa de datos implementa el patrón Repository desacoplado (`BuildingRepository`, `KeyRepository`, `LoanRepository`).',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Endpoint Base XAMPP (PHP REST / MySQL)',
                    hintText: 'http://192.168.1.100/gestion_llaves/api',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sincronizar con Servidor XAMPP MySQL en cada operación'),
                  subtitle: const Text(
                    'Si el servidor XAMPP no está disponible en la red local, el repositorio opera automáticamente contra la caché en memoria sin pérdida de funcionalidad.',
                  ),
                  value: syncRemote,
                  onChanged: (v) => setModalState(() => syncRemote = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Aplicar Configuración'),
              onPressed: () {
                ref.read(backendConfigProvider.notifier).state =
                    currentCfg.copyWith(
                  apiBaseUrl: urlCtrl.text.trim(),
                  syncWithRemoteMysql: syncRemote,
                );
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel de Auditoría Global y Métricas de Retención (Módulo D - Rol Gerencia)
class _GerenciaAuditDashboard extends ConsumerWidget {
  const _GerenciaAuditDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeUser = ref.watch(activeUserProvider);
    final keys = ref.watch(keysNotifierProvider).valueOrNull ?? const <KeyEntity>[];
    final loans = ref.watch(loansNotifierProvider).valueOrNull ?? const [];
    final overdue = ref.watch(overdueLoansProvider);
    final buildings = ref.watch(buildingsNotifierProvider).valueOrNull ?? const [];

    if (!activeUser.canViewGlobalMetricsAndAudits) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_outlined, size: 48, color: Colors.amber),
              const SizedBox(height: 12),
              Text(
                'Acceso Restringido por RBAC (Rol actual: ${activeUser.rol.dbValue})',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Las métricas globales de retención, auditoría histórica y bajas definitivas son exclusivas del rol GERENCIA. '
                'Puede cambiar al rol "Gerencia" desde el selector superior derecho para auditar este módulo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final totalVectorBytes = keys.fold<int>(
      0,
      (sum, k) => sum + k.vectorDataJson.length,
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Módulo D: Auditoría Ejecutiva, Métricas de Retención y Eficiencia Vectorial (Gerencia)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Auditor activo: ${activeUser.nombreCompleto} • Supervisión integral de inventario y préstamos.',
            style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade300),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _KpiMetricCard(
                title: 'Edificios Activos',
                value: '${buildings.length}',
                subtitle: 'Consorcios administrados',
                icon: Icons.domain,
                color: const Color(0xFF38BDF8),
              ),
              _KpiMetricCard(
                title: 'Llaves Vectorizadas',
                value: '${keys.length}',
                subtitle: 'Peso total JSON: ${(totalVectorBytes / 1024).toStringAsFixed(1)} KB (0% fotos)',
                icon: Icons.polyline,
                color: const Color(0xFF00E676),
              ),
              _KpiMetricCard(
                title: 'Préstamos Activos',
                value: '${loans.where((m) => m.isActive).length}',
                subtitle: 'De ${loans.length} movimientos históricos',
                icon: Icons.vpn_key_outlined,
                color: Colors.amber,
              ),
              _KpiMetricCard(
                title: 'Mora > 30 Días',
                value: '${overdue.length}',
                subtitle: 'Requieren recordatorio SMS nativo',
                icon: Icons.warning_amber_rounded,
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _KpiMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 265,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
