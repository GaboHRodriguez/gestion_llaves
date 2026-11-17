import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/rbac_provider.dart';
import '../../../buildings/domain/entities/building_entity.dart';
import '../../../buildings/presentation/providers/building_providers.dart';
import '../../../keys/domain/entities/key_entity.dart';
import '../../../keys/presentation/providers/key_providers.dart';
import '../../domain/entities/vector_point.dart';
import '../../domain/services/key_vectorizer_service.dart';
import '../widgets/key_guide_overlay_painter.dart';

class CameraVectorScreen extends ConsumerStatefulWidget {
  const CameraVectorScreen({super.key});

  @override
  ConsumerState<CameraVectorScreen> createState() => _CameraVectorScreenState();
}

class _CameraVectorScreenState extends ConsumerState<CameraVectorScreen> {
  // Alturas de los 6 cortes de dientes en milímetros para el banco óptico/simulador
  List<double> _currentCutsMm = [7.6, 5.1, 6.8, 4.3, 7.2, 5.4];
  double _bladeLengthMm = 28.5;
  double _sensorNoiseMm = 0.08;
  double _pixelsPerCm = 120.0;

  bool _showGrid = true;
  bool _showSilhouetteGuide = true;
  bool _isVerified = false;
  Uint8List? _importedPhotoBytes;
  VectorExtractionResult? _lastExtraction;
  KeyEntity? _selectedComparisonCandidate;

  @override
  void initState() {
    super.initState();
    _recomputeVector();
  }

  void _recomputeVector() {
    setState(() {
      _lastExtraction = KeyVectorizerService.generateFromBittingHeights(
        bittingDepthsMm: _currentCutsMm,
        bladeLengthMm: _bladeLengthMm,
        pixelsPerCm: _pixelsPerCm,
        noiseAmplitudeMm: _sensorNoiseMm,
      );
    });
  }

