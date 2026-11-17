import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/rbac_provider.dart';
import '../../data/repositories/mysql_building_repository.dart';
import '../../domain/entities/building_entity.dart';
import '../../domain/repositories/building_repository.dart';

final buildingRepositoryProvider = Provider<BuildingRepository>((ref) {
  final client = ref.watch(apiGatewayClientProvider);
  final cfg = ref.watch(backendConfigProvider);
  return MysqlBuildingRepository(
    apiClient: client,
    syncRemote: cfg.syncWithRemoteMysql,
  );
});

class BuildingsNotifier extends StateNotifier<AsyncValue<List<BuildingEntity>>> {
  final BuildingRepository _repository;

  BuildingsNotifier(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repository.getAllBuildings();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addOrUpdateBuilding(BuildingEntity building) async {
    await _repository.saveBuilding(building);
    await refresh();
  }

  Future<void> removeBuilding(String idEdificio) async {
    await _repository.deleteBuilding(idEdificio);
    await refresh();
  }
}

final buildingsNotifierProvider =
    StateNotifierProvider<BuildingsNotifier, AsyncValue<List<BuildingEntity>>>(
  (ref) => BuildingsNotifier(ref.watch(buildingRepositoryProvider)),
);
