/// Entidad Edificio (Módulo A.2):
/// `id_edificio` (VARCHAR 10), `nombre`, `direccion`
class BuildingEntity {
  final String idEdificio;
  final String nombre;
  final String direccion;

  const BuildingEntity({
    required this.idEdificio,
    required this.nombre,
    required this.direccion,
  });

  factory BuildingEntity.fromJson(Map<String, dynamic> json) {
    return BuildingEntity(
      idEdificio: (json['id_edificio'] ?? '').toString().toUpperCase().trim(),
      nombre: (json['nombre'] ?? '').toString().trim(),
      direccion: (json['direccion'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id_edificio': idEdificio,
        'nombre': nombre,
        'direccion': direccion,
      };
}