  Future<void> _importImageFromDisk() async {
    final hw = ref.read(platformHardwareServiceProvider);
    final bytes = await hw.pickImageBytesFromDisk();
    if (bytes != null) {
      final result = KeyVectorizerService.extractVectorFromImageBytes(
        bytes,
        manualPixelsPerCmOverride: _pixelsPerCm,
      );
      setState(() {
        _importedPhotoBytes = bytes;
        _lastExtraction = result;
        _isVerified = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imagen procesada: ${result.contourMm.length} puntos extraídos (Escala: ${result.pixelsPerCm.toStringAsFixed(0)} px/cm).',
            ),
          ),
        );
      }
    }
  }

  /// Simula la colocación de una "Llave Huérfana" sin etiqueta sobre la hoja milimetrada
  void _loadOrphanSamplePreset(String label, List<double> cuts, double length) {
    setState(() {
      _importedPhotoBytes = null;
      _currentCutsMm = List<double>.from(cuts);
      _bladeLengthMm = length;
      _sensorNoiseMm = 0.11; // Pequeña tolerancia realista de captura óptica
      _isVerified = true;
    });
    _recomputeVector();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Llave incógnita cargada en visor óptico: $label'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = ref.watch(keysNotifierProvider).valueOrNull ?? const <KeyEntity>[];
    final buildings =
        ref.watch(buildingsNotifierProvider).valueOrNull ?? const <BuildingEntity>[];
    final activeUser = ref.watch(activeUserProvider);
    final extraction = _lastExtraction;
    final contour = extraction?.contourMm ?? const <VectorPoint>[];

    // Calculamos el ranking de Matching contra todas las llaves de la BD (Módulo B.4)
    final rankedMatches = keys.map((k) {
      final metrics = KeyVectorizerService.compareKeyVectors(contour, k.vectorData);
      final bld = buildings.where((b) => b.idEdificio == k.idEdificio).firstOrNull;
      return (key: k, building: bld, metrics: metrics);
    }).toList()
      ..sort(
        (a, b) => b.metrics.matchPercentage.compareTo(a.metrics.matchPercentage),
      );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel Izquierdo: Visor de Cámara con Stack + CameraPreview/Imagen + CustomPaint
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Módulo B: Visión Artificial, Vectorización y Matching',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Stack + CameraPreview/Imagen + CustomPainter • Escala real sobre hoja milimetrada (1 cm = N px).',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Importar Foto (Windows/Cámara)'),
                          onPressed: _importImageFromDisk,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // VISOR PRINCIPAL CON STACK + IMAGEN/CAMARA + CUSTOMPAINTER
                    Container(
                      height: 330,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF070D19),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isVerified
                              ? const Color(0xFF00E676)
                              : const Color(0xFF38BDF8),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Capa 1: Vista previa de imagen/cámara si se importó archivo
                            if (_importedPhotoBytes != null)
                              Opacity(
                                opacity: 0.45,
                                child: Image.memory(
                                  _importedPhotoBytes!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            // Capa 2: CustomPainter superpuesto en tiempo real (Hoja milimetrada + Silueta + Vector)
                            CustomPaint(
                              painter: KeyGuideOverlayPainter(
                                detectedContourMm: contour,
                                comparisonContourMm:
                                    _selectedComparisonCandidate?.vectorData,
                                showMillimeterGrid: _showGrid,
                                showKeySilhouetteGuide: _showSilhouetteGuide,
                                simulatePhysicalKeyOnCanvas:
                                    _importedPhotoBytes == null,
                                contourColor: _isVerified
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFFFFEA00),
                              ),
                            ),
                            // Capa 3: HUD de telemetría óptica
                            Positioned(
                              top: 12,
                              left: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  'CALIBRACIÓN: 1 cm = ${_pixelsPerCm.toStringAsFixed(0)} px  |  '
                                  'LARGO ESPADA: ${_bladeLengthMm.toStringAsFixed(1)} mm  |  '
                                  'PUNTOS (X,Y): ${contour.length}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11.5,
                                    color: Color(0xFF00E676),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 10,
                              right: 12,
                              child: Row(
                                children: [
                                  FilterChip(
                                    label: const Text('Cuadrícula mm'),
                                    selected: _showGrid,
                                    onSelected: (v) =>
                                        setState(() => _showGrid = v),
                                  ),
                                  const SizedBox(width: 8),
                                  FilterChip(
                                    label: const Text('Guía Silueta'),
                                    selected: _showSilhouetteGuide,
                                    onSelected: (v) =>
                                        setState(() => _showSilhouetteGuide = v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Barra de presets rápidos para probar el Matching de Llaves Huérfanas
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Simulador Óptico de Llaves Huérfanas (Probar Reconocimiento Instantáneo):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.key, size: 16),
                                label: const Text('Muestra #1 (Similar a BELG-04-DEPB-01)'),
                                onPressed: () => _loadOrphanSamplePreset(
                                  'Muestra #1 (Depto 4B Belgrano)',
                                  const [7.6, 5.1, 6.8, 4.3, 7.2, 5.4],
                                  28.5,
                                ),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.key, size: 16),
                                label: const Text('Muestra #2 (Similar a LIBE-10-DEPA-01)'),
                                onPressed: () => _loadOrphanSamplePreset(
                                  'Muestra #2 (Multipunto Libertador 10A)',
                                  const [6.4, 6.1, 4.8, 6.5, 5.0, 6.2],
                                  29.5,
                                ),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.key, size: 16),
                                label: const Text('Muestra #3 (Similar a PALE-02-DEPC-01)'),
                                onPressed: () => _loadOrphanSamplePreset(
                                  'Muestra #3 (Palermo Soho 2C)',
                                  const [5.2, 7.4, 4.6, 7.5, 5.8, 3.9],
                                  28.0,
                                ),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.key, size: 16),
                                label: const Text('Muestra #4 (Similar a ALVE-SS-COCH-01)'),
                                onPressed: () => _loadOrphanSamplePreset(
                                  'Muestra #4 (Cocheras Alvear)',
                                  const [6.9, 3.8, 5.5, 6.7, 4.0, 6.8],
                                  30.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Ajuste fino de alturas de dientes (mm) y escala de cuadrícula
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Largo Espada: ${_bladeLengthMm.toStringAsFixed(1)} mm',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Slider(
                                      value: _bladeLengthMm,
                                      min: 24.0,
                                      max: 33.0,
                                      onChanged: (v) {
                                        _bladeLengthMm = v;
                                        _recomputeVector();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Calibración: 1 cm = ${_pixelsPerCm.toStringAsFixed(0)} px',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Slider(
                                      value: _pixelsPerCm,
                                      min: 80.0,
                                      max: 160.0,
                                      onChanged: (v) {
                                        _pixelsPerCm = v;
                                        _recomputeVector();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isVerified
                                        ? Icons.verified_rounded
                                        : Icons.visibility_outlined,
                                    color: _isVerified
                                        ? const Color(0xFF00E676)
                                        : Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isVerified
                                        ? 'Contorno verificado visualmente (Listo para persistir JSON)'
                                        : 'Verifique la alineación del contorno verde sobre la llave',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.check, size: 17),
                                    label: const Text('Confirmar Contorno'),
                                    onPressed: () =>
                                        setState(() => _isVerified = true),
                                  ),
                                  const SizedBox(width: 8),
                                  if (activeUser.canRegisterTechnicalKeys)
                                    FilledButton.icon(
                                      icon: const Icon(Icons.save_alt, size: 17),
                                      label: const Text('Asignar Vector a Llave'),
                                      onPressed: () => _showAssignVectorDialog(
                                        context,
                                        contour,
                                        keys,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            // Panel Derecho: Matching de Llaves Huérfanas (Módulo B.4)
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.manage_search_rounded, color: Color(0xFF38BDF8)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Matching de Llaves Huérfanas (Ranking %)',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Comparación vectorial (RMSE en mm + Similitud Coseno de pendientes). Toque una candidata para superponer su perfil en cian.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: rankedMatches.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = rankedMatches[index];
                          final pct = item.metrics.matchPercentage;
                          final isTopMatch = index == 0 && pct >= 80.0;
                          final isSelected = _selectedComparisonCandidate?.codigoInterno ==
                              item.key.codigoInterno;

                          final Color badgeColor = pct >= 85
                              ? const Color(0xFF00E676)
                              : (pct >= 70
                                  ? const Color(0xFFF59E0B)
                                  : Colors.blueGrey.shade300);

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _selectedComparisonCandidate =
                                    isSelected ? null : item.key;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0284C7).withValues(alpha: 0.22)
                                    : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isTopMatch
                                      ? const Color(0xFF00E676)
                                      : (isSelected
                                          ? const Color(0xFF38BDF8)
                                          : Colors.white12),
                                  width: isTopMatch || isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          if (isTopMatch)
                                            const Padding(
                                              padding: EdgeInsets.only(right: 6),
                                              child: Icon(
                                                Icons.stars_rounded,
                                                color: Color(0xFF00E676),
                                                size: 18,
                                              ),
                                            ),
                                          Text(
                                            item.key.codigoInterno,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: badgeColor),
                                        ),
                                        child: Text(
                                          '${pct.toStringAsFixed(1)}% COINCIDENCIA',
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Edificio: ${item.building?.nombre ?? item.key.idEdificio} • ${item.key.ubicacionDisplay}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (pct / 100.0).clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor: Colors.white10,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(badgeColor),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'RMSE: ${item.metrics.rmseMm} mm  |  ΔMáx: ${item.metrics.maxDeviationMm} mm  |  Sim. Pendiente: ${item.metrics.slopeCosineSimilarity}',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignVectorDialog(
    BuildContext context,
    List<VectorPoint> capturedVector,
    List<KeyEntity> existingKeys,
  ) {
    if (existingKeys.isEmpty) return;
    String selectedCode = existingKeys.first.codigoInterno;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Persistir Vector JSON en Base de Datos'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Se actualizará exclusivamente el campo JSON `vector_data` con las coordenadas normalizadas en milímetros (sin almacenar imágenes en la BD).',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedCode,
                  decoration: const InputDecoration(
                    labelText: 'Seleccionar Llave Destino (codigo_interno)',
                  ),
                  items: existingKeys
                      .map((k) => DropdownMenuItem(
                            value: k.codigoInterno,
                            child: Text('${k.codigoInterno} (${k.ubicacionDisplay})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedCode = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Guardar Vector JSON'),
              onPressed: () {
                final target = existingKeys.firstWhere(
                  (k) => k.codigoInterno == selectedCode,
                );
                ref.read(keysNotifierProvider.notifier).saveKey(
                      target.copyWith(vectorData: capturedVector),
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Vector JSON (${capturedVector.length} pts) guardado en $selectedCode.',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
