import '../../../../core/network/api_gateway_client.dart';
import '../../../camera_vector/domain/services/key_vectorizer_service.dart';
import '../../domain/entities/key_entity.dart';
import '../../domain/repositories/key_repository.dart';

/// Implementación MySQL/MariaDB vía REST PHP con caché local de alta velocidad
class MysqlKeyRepository implements KeyRepository {
  final ApiGatewayClient apiClient;
  final bool syncRemote;

  static final List<KeyEntity> _localCache = [
    KeyEntity(
      codigoInterno: 'BELG-04-DEPB-01',
      idEdificio: 'BELG',
      pisoDepto: '04-DEPB',
      zonaComun: '',
      tipoLlave: KeyType.sierra,
      vectorData: KeyVectorizerService.generateFromBittingHeights(
        bittingDepthsMm: const [7.6, 5.1, 6.8, 4.3, 7.2, 5.4],
        bladeLengthMm: 28.5,
      ).contourMm,
      estado: KeyStatus.disponible,
    ),
    KeyEntity(
      codigoInterno: 'BELG-PB-SALA-01',
      idEdificio: 'BELG',
      pisoDepto: '',
      zonaComun: 'PB-SALA MAQUINAS',
      tipoLlave: KeyType.borjas,
      vectorData: KeyVectorizerService.generateFromBittingHeights(
        bittingDepthsMm: const [8.2, 4.0, 8.0, 3.8, 7.9, 4.2, 8.1],
        bladeLengthMm: 31.0,
      ).contourMm,
      estado: KeyStatus.entregada,
    ),
    KeyEntity(
      codigoInterno: 'LIBE-10-DEPA-01',
      idEdificio: 'LIBE',
      pisoDepto: '10-DEPA',
      zonaComun: '',
      tipoLlave: KeyType.multipunto,
      vectorData: KeyVectorizerService.generateFromBittingHeights(
        bittingDepthsMm: const [6.4, 6.1, 4.8, 6.5, 5.0, 6.2],
        bladeLengthMm: 29.5,
      ).contourMm,
      estado: KeyStatus.entregada,
    ),
    KeyEntity(
      codigoInterno: 'LIBE-AZ-TERR-02',
      idEdificio: 'LIBE',
      pisoDepto: '',
      zonaComun: 'AZ-TERRAZA Y TANQUES',
      tipoLlave: KeyType.tradicional,
      vectorData: KeyVectorizerService.generateFromBittingHeights(
        bittingDepthsMm: const [7.9, 7.8, 4.2, 4.1, 7.7],
        bladeLengthMm: 27.0,
      ).contourMm,
      estado: KeyStatus.disponible,
    ),
    KeyEntity(
      codigoInterno: 'PALE-02-DEPC-01',
      idEdificio: 'PALE',
      pisoDepto: '02-DEPC',
      zonaComun: '',
      tipoLlave: KeyType.sierra,
      vectorData: KeyVectorizerService.generateFromBittingHeights(
        bittingDepthsMm: const [5.2, 7.4, 4.6, 7.5, 5.8, 3.9],
        bladeLengthMm: 28.0,
      ).contourMm,
      estado: KeyStatus.disponible,
    ),
    KeyEntity(
      codigoInterno: 'ALVE-SS-COCH-01',
      idEdificio: 'ALVE',
      pisoDepto: '',
      zonaComun: 'SS-PORTON COCHERAS',
      tipoLlave: KeyType.sierra,
      vectorData: KeyVectorizerService.generateFromBittingHeights(
        bittingDepthsMm: const [6.9, 3.8, 5.5, 6.7, 4.0, 6.8],
        bladeLengthMm: 30.0,
      ).contourMm,
      estado: KeyStatus.entregada,
    ),
  ];

  MysqlKeyRepository({
    required this.apiClient,
    required this.syncRemote,
  });

  @override
  Future<List<KeyEntity>> getAllKeys({String? idEdificio}) async {
    if (syncRemote) {
      try {
        final raw = await apiClient.getJsonList(
          '/llaves.php',
          query: idEdificio != null ? {'id_edificio': idEdificio} : null,
        );
        if (raw.isNotEmpty) {
          final parsed = raw.map(KeyEntity.fromJson).toList();
          if (idEdificio == null) {
            _localCache
              ..clear()
              ..addAll(parsed);
          }
          return parsed;
        }
      } catch (_) {}
    }

    if (idEdificio != null && idEdificio.isNotEmpty) {
      return _localCache
          .where((k) => k.idEdificio == idEdificio.toUpperCase())
          .toList();
    }
    return List.unmodifiable(_localCache);
  }

  @override
  Future<KeyEntity?> getKeyByCode(String codigoInterno) async {
    final norm = codigoInterno.trim().toUpperCase();
    for (final k in _localCache) {
      if (k.codigoInterno == norm) return k;
    }
    return null;
  }

  @override
  Future<KeyEntity> saveKey(KeyEntity key) async {
    if (syncRemote) {
      try {
        await apiClient.postJson('/llaves.php', key.toJson());
      } catch (_) {}
    }
    final idx =
        _localCache.indexWhere((k) => k.codigoInterno == key.codigoInterno);
    if (idx >= 0) {
      _localCache[idx] = key;
    } else {
      _localCache.insert(0, key);
    }
    return key;
  }

  @override
  Future<void> updateKeyStatus(String codigoInterno, KeyStatus newStatus) async {
    if (syncRemote) {
      try {
        await apiClient.putJson('/llaves.php', {
          'codigo_interno': codigoInterno,
          'estado': newStatus.dbValue,
        });
      } catch (_) {}
    }
    final idx =
        _localCache.indexWhere((k) => k.codigoInterno == codigoInterno);
    if (idx >= 0) {
      _localCache[idx] = _localCache[idx].copyWith(estado: newStatus);
    }
  }

  @override
  Future<void> deleteKey(String codigoInterno) async {
    if (syncRemote) {
      try {
        await apiClient.postJson('/llaves.php', {
          'action': 'delete',
          'codigo_interno': codigoInterno,
        });
      } catch (_) {}
    }
    _localCache.removeWhere((k) => k.codigoInterno == codigoInterno);
  }
}
