-- =========================================================================
-- ESQUEMA RELACIONAL MYSQL / MARIADB (XAMPP)
-- PROYECTO: SISTEMA DE GESTIÓN Y RECONOCIMIENTO VECTORIAL DE LLAVES
-- =========================================================================

CREATE DATABASE IF NOT EXISTS gestion_llaves_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE gestion_llaves_db;

-- 1. Tabla Edificio
CREATE TABLE IF NOT EXISTS edificios (
  id_edificio VARCHAR(10) NOT NULL PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL,
  direccion VARCHAR(200) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Tabla Usuario / RBAC
CREATE TABLE IF NOT EXISTS usuarios (
  id_usuario INT AUTO_INCREMENT PRIMARY KEY,
  nombre_usuario VARCHAR(60) NOT NULL UNIQUE,
  nombre_completo VARCHAR(120) NOT NULL,
  rol ENUM('Gerencia', 'Administracion', 'Encargado') NOT NULL DEFAULT 'Encargado',
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 3. Tabla Llave (Restricción crítica: sin BLOB de imágenes; solo JSON vector_data)
CREATE TABLE IF NOT EXISTS llaves (
  codigo_interno VARCHAR(32) NOT NULL PRIMARY KEY COMMENT 'Formato [EDIFICIO]-[PISO/DEPTO/ZONA]-[CORRELATIVO]',
  id_edificio VARCHAR(10) NOT NULL,
  piso_depto VARCHAR(30) DEFAULT '',
  zona_comun VARCHAR(60) DEFAULT '',
  tipo_llave ENUM('sierra', 'tradicional', 'multipunto', 'borjas') NOT NULL DEFAULT 'sierra',
  vector_data JSON NOT NULL COMMENT 'Array ordenado de puntos [{"x": float, "y": float}] en milímetros',
  estado ENUM('disponible', 'entregada', 'perdida') NOT NULL DEFAULT 'disponible',
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_llave_edificio FOREIGN KEY (id_edificio)
    REFERENCES edificios(id_edificio) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 4. Tabla Movimiento / Préstamo (Ciclo de 30 días)
CREATE TABLE IF NOT EXISTS movimientos (
  id_movimiento INT AUTO_INCREMENT PRIMARY KEY,
  codigo_llave VARCHAR(32) NOT NULL,
  contacto_nombre VARCHAR(120) NOT NULL,
  contacto_telefono VARCHAR(40) NOT NULL,
  fecha_salida DATETIME NOT NULL,
  fecha_devolucion_prevista DATETIME NOT NULL COMMENT 'fecha_salida + 30 días',
  fecha_devolucion_real DATETIME NULL DEFAULT NULL,
  entregado_por VARCHAR(120) NOT NULL,
  CONSTRAINT fk_movimiento_llave FOREIGN KEY (codigo_llave)
    REFERENCES llaves(codigo_interno) ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_movimientos_activos (fecha_devolucion_real, fecha_devolucion_prevista)
) ENGINE=InnoDB;
