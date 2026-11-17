import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/rbac_provider.dart';
import '../../../../core/widgets/barcode_qr_label_widget.dart';
import '../../../buildings/presentation/providers/building_providers.dart';
import '../../../camera_vector/domain/services/key_vectorizer_service.dart';
import '../../../camera_vector/presentation/widgets/key_guide_overlay_painter.dart';
import '../../domain/entities/key_entity.dart';
import '../providers/key_providers.dart';

class KeysInventoryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenVectorizerTab;

  const KeysInventoryScreen({
    super.key,
    this.onOpenVectorizerTab,
  });

  @override
  ConsumerState<KeysInventoryScreen> createState() =>
      _KeysInventoryScreenState();
}

class _KeysInventoryScreenState extends ConsumerState<KeysInventoryScreen> {
  String _selectedBuildingFilter = 'TODOS';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final activeUser = ref.watch(activeUserProvider);
    final keysAsync = ref.watch(keysNotifierProvider);
    final buildings =
        ref.watch(buildingsNotifierProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: activeUser.canRegisterTechnicalKeys
          ? FloatingActionButton.extended(
              onPressed: () => _showNewKeyDialog(context),
              icon: const Icon(Icons.vpn_key_outlined),
              label: const Text('Alta Técnica de Llave'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Módulo A: Inventario Maestro de Llaves y Etiquetas QR/Code128',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Nomenclatura jerárquica [EDIFICIO]-[PISO/DEPTO/ZONA]-[CORRELATIVO] • Almacenamiento 100% Vectorial JSON (0% imágenes pesadas).',
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade300),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search, size: 18),
                          hintText: 'Buscar código o unidad...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _selectedBuildingFilter,
                      items: [
                        const DropdownMenuItem(
                          value: 'TODOS',
                          child: Text('Todos los Edificios'),
                        ),
                        ...buildings.map(
                          (b) => DropdownMenuItem(
                            value: b.idEdificio,
                            child: Text('${b.idEdificio} - ${b.nombre}'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedBuildingFilter = val);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: keysAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error al cargar inventario: $e')),
                data: (keys) {
                  final filtered = keys.where((k) {
                    final matchesBuilding = _selectedBuildingFilter == 'TODOS' ||
                        k.idEdificio == _selectedBuildingFilter;
                    final matchesSearch = _searchQuery.isEmpty ||
                        k.codigoInterno.toLowerCase().contains(_searchQuery) ||
                        k.ubicacionDisplay.toLowerCase().contains(_searchQuery) ||
                        k.tipoLlave.label.toLowerCase().contains(_searchQuery);
                    return matchesBuilding && matchesSearch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No se encontraron llaves con los filtros actuales.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final k = filtered[index];
                      return _KeyInventoryCard(
                        keyEntity: k,
                        canEdit: activeUser.canRegisterTechnicalKeys,
                        canDelete: activeUser.canDeleteRecords,
                        onInspectVector: () => _showVectorInspectorModal(context, k),
                        onDelete: () => ref
                            .read(keysNotifierProvider.notifier)
                            .deleteKey(k.codigoInterno),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVectorInspectorModal(BuildContext context, KeyEntity keyEntity) {
    final jsonPayload = keyEntity.vectorDataJson;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.polyline_rounded, color: Color(0xFF00E676)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Ficha Técnica y Vector JSON: ${keyEntity.codigoInterno}'),
            ),
          ],
        ),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: BarcodeQrLabelWidget(
                    codigoInterno: keyEntity.codigoInterno,
                    subtitulo: keyEntity.ubicacionDisplay,
                    tipoLlave: keyEntity.tipoLlave.dbValue,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reconstrucción Geométrica desde Coordenadas (X, Y) en milímetros:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1120),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyan.withValues(alpha: 0.4)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: KeyGuideOverlayPainter(
                        detectedContourMm: keyEntity.vectorData,
                        showMillimeterGrid: true,
                        showKeySilhouetteGuide: true,
                        simulatePhysicalKeyOnCanvas: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payload SQL vector_data (${keyEntity.vectorData.length} puntos X,Y • ${jsonPayload.length} bytes):',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Colors.amberAccent,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar JSON'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: jsonPayload));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('JSON de coordenadas vectoriales copiado al portapapeles.'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Container(
                  height: 95,
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      jsonPayload,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showNewKeyDialog(BuildContext context) {
    final buildings =
        ref.read(buildingsNotifierProvider).valueOrNull ?? const [];
    String selectedBuilding =
        buildings.isNotEmpty ? buildings.first.idEdificio : 'BELG';
    bool isCommonZone = false;
    final pisoDeptoCtrl = TextEditingController(text: '04-DEPB');
    final zonaComunCtrl = TextEditingController(text: 'PB-SUM');
    KeyType selectedType = KeyType.sierra;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final generatedCode = ref
              .read(keysNotifierProvider.notifier)
              .suggestNextHierarchicalCode(
                idEdificio: selectedBuilding,
                pisoDepto: isCommonZone ? '' : pisoDeptoCtrl.text,
                zonaComun: isCommonZone ? zonaComunCtrl.text : '',
              );

          return AlertDialog(
            title: const Text('Alta Técnica de Llave con Nomenclatura Automática'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedBuilding,
                      decoration: const InputDecoration(labelText: 'Edificio (id_edificio)'),
                      items: buildings
                          .map((b) => DropdownMenuItem(
                                value: b.idEdificio,
                                child: Text('${b.idEdificio} - ${b.nombre}'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedBuilding = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('¿Corresponde a Zona Común?'),
                      subtitle: const Text('Alternar entre Piso/Depto o Sector Común'),
                      value: isCommonZone,
                      onChanged: (v) => setModalState(() => isCommonZone = v),
                    ),
                    if (!isCommonZone)
                      TextField(
                        controller: pisoDeptoCtrl,
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Piso / Departamento (Ej: 04-DEPB, 10-DEPA)',
                        ),
                      )
                    else
                      TextField(
                        controller: zonaComunCtrl,
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Zona Común (Ej: PB-SUM, AZ-TERR, SS-COCH)',
                        ),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<KeyType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Tipo de Llave (tipo_llave)'),
                      items: KeyType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedType = v);
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Vista Previa de Etiqueta Autogenerada (QR + Code128):',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: BarcodeQrLabelWidget(
                        codigoInterno: generatedCode,
                        subtitulo: isCommonZone ? zonaComunCtrl.text : pisoDeptoCtrl.text,
                        tipoLlave: selectedType.dbValue,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Crear Llave con Perfil Base'),
                onPressed: () {
                  final defaultVector = KeyVectorizerService.generateFromBittingHeights(
                    bittingDepthsMm: const [7.4, 5.0, 6.6, 4.5, 7.0, 5.3],
                    bladeLengthMm: 28.5,
                  ).contourMm;

                  final newKey = KeyEntity(
                    codigoInterno: generatedCode,
                    idEdificio: selectedBuilding,
                    pisoDepto: isCommonZone ? '' : pisoDeptoCtrl.text.trim().toUpperCase(),
                    zonaComun: isCommonZone ? zonaComunCtrl.text.trim().toUpperCase() : '',
                    tipoLlave: selectedType,
                    vectorData: defaultVector,
                    estado: KeyStatus.disponible,
                  );
                  ref.read(keysNotifierProvider.notifier).saveKey(newKey);
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KeyInventoryCard extends StatelessWidget {
  final KeyEntity keyEntity;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onInspectVector;
  final VoidCallback onDelete;

  const _KeyInventoryCard({
    required this.keyEntity,
    required this.canEdit,
    required this.canDelete,
    required this.onInspectVector,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    switch (keyEntity.estado) {
      case KeyStatus.disponible:
        statusColor = const Color(0xFF10B981);
        break;
      case KeyStatus.entregada:
        statusColor = const Color(0xFFF59E0B);
        break;
      case KeyStatus.perdida:
        statusColor = const Color(0xFFEF4444);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          BarcodeQrLabelWidget(
            codigoInterno: keyEntity.codigoInterno,
            subtitulo: keyEntity.ubicacionDisplay,
            tipoLlave: keyEntity.tipoLlave.dbValue,
            compact: true,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      keyEntity.estado.label.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Edificio: ${keyEntity.idEdificio}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tipo: ${keyEntity.tipoLlave.label}',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                'Vector JSON: ${keyEntity.vectorData.length} coordenadas (X, Y) en mm',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF38BDF8),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text('Ver Vector / QR'),
                onPressed: onInspectVector,
              ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Eliminar Llave (Solo Gerencia)',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
