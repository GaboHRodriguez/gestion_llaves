import '../entities/key_entity.dart';

/// Interfaz desacoplada de repositorio de Llaves (Repository Pattern).
/// Lista para migrar de MySQL REST a Firebase Cloud Firestore sin tocar UI ni casos de uso.
abstract class KeyRepository {
  Future<List<KeyEntity>> getAllKeys({String? idEdificio});
  Future<KeyEntity?> getKeyByCode(String codigoInterno);
  Future<KeyEntity> saveKey(KeyEntity key);
  Future<void> updateKeyStatus(String codigoInterno, KeyStatus newStatus);
  Future<void> deleteKey(String codigoInterno);
}
