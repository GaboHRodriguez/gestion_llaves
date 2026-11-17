/// Configuración global de la solución y parámetros de negocio
class AppConfig {
  /// Endpoint por defecto para entorno local XAMPP (PHP + MySQL/MariaDB)
  static const String defaultApiBaseUrl = 'http://192.168.1.100/gestion_llaves/api';

  /// Ciclo máximo de préstamo antes de disparar alerta SMS obligatoria (Módulo C.2)
  static const int maxLoanRetentionDays = 30;

  /// Escala por defecto de la hoja milimetrada (10 mm = 1 cm)
  static const double referenceGridMm = 10.0;

  /// Umbral mínimo de similitud vectorial (%) para considerar coincidencia probable
  static const double minimumMatchThresholdPercent = 65.0;
}
