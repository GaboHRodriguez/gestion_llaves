import '../../../camera_vector/domain/entities/vector_point.dart';

/// Tipos técnicos de llaves soportados (Módulo A.2)
enum KeyType {
  sierra('sierra', 'Sierra (Yale / Cilindro dentado)'),
  tradicional('tradicional', 'Tradicional (Paleta simple)'),
  multipunto('multipunto', 'Multipunto (Alta seguridad)'),
  borjas('borjas', 'Borjas (Doble paleta bancaria/consorcio)');

  final String dbValue;
  final String label;
  const KeyType(this.dbValue, this.label);

  static KeyType fromString(String value) {
    final norm = value.trim().toLowerCase();
    for (final k in KeyType.values) {
      if (k.dbValue == norm) return k;
    }
    return KeyType.sierra;
  }
}

/// Estados operativos de cada llave (Módulo A.2)
enum KeyStatus {
  disponible('disponible', 'Disponible en Tablero'),
  entregada('entregada', 'Entregada / En Préstamo'),
  perdida('perdida', 'Extraviada / Baja');

  final String dbValue;
  final String label;
  const KeyStatus(this.dbValue, this.label);

  static KeyStatus fromString(String value) {
    final norm = value.trim().toLowerCase();
    for (final s in KeyStatus.values) {
      if (s.dbValue == norm) return s;
    }
    return KeyStatus.disponible;
  }
}

/// Entidad Llave (Módulo A.2):
/// Almacena exclusivamente el JSON de coordenadas vectoriales (X, Y) en `vectorData`,
/// cumpliendo la restricción crítica de NO persistir imágenes pesadas en base de datos.
class KeyEntity {
  final String codigoInterno; // PK ej: BELG-04-DEPB-01
  final String idEdificio;
  final String pisoDepto;
  final String zonaComun;
  final KeyType tipoLlave;
  final List<VectorPoint> vectorData;
  final KeyStatus estado;

  const KeyEntity({
    required this.codigoInterno,
    required this.idEdificio,
    required this.pisoDepto,
    required this.zonaComun,
    required this.tipoLlave,
    required this.vectorData,
    required this.estado,
  });

  String get ubicacionDisplay =>
      pisoDepto.trim().isNotEmpty ? 'Piso/Depto: $pisoDepto' : 'Zona Común: $zonaComun';

  String get vectorDataJson => VectorPoint.listToJsonString(vectorData);

  KeyEntity copyWith({
    String? codigoInterno,
    String? idEdificio,
    String? pisoDepto,
    String? zonaComun,
    KeyType? tipoLlave,
    List<VectorPoint>? vectorData,
    KeyStatus? estado,
  }) {
    return KeyEntity(
      codigoInterno: codigoInterno ?? this.codigoInterno,
      idEdificio: idEdificio ?? this.idEdificio,
      pisoDepto: pisoDepto ?? this.pisoDepto,
      zonaComun: zonaComun ?? this.zonaComun,
      tipoLlave: tipoLlave ?? this.tipoLlave,
      vectorData: vectorData ?? this.vectorData,
      estado: estado ?? this.estado,
    );
  }

  factory KeyEntity.fromJson(Map<String, dynamic> json) {
    final rawVector = json['vector_data'];
    List<VectorPoint> parsedPoints = const [];
    if (rawVector is String) {
      parsedPoints = VectorPoint.listFromJsonString(rawVector);
    } else if (rawVector is List) {
      parsedPoints = rawVector
          .whereType<Map>()
          .map((e) => VectorPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return KeyEntity(
      codigoInterno: (json['codigo_interno'] ?? '').toString().toUpperCase().trim(),
      idEdificio: (json['id_edificio'] ?? '').toString().toUpperCase().trim(),
      pisoDepto: (json['piso_depto'] ?? '').toString(),
      zonaComun: (json['zona_comun'] ?? '').toString(),
      tipoLlave: KeyType.fromString((json['tipo_llave'] ?? 'sierra').toString()),
      vectorData: parsedPoints,
      estado: KeyStatus.fromString((json['estado'] ?? 'disponible').toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'codigo_interno': codigoInterno,
        'id_edificio': idEdificio,
        'piso_depto': pisoDepto,
        'zona_comun': zonaComun,
        'tipo_llave': tipoLlave.dbValue,
        // Persistimos únicamente el JSON compacto de coordenadas vectoriales (X, Y)
        'vector_data': vectorDataJson,
        'estado': estado.dbValue,
      };
}
