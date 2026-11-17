import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../network/api_gateway_client.dart';
import '../platform/platform_services.dart';
import 'rbac_models.dart';

/// Usuarios preconfigurados para demostrar el modelo RBAC (Módulo D)
const List<AppUser> kDemoUsers = [
  AppUser(
    idUsuario: 1,
    nombreUsuario: 'dir.general',
    nombreCompleto: 'Ing. Gabriel Herrera (Gerencia)',
    rol: UserRole.gerencia,
  ),
  AppUser(
    idUsuario: 2,
    nombreUsuario: 'admin.consorcios',
    nombreCompleto: 'Lic. Valeria Quiroga (Administración)',
    rol: UserRole.administracion,
  ),
  AppUser(
    idUsuario: 3,
    nombreUsuario: 'encargado.guardia',
    nombreCompleto: 'Sr. Jorge Sosa (Encargado Operativo)',
    rol: UserRole.encargado,
  ),
];

/// Estado global de conexión con el Backend REST (XAMPP MySQL vs Caché/Demo Local)
class BackendConnectionConfig {
  final String apiBaseUrl;
  final bool syncWithRemoteMysql;
  final String? lastSyncMessage;

  const BackendConnectionConfig({
    this.apiBaseUrl = AppConfig.defaultApiBaseUrl,
    this.syncWithRemoteMysql = false,
    this.lastSyncMessage,
  });

  BackendConnectionConfig copyWith({
    String? apiBaseUrl,
    bool? syncWithRemoteMysql,
    String? lastSyncMessage,
  }) {
    return BackendConnectionConfig(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      syncWithRemoteMysql: syncWithRemoteMysql ?? this.syncWithRemoteMysql,
      lastSyncMessage: lastSyncMessage ?? this.lastSyncMessage,
    );
  }
}

final activeUserProvider = StateProvider<AppUser>((ref) => kDemoUsers.first);

final backendConfigProvider = StateProvider<BackendConnectionConfig>(
  (ref) => const BackendConnectionConfig(),
);

final apiGatewayClientProvider = Provider<ApiGatewayClient>((ref) {
  final user = ref.watch(activeUserProvider);
  final cfg = ref.watch(backendConfigProvider);
  return ApiGatewayClient(
    baseUrl: cfg.apiBaseUrl,
    activeUser: user,
  );
});

final platformHardwareServiceProvider = Provider<PlatformHardwareService>(
  (ref) => AdaptivePlatformHardwareService(),
);
