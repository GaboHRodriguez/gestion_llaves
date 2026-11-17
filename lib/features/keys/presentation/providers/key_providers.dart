import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/rbac_provider.dart';
import '../../../../core/utils/key_nomenclature_generator.dart';
import '../../data/repositories/mysql_key_repository.dart';
import '../../domain/entities/key_entity.dart';
import '../../domain/repositories/key_repository.dart';

final keyRepositoryProvider = Provider<KeyRepository>((ref) {
  final client = ref.watch(apiGatewayClientProvider);
  final cfg = ref.watch(backendConfigProvider);
  return MysqlKeyRepository(
    apiClient: client,
    syncRemote: cfg.syncWithRemoteMysql,
  );
});

class KeysNotifier extends StateNotifier<AsyncValue<List<KeyEntity>>> {
  final KeyRepository _repository;

  KeysNotifier(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final keys = await _repository.getAllKeys();
      state = AsyncValue.data(keys);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveKey(KeyEntity key) async {
    await _repository.saveKey(key);
    await refresh();
  }

  Future<void> updateStatus(String codigoInterno, KeyStatus newStatus) async {
    await _repository.updateKeyStatus(codigoInterno, newStatus);
    await refresh();
  }

  Future<void> deleteKey(String codigoInterno) async {
    await _repository.deleteKey(codigoInterno);
    await refresh();
  }

  /// Calcula el siguiente correlativo libre para `[EDIFICIO]-[PISO/DEPTO/ZONA]-[CORRELATIVO]`
  String suggestNextHierarchicalCode({
    required String idEdificio,
    String? pisoDepto,
    String? zonaComun,
  }) {
    final existing = state.valueOrNull ?? const <KeyEntity>[];
    int correlativo = 1;
    while (true) {
      final candidate = KeyNomenclatureGenerator.generateCode(
        idEdificio: idEdificio,
        pisoDepto: pisoDepto,
        zonaComun: zonaComun,
        correlativo: correlativo,
      );
      final taken = existing.any((k) => k.codigoInterno == candidate);
      if (!taken) return candidate;
      correlativo++;
    }
  }
}

final keysNotifierProvider =
    StateNotifierProvider<KeysNotifier, AsyncValue<List<KeyEntity>>>(
  (ref) => KeysNotifier(ref.watch(keyRepositoryProvider)),
);
