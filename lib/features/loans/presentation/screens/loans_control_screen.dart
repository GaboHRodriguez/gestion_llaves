import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/auth/rbac_provider.dart';
import '../../../../core/platform/platform_services.dart';
import '../../../buildings/presentation/providers/building_providers.dart';
import '../../../keys/domain/entities/key_entity.dart';
import '../../../keys/presentation/providers/key_providers.dart';
import '../../domain/entities/loan_movement_entity.dart';
import '../providers/loan_providers.dart';

class LoansControlScreen extends ConsumerStatefulWidget {
  const LoansControlScreen({super.key});

  @override
  ConsumerState<LoansControlScreen> createState() => _LoansControlScreenState();
}

class _LoansControlScreenState extends ConsumerState<LoansControlScreen> {
  bool _onlyOverdue30Days = false;

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(loansNotifierProvider);
    final overdueList = ref.watch(overdueLoansProvider);
    final keys = ref.watch(keysNotifierProvider).valueOrNull ?? const <KeyEntity>[];
    final availableKeys =
        keys.where((k) => k.estado == KeyStatus.disponible).toList();
    final hw = ref.watch(platformHardwareServiceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCheckoutModal(context, availableKeys),
        icon: const Icon(Icons.vpn_key),
        label: const Text('Registrar Entrega de Llave'),
      ),
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
                      'Módulo C: Control de Préstamos, Agenda Nativa y Alertas SMS (+30 Días)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Plataforma activa: ${hw.currentPlatformName} • Validación obligatoria de contacto antes de autorizar salida.',
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade300),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilterChip(
                      avatar: const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Colors.amberAccent,
                      ),
                      label: Text(
                        'Solo Vencidos >30 Días (${overdueList.length})',
                      ),
                      selected: _onlyOverdue30Days,
                      onSelected: (v) => setState(() => _onlyOverdue30Days = v),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Banner de monitoreo de ciclo de 30 días (Módulo C.2)
            if (overdueList.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D).withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sms_failed_outlined, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'MONITOR DE RETENCIÓN (CICLO 30 DÍAS): Se detectaron ${overdueList.length} llaves que superan los 30 días sin devolución. '
                        'Utilice el botón "Despachar SMS Nativo" para notificar vía chip GSM sin costo de infraestructura.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: loansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error al cargar préstamos: $e')),
                data: (movements) {
                  final list = _onlyOverdue30Days
                      ? movements.where((m) => m.isOverdue30Days).toList()
                      : movements;

                  if (list.isEmpty) {
                    return const Center(
                      child: Text('No hay movimientos registrados para este filtro.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final m = list[index];
                      return _LoanMovementCard(
                        movement: m,
                        onDispatchSms: () => _triggerNativeSmsAlert(context, m),
                        onRegisterReturn: () async {
                          await ref
                              .read(loansNotifierProvider.notifier)
                              .returnKey(m);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Devolución registrada. Llave ${m.codigoLlave} nuevamente DISPONIBLE en tablero.',
                                ),
                              ),
                            );
                          }
                        },
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

  Future<void> _triggerNativeSmsAlert(
    BuildContext context,
    LoanMovementEntity movement,
  ) async {
    final hw = ref.read(platformHardwareServiceProvider);
    final buildings =
        ref.read(buildingsNotifierProvider).valueOrNull ?? const [];
    final prefix = movement.codigoLlave.split('-').first;
    final bldName = buildings
            .where((b) => b.idEdificio == prefix)
            .map((b) => b.nombre)
            .firstOrNull ??
        'Consorcio $prefix';

    final res = await hw.sendOverdueLoanSms(
      recipientName: movement.contactoNombre,
      recipientPhone: movement.contactoTelefono,
      keyCode: movement.codigoLlave,
      buildingName: bldName,
      daysOverdue: movement.daysElapsed,
    );

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sms_outlined, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Expanded(
              child: Text('Despacho de Recordatorio SMS (Ciclo +30 Días)'),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Canal utilizado: ${res.platformUsed}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E676),
                ),
              ),
              const SizedBox(height: 6),
              Text('Destinatario: ${movement.contactoNombre} (${res.destinationPhone})'),
              const SizedBox(height: 12),
              const Text(
                'Cuerpo preconfigurado despachado al Intent nativo de SMS:',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  res.formattedBody,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Flujo de entrega con Validación Obligatoria de Contacto (Módulo C.1)
  Future<void> _showCheckoutModal(
    BuildContext context,
    List<KeyEntity> availableKeys,
  ) async {
    if (availableKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay llaves con estado DISPONIBLE para entregar en este momento.'),
        ),
      );
      return;
    }

    final hw = ref.read(platformHardwareServiceProvider);
    final contacts = await hw.getAvailableContacts();
    if (!context.mounted) return;

    String selectedKeyCode = availableKeys.first.codigoInterno;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    DeviceContact? verifiedContact;
    bool requiresNativeCreationAlert = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: const Text('Registrar Salida de Llave (Validación de Contacto)'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedKeyCode,
                      decoration: const InputDecoration(
                        labelText: 'Llave Disponible a Entregar',
                      ),
                      items: availableKeys
                          .map((k) => DropdownMenuItem(
                                value: k.codigoInterno,
                                child: Text('${k.codigoInterno} (${k.ubicacionDisplay})'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedKeyCode = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Seleccionar Contacto de Agenda / Directorio:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<DeviceContact>(
                      initialValue: verifiedContact,
                      hint: const Text('Elegir contacto existente en agenda...'),
                      items: contacts
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text('${c.nombre} (${c.telefono})'),
                              ))
                          .toList(),
                      onChanged: (c) {
                        if (c != null) {
                          setModalState(() {
                            verifiedContact = c;
                            nameCtrl.text = c.nombre;
                            phoneCtrl.text = c.telefono;
                            requiresNativeCreationAlert = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'O ingrese datos de una persona nueva (disparará alta obligatoria de contacto):',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) => setModalState(() {
                        verifiedContact = null;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Nombre y Apellido / Empresa',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      onChanged: (_) => setModalState(() {
                        verifiedContact = null;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Teléfono Celular (para alertas SMS 30 días)',
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                    ),
                    if (requiresNativeCreationAlert) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.contact_phone, color: Colors.amber),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'BLOQUEO DE SEGURIDAD (Módulo C.1): Contacto No Agendado',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'La persona ingresada no existe en la libreta de direcciones. '
                              'Debe crear el contacto nativo antes de autorizar la salida de la llave.',
                              style: TextStyle(fontSize: 12.5),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text(
                                'Abrir Alta de Contacto Nativo y Verificar',
                              ),
                              onPressed: () async {
                                final created = await hw.createMandatoryContact(
                                  nombre: nameCtrl.text,
                                  telefono: phoneCtrl.text,
                                );
                                setModalState(() {
                                  verifiedContact = created;
                                  requiresNativeCreationAlert = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
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
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Validar Contacto y Autorizar Entrega'),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  if (name.isEmpty || phone.isEmpty) return;

                  // Validación obligatoria en agenda (Módulo C.1)
                  final found = verifiedContact ??
                      await hw.findVerifiedContact(
                        nameQuery: name,
                        phoneQuery: phone,
                      );

                  if (found == null) {
                    setModalState(() => requiresNativeCreationAlert = true);
                    return;
                  }

                  await ref.read(loansNotifierProvider.notifier).checkOutKey(
                        codigoLlave: selectedKeyCode,
                        contactoNombre: found.nombre,
                        contactoTelefono: found.telefono,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoanMovementCard extends StatelessWidget {
  final LoanMovementEntity movement;
  final VoidCallback onDispatchSms;
  final VoidCallback onRegisterReturn;

  const _LoanMovementCard({
    required this.movement,
    required this.onDispatchSms,
    required this.onRegisterReturn,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    final isOverdue = movement.isOverdue30Days;
    final isActive = movement.isActive;

    final Color borderColor = isOverdue
        ? Colors.redAccent
        : (isActive ? Colors.amber : Colors.white12);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isOverdue ? 1.8 : 1.0),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    movement.codigoLlave,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? Colors.redAccent.withValues(alpha: 0.2)
                          : (isActive
                              ? Colors.amber.withValues(alpha: 0.2)
                              : Colors.green.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOverdue
                          ? 'VENCIDO: ${movement.daysElapsed} DÍAS (+${movement.daysOverdue}d EXCEDIDO)'
                          : (isActive
                              ? 'ACTIVO (${movement.daysElapsed} de 30 días)'
                              : 'DEVUELTA EL ${df.format(movement.fechaDevolucionReal!)}'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isOverdue
                            ? Colors.redAccent
                            : (isActive ? Colors.amber : Colors.greenAccent),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Destinatario: ${movement.contactoNombre}  •  Tel: ${movement.contactoTelefono}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Salida: ${df.format(movement.fechaSalida)}  |  Devolución Prevista (+30d): ${df.format(movement.fechaDevolucionPrevista)}  |  Entregó: ${movement.entregadoPor}',
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
          if (isActive)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.sms_outlined,
                    size: 17,
                    color: isOverdue ? Colors.redAccent : Colors.amberAccent,
                  ),
                  label: Text(
                    isOverdue ? 'Alerta SMS (+30d)' : 'Recordatorio SMS',
                  ),
                  onPressed: onDispatchSms,
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  icon: const Icon(Icons.assignment_returned_outlined, size: 17),
                  label: const Text('Recibir Llave'),
                  onPressed: onRegisterReturn,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
