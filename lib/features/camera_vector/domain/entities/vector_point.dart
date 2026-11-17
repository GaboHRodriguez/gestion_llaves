import 'dart:convert';

/// Punto bidimensional en milímetros reales (X, Y) sobre la hoja milimetrada (Módulo B.2)
class VectorPoint {
  final double x;
  final double y;

  const VectorPoint({
    required this.x,
    required this.y,
  });

  factory VectorPoint.fromJson(Map<String, dynamic> json) {
    return VectorPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x': double.parse(x.toStringAsFixed(3)),
        'y': double.parse(y.toStringAsFixed(3)),
      };

  static List<VectorPoint> listFromJsonString(String jsonStr) {
    if (jsonStr.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => VectorPoint.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static String listToJsonString(List<VectorPoint> points) {
    return jsonEncode(points.map((p) => p.toJson()).toList());
  }
}

/// Resultado de la calibración métrica y extracción vectorial (Módulo B.2)
class VectorExtractionResult {
  /// Secuencia ordenada de puntos (X, Y) en milímetros reales
  final List<VectorPoint> contourMm;

  /// Factor de calibración detectado: cuántos píxeles equivalen a 10 mm (1 cm)
  final double pixelsPerCm;

  /// Longitud física estimada de la hoja/espada de la llave en milímetros
  final double bladeLengthMm;

  /// Altura máxima del perfil de dientes/valles en milímetros
  final double maxHeightMm;

  /// Número de picos/cortes detectados en el perfil
  final int detectedCutsCount;

  /// Nivel de confianza de la calibración de cuadrícula milimetrada (0.0 a 1.0)
  final double calibrationConfidence;

  const VectorExtractionResult({
    required this.contourMm,
    required this.pixelsPerCm,
    required this.bladeLengthMm,
    required this.maxHeightMm,
    required this.detectedCutsCount,
    required this.calibrationConfidence,
  });

  String get toJsonPayload => VectorPoint.listToJsonString(contourMm);
}
