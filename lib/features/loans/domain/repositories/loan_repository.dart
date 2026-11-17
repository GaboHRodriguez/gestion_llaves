import '../entities/loan_movement_entity.dart';

/// Interfaz desacoplada de repositorio de Movimientos / Préstamos (Repository Pattern)
abstract class LoanRepository {
  Future<List<LoanMovementEntity>> getAllMovements();
  Future<LoanMovementEntity> registerCheckOut({
    required String codigoLlave,
    required String contactoNombre,
    required String contactoTelefono,
    required String entregadoPor,
    DateTime? customCheckoutDate,
  });
  Future<LoanMovementEntity> registerReturn(int idMovimiento);
}
