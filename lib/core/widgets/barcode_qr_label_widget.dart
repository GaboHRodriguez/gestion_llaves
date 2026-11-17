import 'package:flutter/material.dart';
import '../utils/key_nomenclature_generator.dart';

/// Etiqueta visual autogenerada con Código QR y Código de Barras Code128 (Módulo A.1)
class BarcodeQrLabelWidget extends StatelessWidget {
  final String codigoInterno;
  final String subtitulo;
  final String tipoLlave;
  final bool compact;

  const BarcodeQrLabelWidget({
    super.key,
    required this.codigoInterno,
    required this.subtitulo,
    required this.tipoLlave,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade300, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size.square(compact ? 64 : 84),
            painter: _QrMatrixPainter(codigoInterno),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  codigoInterno,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: compact ? 14 : 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$subtitulo • ${tipoLlave.toUpperCase()}',
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    color: Colors.blueGrey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: compact ? 26 : 34,
                  width: compact ? 150 : 210,
                  child: CustomPaint(
                    painter: _Code128Painter(codigoInterno),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrMatrixPainter extends CustomPainter {
  final String code;
  _QrMatrixPainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = KeyNomenclatureGenerator.encodeQrMatrix(code);
    final n = matrix.length;
    final cellSize = size.width / n;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (matrix[r][c]) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize + 0.4, cellSize + 0.4),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrMatrixPainter oldDelegate) =>
      oldDelegate.code != code;
}

class _Code128Painter extends CustomPainter {
  final String code;
  _Code128Painter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final pattern = KeyNomenclatureGenerator.encodeCode128Pattern(code);
    final totalUnits = pattern.fold<int>(0, (sum, w) => sum + w);
    if (totalUnits == 0) return;

    final unitWidth = size.width / totalUnits;
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    double currentX = 0;
    for (int i = 0; i < pattern.length; i++) {
      final w = pattern[i] * unitWidth;
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(currentX, 0, w, size.height), paint);
      }
      currentX += w;
    }
  }

  @override
  bool shouldRepaint(covariant _Code128Painter oldDelegate) =>
      oldDelegate.code != code;
}
