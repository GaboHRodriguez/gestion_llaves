import '../../../../core/config/app_config.dart';

/// Entidad Movimiento de Préstamo/Entrega de Llave (Módulo A.2 y Módulo C)
class LoanMovementEntity {
  final int idMovimiento;
  final String codigoLlave;
  final String contactoNombre;
  final String contactoTelefono;
  final DateTime fechaSalida;
  final DateTime fechaDevolucionPrevista; // Automáticamente fechaSalida + 30 días
  final DateTime? fechaDevolucionReal;
  final String entregadoPor;

  const LoanMovementEntity({
    required this.idMovimiento,
    required this.codigoLlave,
    required this.contactoNombre,
    required this.contactoTelefono,
    required this.fechaSalida,
    required this.fechaDevolucionPrevista,
    this.fechaDevolucionReal,
    required this.entregadoPor,
  });

  bool get isActive => fechaDevolucionReal == null;

  int get daysElapsed {
    final end = fechaDevolucionReal ?? DateTime.now();
    return end.difference(fechaSalida).inDays.clamp(0, 9999);
  }

  /// Verifica si supera el ciclo de 30 días sin devolución (Módulo C.2)
  bool get isOverdue30Days =>
      isActive &&
      (DateTime.now().isAfter(fechaDevolucionPrevista) ||
          daysElapsed > AppConfig.maxLoanRetentionDays);

  int get daysOverdue {
    if (!isOverdue30Days) return 0;
    return daysElapsed - AppConfig.maxLoanRetentionDays;
  }

  LoanMovementEntity copyWith({
    int? idMovimiento,
    String? codigoLlave,
    String? contactoNombre,
    String? contactoTelefono,
    DateTime? fechaSalida,
    DateTime? fechaDevolucionPrevista,
    DateTime? fechaDevolucionReal,
    String? entregadoPor,
  }) {
    return LoanMovementEntity(
      idMovimiento: idMovimiento ?? this.idMovimiento,
      codigoLlave: codigoLlave ?? this.codigoLlave,
      contactoNombre: contactoNombre ?? this.contactoNombre,
      contactoTelefono: contactoTelefono ?? this.contactoTelefono,
      fechaSalida: fechaSalida ?? this.fechaSalida,
      fechaDevolucionPrevista:
          fechaDevolucionPrevista ?? this.fechaDevolucionPrevista,
      fechaDevolucionReal: fechaDevolucionReal ?? this.fechaDevolucionReal,
      entregadoPor: entregadoPor ?? this.entregadoPor,
    );
  }

  factory LoanMovementEntity.fromJson(Map<String, dynamic> json) {
    final salida = DateTime.tryParse((json['fecha_salida'] ?? '').toString()) ??
        DateTime.now();
    final prevista = DateTime.tryParse(
          (json['fecha_devolucion_prevista'] ?? '').toString(),
        ) ??
        salida.add(const Duration(days: AppConfig.maxLoanRetentionDays));
    final realRaw = json['fecha_devolucion_real']?.toString();
    final real = (realRaw != null && realRaw.trim().isNotEmpty)
        ? DateTime.tryParse(realRaw)
        : null;

    return LoanMovementEntity(
      idMovimiento: (json['id_movimiento'] as num?)?.toInt() ?? 0,
      codigoLlave: (json['codigo_llave'] ?? '').toString().toUpperCase(),
      contactoNombre: (json['contacto_nombre'] ?? '').toString(),
      contactoTelefono: (json['contacto_telefono'] ?? '').toString(),
      fechaSalida: salida,
      fechaDevolucionPrevista: prevista,
      fechaDevolucionReal: real,
      entregadoPor: (json['entregado_por'] ?? 'Operador').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id_movimiento': idMovimiento,
        'codigo_llave': codigoLlave,
        'contacto_nombre': contactoNombre,
        'contacto_telefono': contactoTelefono,
        'fecha_salida': fechaSalida.toIso8601String(),
        'fecha_devolucion_prevista': fechaDevolucionPrevista.toIso8601String(),
        'fecha_devolucion_real': fechaDevolucionReal?.toIso8601String(),
        'entregado_por': entregadoPor,
      };
}
