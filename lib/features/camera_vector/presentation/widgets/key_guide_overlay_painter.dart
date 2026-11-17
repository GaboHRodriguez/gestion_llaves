import 'package:flutter/material.dart';
import '../../domain/entities/vector_point.dart';

/// CustomPainter superpuesto en tiempo real para:
/// 1. Hoja milimetrada de fondo calibrada (1 cm = N píxeles)
/// 2. Silueta guía para alinear cabezal, tope de hombro (X=0) y espada de la llave
/// 3. Dibujo en color contrastante del contorno vectorial detectado (Módulo B.1 y B.3)
class KeyGuideOverlayPainter extends CustomPainter {
  final List<VectorPoint> detectedContourMm;
  final List<VectorPoint>? comparisonContourMm;
  final bool showMillimeterGrid;
  final bool showKeySilhouetteGuide;
  final bool simulatePhysicalKeyOnCanvas;
  final Color contourColor;

  KeyGuideOverlayPainter({
    required this.detectedContourMm,
    this.comparisonContourMm,
    this.showMillimeterGrid = true,
    this.showKeySilhouetteGuide = true,
    this.simulatePhysicalKeyOnCanvas = true,
    this.contourColor = const Color(0xFF00E676),
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Definimos escala visual: la zona de la espada mide 32 mm de largo
    final double originX = size.width * 0.30; // Tope de hombro X = 0 mm
    final double baselineY = size.height * 0.66; // Base inferior de la espada Y = 0 mm
    final double pxPerMm = (size.width * 0.56) / 32.0;

    if (showMillimeterGrid) {
      _drawMillimeterSheet(canvas, size, originX, baselineY, pxPerMm);
    }

    if (simulatePhysicalKeyOnCanvas && detectedContourMm.isNotEmpty) {
      _drawSimulatedMetallicKey(canvas, originX, baselineY, pxPerMm);
    }

    if (showKeySilhouetteGuide) {
      _drawAlignmentGuide(canvas, size, originX, baselineY, pxPerMm);
    }

    // Si hay un vector de base de datos seleccionado para comparación, lo dibujamos en cian punteado
    if (comparisonContourMm != null && comparisonContourMm!.isNotEmpty) {
      _drawVectorContour(
        canvas,
        comparisonContourMm!,
        originX,
        baselineY,
        pxPerMm,
        color: const Color(0xFF00B0FF),
        strokeWidth: 2.2,
        drawPoints: false,
      );
    }

    // Dibujamos el contorno vectorial detectado en color contrastante (Módulo B.3)
    if (detectedContourMm.isNotEmpty) {
      _drawVectorContour(
        canvas,
        detectedContourMm,
        originX,
        baselineY,
        pxPerMm,
        color: contourColor,
        strokeWidth: 3.0,
        drawPoints: true,
      );
    }
  }

  void _drawMillimeterSheet(
    Canvas canvas,
    Size size,
    double originX,
    double baselineY,
    double pxPerMm,
  ) {
    final finePaint = Paint()
      ..color = const Color(0x2200E5FF)
      ..strokeWidth = 0.6;
    final fiveMmPaint = Paint()
      ..color = const Color(0x4400E5FF)
      ..strokeWidth = 1.0;
    final cmPaint = Paint()
      ..color = const Color(0x8800E5FF)
      ..strokeWidth = 1.5;

    // Líneas verticales desde el origen hacia izquierda y derecha en pasos de 1 mm
    final int maxMmRight = ((size.width - originX) / pxPerMm).ceil();
    final int maxMmLeft = (originX / pxPerMm).ceil();

    for (int mm = -maxMmLeft; mm <= maxMmRight; mm++) {
      final x = originX + mm * pxPerMm;
      final Paint p = (mm % 10 == 0)
          ? cmPaint
          : (mm % 5 == 0 ? fiveMmPaint : finePaint);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);

      if (mm >= 0 && mm <= 30 && mm % 10 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${mm ~/ 10} cm (${mm}mm)',
            style: const TextStyle(
              color: Color(0xCC80D8FF),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 3, baselineY + 10));
      }
    }

