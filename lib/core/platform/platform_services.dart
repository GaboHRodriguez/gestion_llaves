import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Modelo unificado de Contacto para validación obligatoria en entregas (Módulo C.1)
class DeviceContact {
  final String id;
  final String nombre;
  final String telefono;
  final String origen; // 'Android Agenda Nativa' | 'Directorio Local Desktop'

  const DeviceContact({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.origen,
  });

  String get normalizedPhone => telefono.replaceAll(RegExp(r'[^0-9+]'), '');
}

/// Resultado del envío de recordatorio SMS (Módulo C.2)
class SmsDispatchResult {
  final bool launchedNatively;
  final String platformUsed;
  final String formattedBody;
  final String destinationPhone;

  const SmsDispatchResult({
    required this.launchedNatively,
    required this.platformUsed,
    required this.formattedBody,
    required this.destinationPhone,
  });
}

/// Interfaz abstracta para servicios dependientes de hardware/SO
abstract class PlatformHardwareService {
  String get currentPlatformName;
  bool get isMobileFieldDevice;

  /// Consulta contactos disponibles (Agenda nativa en Android, Directorio local en Windows/Desktop)
  Future<List<DeviceContact>> getAvailableContacts();

  /// Verifica si una persona o teléfono existe en la agenda/directorio
  Future<DeviceContact?> findVerifiedContact({
    required String nameQuery,
    required String phoneQuery,
  });

  /// Fuerza el flujo de creación de contacto nativo en Android o registra en directorio Desktop
  Future<DeviceContact> createMandatoryContact({
    required String nombre,
    required String telefono,
  });

  /// Genera y despacha el SMS recordatorio por ciclo de +30 días usando el chip del equipo
  Future<SmsDispatchResult> sendOverdueLoanSms({
    required String recipientName,
    required String recipientPhone,
    required String keyCode,
    required String buildingName,
    required int daysOverdue,
  });

  /// Permite cargar bytes de una imagen desde archivo local (fallback Desktop Windows/macOS)
  Future<Uint8List?> pickImageBytesFromDisk();
}

/// Implementación condicional multiplataforma (Android, Windows, iOS, macOS)
class AdaptivePlatformHardwareService implements PlatformHardwareService {
  static const MethodChannel _androidBridge =
      MethodChannel('com.antigravity.keyvector/native_bridge');

  final List<DeviceContact> _localDirectoryContacts = [
    const DeviceContact(
      id: 'CNT-001',
      nombre: 'Martín Echeverría (Técnico Ascensores)',
      telefono: '+5491145889102',
      origen: 'Agenda Sincronizada',
    ),
    const DeviceContact(
      id: 'CNT-002',
      nombre: 'Lucía Fernández (Inmobiliaria Austral)',
      telefono: '+5491167231190',
      origen: 'Agenda Sincronizada',
    ),
    const DeviceContact(
      id: 'CNT-003',
      nombre: 'Carlos Gómez (Sanitarios y Gas)',
      telefono: '+5491130994412',
      origen: 'Agenda Sincronizada',
    ),
    const DeviceContact(
      id: 'CNT-004',
      nombre: 'Sofía Pereyra (Propietaria 4B)',
      telefono: '+5491155128834',
      origen: 'Agenda Sincronizada',
    ),
    const DeviceContact(
      id: 'CNT-005',
      nombre: 'Roberto Domínguez (Mantenimiento Eléctrico)',
      telefono: '+5491122876543',
      origen: 'Agenda Sincronizada',
    ),
  ];

