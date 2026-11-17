import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/rbac_provider.dart';
import '../../../../core/utils/key_nomenclature_generator.dart';
import '../../../keys/domain/entities/key_entity.dart';
import '../../../keys/presentation/providers/key_providers.dart';
import '../../domain/entities/building_entity.dart';
import '../providers/building_providers.dart';

class BuildingsScreen extends ConsumerWidget {
  const BuildingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeUser = ref.watch(activeUserProvider);
    final buildingsAsync = ref.watch(buildingsNotifierProvider);
    final keysList = ref.watch(keysNotifierProvider).valueOrNull ?? const <KeyEntity>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: activeUser.canManageBuildings
          ? FloatingActionButton.extended(
              onPressed: () => _showBuildingDialog(context, ref),
              icon: const Icon(Icons.domain_add),
              label: const Text('Alta de Edificio'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.apartment_rounded, size: 28, color: Color(0xFF38BDF8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Módulo A: Consorcios, Edificios y Unidades',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        activeUser.canManageBuildings
                            ? 'Rol activo (${activeUser.rol.dbValue}): Habilitado para alta, baja y modificación de edificios.'
                            : 'Rol activo (${activeUser.rol.dbValue}): Modo consulta operativa (RBAC Módulo D).',
                        style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade300),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: buildingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error al cargar edificios: $e')),
                data: (buildings) {
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisExtent: 195,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: buildings.length,
                    itemBuilder: (context, index) {
                      final b = buildings[index];
                      final bKeys = keysList.where((k) => k.idEdificio == b.idEdificio).toList();
                      final availableCount =
                          bKeys.where((k) => k.estado == KeyStatus.disponible).length;
                      final loanedCount =
                          bKeys.where((k) => k.estado == KeyStatus.entregada).length;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF38BDF8)),
                                  ),
                                  child: Text(
                                    b.idEdificio,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF38BDF8),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    b.nombre,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (activeUser.canManageBuildings)
                                  IconButton(
                                    tooltip: 'Editar Edificio',
                                    icon: const Icon(Icons.edit_outlined, size: 19),
                                    onPressed: () =>
                                        _showBuildingDialog(context, ref, existing: b),
                                  ),
                                if (activeUser.canDeleteRecords)
                                  IconButton(
                                    tooltip: 'Eliminar Edificio (Solo Gerencia)',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 19,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => ref
                                        .read(buildingsNotifierProvider.notifier)
                                        .removeBuilding(b.idEdificio),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    b.direccion,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Divider(color: Colors.white12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _MiniStatChip(
                                  label: 'Total Llaves',
                                  value: '${bKeys.length}',
                                  color: Colors.blueAccent,
                                ),
                                _MiniStatChip(
                                  label: 'En Tablero',
                                  value: '$availableCount',
                                  color: const Color(0xFF10B981),
                                ),
                                _MiniStatChip(
                                  label: 'Prestadas',
                                  value: '$loanedCount',
                                  color: Colors.amber,
                                ),
                              ],
                            ),
                          ],
                        ),
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

  void _showBuildingDialog(
    BuildContext context,
    WidgetRef ref, {
    BuildingEntity? existing,
  }) {
    final idCtrl = TextEditingController(text: existing?.idEdificio ?? '');
    final nameCtrl = TextEditingController(text: existing?.nombre ?? '');
    final dirCtrl = TextEditingController(text: existing?.direccion ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Registrar Nuevo Edificio' : 'Editar Edificio'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idCtrl,
                enabled: existing == null,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Código Prefijo (id_edificio VARCHAR 10)',
                  hintText: 'Ej: BELG, LIBE, TORR1',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Consorcio / Edificio',
                  hintText: 'Ej: Torre Belgrano Plaza',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dirCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección Oficial',
                  hintText: 'Ej: Av. Belgrano 1840, CABA',
                ),
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
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar en Repositorio'),
            onPressed: () {
              final cleanId = KeyNomenclatureGenerator.sanitizeSegment(
                idCtrl.text,
                maxLength: 10,
              );
              if (nameCtrl.text.trim().isEmpty) return;
              ref.read(buildingsNotifierProvider.notifier).addOrUpdateBuilding(
                    BuildingEntity(
                      idEdificio: cleanId,
                      nombre: nameCtrl.text.trim(),
                      direccion: dirCtrl.text.trim(),
                    ),
                  );
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
