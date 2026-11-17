/// Modelos de Control de Acceso Basado en Roles (RBAC - Módulo D)
enum UserRole {
  gerencia('Gerencia', 'Acceso total, métricas de retención, historial global y auditorías'),
  administracion('Administracion', 'Alta/baja/modificación de edificios, unidades y registro técnico de llaves'),
  encargado('Encargado', 'Flujo operativo: escaneo QR/código, entrega, devolución y consulta de estado');

  final String dbValue;
  final String description;
  const UserRole(this.dbValue, this.description);

  static UserRole fromString(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.startsWith('geren')) return UserRole.gerencia;
    if (normalized.startsWith('admin')) return UserRole.administracion;
    return UserRole.encargado;
  }
}

class AppUser {
  final int idUsuario;
  final String nombreUsuario;
  final String nombreCompleto;
  final UserRole rol;

  const AppUser({
    required this.idUsuario,
    required this.nombreUsuario,
    required this.nombreCompleto,
    required this.rol,
  });

  // Permisos granulares según Módulo D
  bool get canViewGlobalMetricsAndAudits => rol == UserRole.gerencia;
  bool get canManageBuildings =>
      rol == UserRole.gerencia || rol == UserRole.administracion;
  bool get canRegisterTechnicalKeys =>
      rol == UserRole.gerencia || rol == UserRole.administracion;
  bool get canDeleteRecords => rol == UserRole.gerencia;
  bool get canOperateLoans => true; // Todos los roles pueden entregar/recibir o auditar

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      idUsuario: (json['id_usuario'] as num?)?.toInt() ?? 1,
      nombreUsuario: (json['nombre_usuario'] ?? 'operador').toString(),
      nombreCompleto: (json['nombre_completo'] ?? json['nombre_usuario'] ?? 'Usuario').toString(),
      rol: UserRole.fromString((json['rol'] ?? 'Encargado').toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id_usuario': idUsuario,
        'nombre_usuario': nombreUsuario,
        'nombre_completo': nombreCompleto,
        'rol': rol.dbValue,
      };
}
