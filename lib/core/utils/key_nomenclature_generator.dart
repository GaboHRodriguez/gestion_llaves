/// Generador y validador de la Regla de Nomenclatura Unívoca (Módulo A.1):
/// Formato jerárquico: `[EDIFICIO]-[PISO/DEPTO/ZONA]-[CORRELATIVO]`
/// Ejemplo: `BELG-04-DEPB-01` o `LIBE-PB-SUM-02`
class KeyNomenclatureGenerator {
  static final RegExp validCodeRegex = RegExp(
    r'^[A-Z0-9]{2,10}-[A-Z0-9\-]{2,14}-\d{2,3}$',
  );

  /// Normaliza una cadena a mayúsculas alfanuméricas sin acentos ni espacios
  static String sanitizeSegment(String input, {int maxLength = 8}) {
    final mapAccents = {
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ñ': 'N',
      'á': 'A', 'é': 'E', 'í': 'I', 'ó': 'O', 'ú': 'U', 'ñ': 'N',
    };
    var upper = input.trim();
    mapAccents.forEach((k, v) => upper = upper.replaceAll(k, v));
    upper = upper.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (upper.isEmpty) return 'GEN';
    return upper.length > maxLength ? upper.substring(0, maxLength) : upper;
  }

  /// Genera el código jerárquico unívoco `[EDIFICIO]-[PISO/DEPTO/ZONA]-[CORRELATIVO]`
  static String generateCode({
    required String idEdificio,
    String? pisoDepto,
    String? zonaComun,
    required int correlativo,
  }) {
    final bld = sanitizeSegment(idEdificio, maxLength: 6);
    final rawLocation = (pisoDepto != null && pisoDepto.trim().isNotEmpty)
        ? pisoDepto.trim()
        : (zonaComun ?? 'ZCOM');

    // Permite formato compuesto como 04-DEPB o PB-HALL
    final parts = rawLocation
        .toUpperCase()
        .split(RegExp(r'[\s\-_/]+'))
        .map((e) => sanitizeSegment(e, maxLength: 6))
        .where((e) => e.isNotEmpty)
        .toList();

    final locSegment = parts.isEmpty ? 'PB' : parts.join('-');
    final corrSegment = correlativo.clamp(1, 999).toString().padLeft(2, '0');

    return '$bld-$locSegment-$corrSegment';
  }

  static bool isValid(String code) => validCodeRegex.hasMatch(code.trim().toUpperCase());

  /// Genera un patrón determinista de barras (estilo Code128B) para representación visual
  static List<int> encodeCode128Pattern(String code) {
    final List<int> bars = [2, 1, 1, 2, 1, 4]; // Start Code B
    int checksum = 104;
    final clean = code.trim().toUpperCase();
    for (int i = 0; i < clean.length; i++) {
      final codeUnit = clean.codeUnitAt(i);
      checksum += (codeUnit - 32) * (i + 1);
      final b1 = ((codeUnit >> 0) & 3) + 1;
      final s1 = ((codeUnit >> 2) & 2) + 1;
      final b2 = ((codeUnit >> 4) & 3) + 1;
      final s2 = ((codeUnit >> 1) & 2) + 1;
      bars.addAll([b1, s1, b2, s2, 1, 1]);
    }
    final chk = checksum % 103;
    bars.addAll([(chk & 3) + 1, 1, ((chk >> 2) & 3) + 1, 2, 2, 3, 3, 1, 1, 2]); // Stop
    return bars;
  }

  /// Genera una matriz booleana 21x21 con patrones de posición QR e información codificada del código
  static List<List<bool>> encodeQrMatrix(String code) {
    const int size = 21;
    final matrix = List.generate(size, (_) => List.filled(size, false));

    void drawFinder(int rowOffset, int colOffset) {
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 7; c++) {
          final isBorder = r == 0 || r == 6 || c == 0 || c == 6;
          final isCenter = r >= 2 && r <= 4 && c >= 2 && c <= 4;
          matrix[rowOffset + r][colOffset + c] = isBorder || isCenter;
        }
      }
    }

    drawFinder(0, 0);
    drawFinder(0, size - 7);
    drawFinder(size - 7, 0);

    // Timing patterns
    for (int i = 8; i < size - 8; i++) {
      matrix[6][i] = i.isEven;
      matrix[i][6] = i.isEven;
    }

    // Payload bits a partir del código jerárquico
    final bytes = code.codeUnits;
    int bitIndex = 0;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final inTopLeft = r < 8 && c < 8;
        final inTopRight = r < 8 && c >= size - 8;
        final inBottomLeft = r >= size - 8 && c < 8;
        final isTiming = r == 6 || c == 6;
        if (inTopLeft || inTopRight || inBottomLeft || isTiming) continue;

        final byteVal = bytes[(bitIndex ~/ 8) % bytes.length];
        final shift = bitIndex % 8;
        final bit = ((byteVal >> shift) ^ ((r * 31 + c * 17) & 1)) & 1;
        matrix[r][c] = bit == 1;
        bitIndex++;
      }
    }
    return matrix;
  }
}
