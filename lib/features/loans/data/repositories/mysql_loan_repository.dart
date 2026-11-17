import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_gateway_client.dart';
import '../../domain/entities/loan_movement_entity.dart';
import '../../domain/repositories/loan_repository.dart';

/// Implementación MySQL/MariaDB vía REST PHP con préstamos precargados (incluyendo vencidos >30 días)
class MysqlLoanRepository implements LoanRepository {
  final ApiGatewayClient apiClient;
  final bool syncRemote;

  static final List<LoanMovementEntity> _localCache = [
    LoanMovementEntity(
      idMovimiento: 1001,
      codigoLlave: 'BELG-PB-SALA-01',
      contactoNombre: 'Martín Echeverría (Técnico Ascensores)',
      contactoTelefono: '+5491145889102',
      fechaSalida: DateTime.now().subtract(const Duration(days: 38)),
      fechaDevolucionPrevista: DateTime.now().subtract(const Duration(days: 8)),
      fechaDevolucionReal: null,
      entregadoPor: 'Sr. Jorge Sosa (Encargado Operativo)',
    ),
    LoanMovementEntity(
      idMovimiento: 1002,
      codigoLlave: 'ALVE-SS-COCH-01',
      contactoNombre: 'Carlos Gómez (Sanitarios y Gas)',
      contactoTelefono: '+5491130994412',
      fechaSalida: DateTime.now().subtract(const Duration(days: 34)),
      fechaDevolucionPrevista: DateTime.now().subtract(const Duration(days: 4)),
      fechaDevolucionReal: null,
      entregadoPor: 'Lic. Valeria Quiroga (Administración)',
    ),
    LoanMovementEntity(
      idMovimiento: 1003,
      codigoLlave: 'LIBE-10-DEPA-01',
      contactoNombre: 'Lucía Fernández (Inmobiliaria Austral)',
      contactoTelefono: '+5491167231190',
      fechaSalida: DateTime.now().subtract(const Duration(days: 12)),
      fechaDevolucionPrevista: DateTime.now().add(const Duration(days: 18)),
      fechaDevolucionReal: null,
      entregadoPor: 'Sr. Jorge Sosa (Encargado Operativo)',
    ),
    LoanMovementEntity(
      idMovimiento: 1004,
      codigoLlave: 'BELG-04-DEPB-01',
      contactoNombre: 'Sofía Pereyra (Propietaria 4B)',
      contactoTelefono: '+5491155128834',
      fechaSalida: DateTime.now().subtract(const Duration(days: 22)),
      fechaDevolucionPrevista: DateTime.now().add(const Duration(days: 8)),
      fechaDevolucionReal: DateTime.now().subtract(const Duration(days: 5)),
      entregadoPor: 'Sr. Jorge Sosa (Encargado Operativo)',
    ),
  ];

  MysqlLoanRepository({
    required this.apiClient,
    required this.syncRemote,
  });

  @override
  Future<List<LoanMovementEntity>> getAllMovements() async {
    if (syncRemote) {
      try {
        final raw = await apiClient.getJsonList('/movimientos.php');
        if (raw.isNotEmpty) {
          final parsed = raw.map(LoanMovementEntity.fromJson).toList();
          _localCache
            ..clear()
            ..addAll(parsed);
        }
      } catch (_) {}
    }
    return List.unmodifiable(_localCache);
  }

  @override
  Future<LoanMovementEntity> registerCheckOut({
    required String codigoLlave,
    required String contactoNombre,
    required String contactoTelefono,
    required String entregadoPor,
    DateTime? customCheckoutDate,
  }) async {
    final salida = customCheckoutDate ?? DateTime.now();
    final prevista =
        salida.add(const Duration(days: AppConfig.maxLoanRetentionDays));
    final nextId = _localCache.isEmpty
        ? 1001
        : (_localCache
                .map((m) => m.idMovimiento)
                .reduce((a, b) => a > b ? a : b) +
            1);

    final movement = LoanMovementEntity(
      idMovimiento: nextId,
      codigoLlave: codigoLlave.toUpperCase().trim(),
      contactoNombre: contactoNombre.trim(),
      contactoTelefono: contactoTelefono.trim(),
      fechaSalida: salida,
      fechaDevolucionPrevista: prevista,
      fechaDevolucionReal: null,
      entregadoPor: entregadoPor,
    );

    if (syncRemote) {
      try {
        await apiClient.postJson('/movimientos.php', movement.toJson());
      } catch (_) {}
    }
    _localCache.insert(0, movement);
    return movement;
  }

  @override
  Future<LoanMovementEntity> registerReturn(int idMovimiento) async {
    final now = DateTime.now();
    if (syncRemote) {
      try {
        await apiClient.putJson('/movimientos.php', {
          'id_movimiento': idMovimiento,
          'fecha_devolucion_real': now.toIso8601String(),
        });
      } catch (_) {}
    }
    final idx =
        _localCache.indexWhere((m) => m.idMovimiento == idMovimiento);
    if (idx < 0) {
      throw StateError('Movimiento #$idMovimiento no encontrado.');
    }
    final updated = _localCache[idx].copyWith(fechaDevolucionReal: now);
    _localCache[idx] = updated;
    return updated;
  }
}
