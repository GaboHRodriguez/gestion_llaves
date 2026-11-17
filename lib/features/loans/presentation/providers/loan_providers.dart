import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/rbac_provider.dart';
import '../../../keys/domain/entities/key_entity.dart';
import '../../../keys/presentation/providers/key_providers.dart';
import '../../data/repositories/mysql_loan_repository.dart';
import '../../domain/entities/loan_movement_entity.dart';
import '../../domain/repositories/loan_repository.dart';

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  final client = ref.watch(apiGatewayClientProvider);
  final cfg = ref.watch(backendConfigProvider);
  return MysqlLoanRepository(
    apiClient: client,
    syncRemote: cfg.syncWithRemoteMysql,
  );
});

class LoansNotifier extends StateNotifier<AsyncValue<List<LoanMovementEntity>>> {
  final LoanRepository _repository;
  final Ref _ref;

  LoansNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repository.getAllMovements();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<LoanMovementEntity> checkOutKey({
    required String codigoLlave,
    required String contactoNombre,
    required String contactoTelefono,
    DateTime? customCheckoutDate,
  }) async {
    final activeUser = _ref.read(activeUserProvider);
    final movement = await _repository.registerCheckOut(
      codigoLlave: codigoLlave,
      contactoNombre: contactoNombre,
      contactoTelefono: contactoTelefono,
      entregadoPor: activeUser.nombreCompleto,
      customCheckoutDate: customCheckoutDate,
    );
    await _ref
        .read(keysNotifierProvider.notifier)
        .updateStatus(codigoLlave, KeyStatus.entregada);
    await refresh();
    return movement;
  }

  Future<void> returnKey(LoanMovementEntity movement) async {
    await _repository.registerReturn(movement.idMovimiento);
    await _ref
        .read(keysNotifierProvider.notifier)
        .updateStatus(movement.codigoLlave, KeyStatus.disponible);
    await refresh();
  }
}

final loansNotifierProvider =
    StateNotifierProvider<LoansNotifier, AsyncValue<List<LoanMovementEntity>>>(
  (ref) => LoansNotifier(ref.watch(loanRepositoryProvider), ref),
);

/// Proveedor derivado que filtra automáticamente los préstamos vencidos (> 30 días sin devolución)
final overdueLoansProvider = Provider<List<LoanMovementEntity>>((ref) {
  final all = ref.watch(loansNotifierProvider).valueOrNull ?? const [];
  return all.where((m) => m.isOverdue30Days).toList();
});
