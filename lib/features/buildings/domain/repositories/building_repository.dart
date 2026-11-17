import '../entities/building_entity.dart';

/// Interfaz desacoplada de repositorio de Edificios (Repository Pattern).
/// Permite intercambiar el backend PHP/MySQL por Firebase Cloud Firestore sin alterar casos de uso ni UI.
abstract class BuildingRepository {
  Future<List<BuildingEntity>> getAllBuildings();
  Future<BuildingEntity> saveBuilding(BuildingEntity building);
  Future<void> deleteBuilding(String idEdificio);
}