    // Líneas horizontales desde baselineY hacia arriba y abajo
    final int maxMmUp = (baselineY / pxPerMm).ceil();
    final int maxMmDown = ((size.height - baselineY) / pxPerMm).ceil();
    for (int mm = -maxMmDown; mm <= maxMmUp; mm++) {
      final y = baselineY - mm * pxPerMm;
      final Paint p = (mm % 10 == 0)
          ? cmPaint
          : (mm % 5 == 0 ? fiveMmPaint : finePaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _drawSimulatedMetallicKey(
    Canvas canvas,
    double originX,
    double baselineY,
    double pxPerMm,
  ) {
    final metalPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.amber.shade200.withValues(alpha: 0.85),
          Colors.amber.shade600.withValues(alpha: 0.88),
          Colors.brown.shade400.withValues(alpha: 0.85),
        ],
      ).createShader(Rect.fromLTWH(0, baselineY - 12 * pxPerMm, 350, 15 * pxPerMm))
      ..style = PaintingStyle.fill;

    // Cabezal (Bow) a la izquierda del tope X=0
    final bowCenter = Offset(originX - 9.5 * pxPerMm, baselineY - 4.3 * pxPerMm);
    final bowPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: bowCenter,
            width: 15 * pxPerMm,
            height: 15 * pxPerMm,
          ),
          Radius.circular(3.5 * pxPerMm),
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: Offset(originX - 12.2 * pxPerMm, baselineY - 4.3 * pxPerMm),
          width: 4.2 * pxPerMm,
          height: 4.2 * pxPerMm,
        ),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(bowPath, metalPaint);

    // Espada (Blade) siguiendo exactamente el vector en milímetros
    final bladePath = Path()..moveTo(originX, baselineY);
    for (final pt in detectedContourMm) {
      final px = originX + pt.x * pxPerMm;
      final py = baselineY - pt.y * pxPerMm;
      bladePath.lineTo(px, py);
    }
    final lastX = originX + detectedContourMm.last.x * pxPerMm;
    bladePath.lineTo(lastX, baselineY);
    bladePath.close();
    canvas.drawPath(bladePath, metalPaint);
  }

  void _drawAlignmentGuide(
    Canvas canvas,
    Size size,
    double originX,
    double baselineY,
    double pxPerMm,
  ) {
    final guidePaint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    // Línea vertical de Tope de Hombro (X = 0 mm)
    canvas.drawLine(
      Offset(originX, baselineY - 13 * pxPerMm),
      Offset(originX, baselineY + 4 * pxPerMm),
      Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 2.2,
    );

    // Marco de encuadre de la espada (0 a 30 mm, alto 0 a 10 mm)
    final bladeBox = Rect.fromLTRB(
      originX,
      baselineY - 10.0 * pxPerMm,
      originX + 30.5 * pxPerMm,
      baselineY,
    );
    canvas.drawRect(bladeBox, guidePaint);

    // Etiqueta de tope de hombro
    final tp = TextPainter(
      text: const TextSpan(
        text: '▼ TOPE HOMBRO (X=0.0 mm)',
        style: TextStyle(
          color: Colors.redAccent,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          backgroundColor: Color(0x99000000),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(originX - 18, baselineY - 14.8 * pxPerMm));
  }

  void _drawVectorContour(
    Canvas canvas,
    List<VectorPoint> points,
    double originX,
    double baselineY,
    double pxPerMm, {
    required Color color,
    required double strokeWidth,
    required bool drawPoints,
  }) {
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final px = originX + points[i].x * pxPerMm;
      final py = baselineY - points[i].y * pxPerMm;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, linePaint);

    if (drawPoints) {
      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final ringPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      // Dibujamos los nodos cada 4 muestras para ver claramente la discretización (X, Y)
      for (int i = 0; i < points.length; i += 4) {
        final px = originX + points[i].x * pxPerMm;
        final py = baselineY - points[i].y * pxPerMm;
        canvas.drawCircle(Offset(px, py), 3.0, dotPaint);
        canvas.drawCircle(Offset(px, py), 3.0, ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant KeyGuideOverlayPainter oldDelegate) {
    return oldDelegate.detectedContourMm != detectedContourMm ||
        oldDelegate.comparisonContourMm != comparisonContourMm ||
        oldDelegate.showMillimeterGrid != showMillimeterGrid ||
        oldDelegate.showKeySilhouetteGuide != showKeySilhouetteGuide ||
        oldDelegate.simulatePhysicalKeyOnCanvas != simulatePhysicalKeyOnCanvas ||
        oldDelegate.contourColor != contourColor;
  }
}
