import '../../../../core/network/api_gateway_client.dart';
import '../../domain/entities/building_entity.dart';
import '../../domain/repositories/building_repository.dart';

/// Implementación MySQL/MariaDB (vía API REST PHP en XAMPP) con caché reactivo local
class MysqlBuildingRepository implements BuildingRepository {
  final ApiGatewayClient apiClient;
  final bool syncRemote;

  static final List<BuildingEntity> _localCache = [
    const BuildingEntity(
      idEdificio: 'BELG',
      nombre: 'Torre Belgrano Plaza',
      direccion: 'Av. Belgrano 1840, CABA',
    ),
    const BuildingEntity(
      idEdificio: 'LIBE',
      nombre: 'Complejo Libertador Park',
      direccion: 'Av. del Libertador 4920, Palermo',
    ),
    const BuildingEntity(
      idEdificio: 'PALE',
      nombre: 'Edificio Palermo Soho Suites',
      direccion: 'Thames 1650, CABA',
    ),
    const BuildingEntity(
      idEdificio: 'ALVE',
      nombre: 'Residencia Alvear Recoleta',
      direccion: 'Av. Alvear 1520, Recoleta',
    ),
  ];

  MysqlBuildingRepository({
    required this.apiClient,
    required this.syncRemote,
  });

  @override
  Future<List<BuildingEntity>> getAllBuildings() async {
    if (syncRemote) {
      try {
        final raw = await apiClient.getJsonList('/edificios.php');
        if (raw.isNotEmpty) {
          final parsed = raw.map(BuildingEntity.fromJson).toList();
          _localCache
            ..clear()
            ..addAll(parsed);
        }
      } catch (_) {
        // Fallback transparente a caché local si el servidor XAMPP no está activo
      }
    }
    return List.unmodifiable(_localCache);
  }

  @override
  Future<BuildingEntity> saveBuilding(BuildingEntity building) async {
    if (syncRemote) {
      try {
        await apiClient.postJson('/edificios.php', building.toJson());
      } catch (_) {}
    }
    final idx = _localCache.indexWhere((b) => b.idEdificio == building.idEdificio);
    if (idx >= 0) {
      _localCache[idx] = building;
    } else {
      _localCache.add(building);
    }
    return building;
  }

  @override
  Future<void> deleteBuilding(String idEdificio) async {
    if (syncRemote) {
      try {
        await apiClient.postJson('/edificios.php', {
          'action': 'delete',
          'id_edificio': idEdificio,
        });
      } catch (_) {}
    }
    _localCache.removeWhere((b) => b.idEdificio == idEdificio);
  }
}