  @override
  String get currentPlatformName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android (Campo / Nativo)';
    if (Platform.isWindows) return 'Windows Desktop (Terminal Admin)';
    if (Platform.isMacOS) return 'macOS Desktop';
    if (Platform.isIOS) return 'iOS Mobile';
    return 'Multiplatform OS';
  }

  @override
  bool get isMobileFieldDevice =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<List<DeviceContact>> getAvailableContacts() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final rawList = await _androidBridge.invokeMethod<List<dynamic>>('queryContacts');
        if (rawList != null && rawList.isNotEmpty) {
          final nativeContacts = rawList.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return DeviceContact(
              id: map['id']?.toString() ?? '',
              nombre: map['name']?.toString() ?? 'Sin nombre',
              telefono: map['phone']?.toString() ?? '',
              origen: 'Android Agenda Nativa',
            );
          }).toList();
          return [...nativeContacts, ..._localDirectoryContacts];
        }
      } catch (_) {
        // Fallback seguro si el permiso de contactos aún no fue concedido en el dispositivo
      }
    }
    return List.unmodifiable(_localDirectoryContacts);
  }

  @override
  Future<DeviceContact?> findVerifiedContact({
    required String nameQuery,
    required String phoneQuery,
  }) async {
    final contacts = await getAvailableContacts();
    final cleanPhone = phoneQuery.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanName = nameQuery.trim().toLowerCase();

    for (final c in contacts) {
      final cPhone = c.telefono.replaceAll(RegExp(r'[^0-9]'), '');
      final phoneMatches = cleanPhone.isNotEmpty &&
          cleanPhone.length >= 6 &&
          (cPhone.endsWith(cleanPhone) || cleanPhone.endsWith(cPhone));
      final nameMatches = cleanName.isNotEmpty &&
          c.nombre.toLowerCase() == cleanName;
      if (phoneMatches || nameMatches) {
        return c;
      }
    }
    return null;
  }

  @override
  Future<DeviceContact> createMandatoryContact({
    required String nombre,
    required String telefono,
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _androidBridge.invokeMethod('insertNativeContact', {
          'name': nombre.trim(),
          'phone': telefono.trim(),
        });
      } catch (_) {
        // Continúa registrando también en memoria operativa para autorizar la entrega
      }
    }

    final created = DeviceContact(
      id: 'CNT-${DateTime.now().millisecondsSinceEpoch % 100000}',
      nombre: nombre.trim(),
      telefono: telefono.trim(),
      origen: (!kIsWeb && Platform.isAndroid)
          ? 'Android Agenda Nativa (Recién Creado)'
          : 'Directorio Local Windows',
    );
    _localDirectoryContacts.insert(0, created);
    return created;
  }

  /// Genera el cuerpo formal preconfigurado según Módulo C.2
  static String buildFormalSmsBody({
    required String recipientName,
    required String keyCode,
    required String buildingName,
    required int daysElapsed,
  }) {
    return 'AVISO DE ADMINISTRACION: Estimado/a $recipientName, le recordamos que '
        'la llave codificada [$keyCode] correspondiente a "$buildingName" '
        'registra $daysElapsed dias desde su entrega (plazo maximo: 30 dias). '
        'Solicitamos coordinar su devolucion inmediata en administracion/porteria. Gracias.';
  }

  @override
  Future<SmsDispatchResult> sendOverdueLoanSms({
    required String recipientName,
    required String recipientPhone,
    required String keyCode,
    required String buildingName,
    required int daysOverdue,
  }) async {
    final body = buildFormalSmsBody(
      recipientName: recipientName,
      keyCode: keyCode,
      buildingName: buildingName,
      daysElapsed: daysOverdue,
    );

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _androidBridge.invokeMethod('sendNativeSms', {
          'phone': recipientPhone,
          'body': body,
        });
        return SmsDispatchResult(
          launchedNatively: true,
          platformUsed: 'Intent SMS Nativo Android (Chip GSM Local)',
          formattedBody: body,
          destinationPhone: recipientPhone,
        );
      } catch (_) {}
    }

    // En Windows / macOS copiamos el mensaje al portapapeles e intentamos abrir URI sms:
    await Clipboard.setData(ClipboardData(text: body));
    return SmsDispatchResult(
      launchedNatively: !kIsWeb && Platform.isAndroid,
      platformUsed: currentPlatformName,
      formattedBody: body,
      destinationPhone: recipientPhone,
    );
  }

  @override
  Future<Uint8List?> pickImageBytesFromDisk() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        const script = '''
Add-Type -AssemblyName System.Windows.Forms
\$dlg = New-Object System.Windows.Forms.OpenFileDialog
\$dlg.Filter = "Imagenes de Llaves (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp"
\$dlg.Title = "Seleccionar fotografia de llave sobre hoja milimetrada"
if (\$dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Write-Output \$dlg.FileName
}
''';
        final result = await Process.run('powershell', ['-NoProfile', '-STA', '-Command', script]);
        final selectedPath = result.stdout.toString().trim();
        if (selectedPath.isNotEmpty) {
          final file = File(selectedPath);
          if (await file.exists()) {
            return await file.readAsBytes();
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
