-- ============================================================================
-- MIGRACIÓN: Columnas de Sincronización Offline-First (Esquema Granular)
-- Archivo: migration_offline_sync.sql
-- Descripción:
--   - tbl_roles e id_rol han sido eliminados del sistema.
--   - tbl_usuarios ahora usa nombre_usuario UNIQUE NOT NULL y permisos_ventanas JSONB.
--   - Agrega uuid_sync, sincronizado y terminal_origen a todas las 7 tablas activas.
-- Ejecutar en: PostgreSQL Local Y Supabase (ambas bases de datos).
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- Eliminar tbl_roles si aún existe
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS tbl_roles CASCADE;

-- ----------------------------------------------------------------------------
-- 1. tbl_usuarios
-- ----------------------------------------------------------------------------
-- Asegurar que la columna id_rol no exista
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tbl_usuarios' AND column_name = 'id_rol'
  ) THEN
    ALTER TABLE tbl_usuarios DROP COLUMN id_rol CASCADE;
  END IF;
END $$;

-- Migrar correo_inst a nombre_usuario si aplica
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tbl_usuarios' AND column_name = 'correo_inst'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tbl_usuarios' AND column_name = 'nombre_usuario'
  ) THEN
    ALTER TABLE tbl_usuarios RENAME COLUMN correo_inst TO nombre_usuario;
  END IF;
END $$;

ALTER TABLE tbl_usuarios
  ADD COLUMN IF NOT EXISTS nombre_usuario VARCHAR(50),
  ADD COLUMN IF NOT EXISTS uuid_sync UUID DEFAULT gen_random_uuid() NOT NULL,
  ADD COLUMN IF NOT EXISTS sincronizado BOOLEAN DEFAULT FALSE NOT NULL,
  ADD COLUMN IF NOT EXISTS terminal_origen VARCHAR(50);

-- Si hay columna correo_inst remanente, eliminarla
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tbl_usuarios' AND column_name = 'correo_inst'
  ) THEN
    ALTER TABLE tbl_usuarios DROP COLUMN correo_inst;
  END IF;
END $$;

UPDATE tbl_usuarios SET uuid_sync = gen_random_uuid() WHERE uuid_sync IS NULL;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'uq_usuarios_uuid_sync'
  ) THEN
    ALTER TABLE tbl_usuarios ADD CONSTRAINT uq_usuarios_uuid_sync UNIQUE (uuid_sync);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'uq_usuarios_nombre_usuario'
  ) THEN
    ALTER TABLE tbl_usuarios ADD CONSTRAINT uq_usuarios_nombre_usuario UNIQUE (nombre_usuario);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_usuarios_sincronizado ON tbl_usuarios (sincronizado) WHERE sincronizado = FALSE;

-- ----------------------------------------------------------------------------
-- 2. tbl_categorias
-- ----------------------------------------------------------------------------
ALTER TABLE tbl_categorias
  ADD COLUMN IF NOT EXISTS uuid_sync UUID DEFAULT gen_random_uuid() NOT NULL,
  ADD COLUMN IF NOT EXISTS sincronizado BOOLEAN DEFAULT FALSE NOT NULL,
  ADD COLUMN IF NOT EXISTS terminal_origen VARCHAR(50);

UPDATE tbl_categorias SET uuid_sync = gen_random_uuid() WHERE uuid_sync IS NULL;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'uq_categorias_uuid_sync'
  ) THEN
    ALTER TABLE tbl_categorias ADD CONSTRAINT uq_categorias_uuid_sync UNIQUE (uuid_sync);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_categorias_sincronizado ON tbl_categorias (sincronizado) WHERE sincronizado = FALSE;

-- ----------------------------------------------------------------------------
-- 3. tbl_productos
-- ----------------------------------------------------------------------------
ALTER TABLE tbl_productos
  ADD COLUMN IF NOT EXISTS uuid_sync UUID DEFAULT gen_random_uuid() NOT NULL,
  ADD COLUMN IF NOT EXISTS sincronizado BOOLEAN DEFAULT FALSE NOT NULL,
  ADD COLUMN IF NOT EXISTS terminal_origen VARCHAR(50);

UPDATE tbl_productos SET uuid_sync = gen_random_uuid() WHERE uuid_sync IS NULL;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'uq_productos_uuid_sync'
  ) THEN
    ALTER TABLE tbl_productos ADD CONSTRAINT uq_productos_uuid_sync UNIQUE (uuid_sync);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_productos_sincronizado ON tbl_productos (sincronizado) WHERE sincronizado = FALSE;

-- ----------------------------------------------------------------------------
-- 4. tbl_clientes
-- ----------------------------------------------------------------------------
ALTER TABLE tbl_clientes
  ADD COLUMN IF NOT EXISTS uuid_sync UUID DEFAULT gen_random_uuid() NOT NULL,
  ADD COLUMN IF NOT EXISTS sincronizado BOOLEAN DEFAULT FALSE NOT NULL,
  ADD COLUMN IF NOT EXISTS terminal_origen VARCHAR(50);

UPDATE tbl_clientes SET uuid_sync = gen_random_uuid() WHERE uuid_sync IS NULL;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'uq_clientes_uuid_sync'
  ) THEN
    ALTER TABLE tbl_clientes ADD CONSTRAINT uq_clientes_uuid_sync UNIQUE (uuid_sync);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_clientes_sincronizado ON tbl_clientes (sincronizado) WHERE sincronizado = FALSE;

-- ----------------------------------------------------------------------------
-- 5. tbl_ventas
-- ----------------------------------------------------------------------------
ALTER TABLE tbl_ventas
  ADD COLUMN IF NOT EXISTS uuid_sync UUID DEFAULT gen_random_uuid() NOT NULL,
  ADD COLUMN IF NOT EXISTS sincronizado BOOLEAN DEFAULT FALSE NOT NULL,
  ADD COLUMN IF NOT EXISTS terminal_origen VARCHAR(50);

UPDATE tbl_ventas SET uuid_sync = gen_random_uuid() WHERE uuid_sync IS NULL;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'uq_ventas_uuid_sync'
  ) THEN
    ALTER TABLE tbl_ventas ADD CONSTRAINT uq_ventas_uuid_sync UNIQUE (uuid_sync);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ventas_sincronizado ON tbl_ventas (sincronizado) WHERE sincronizado = FALSE;

-- ----------------------------------------------------------------------------
-- 6. tbl_ventas_detalle
-- ----------------------------------------------------------------------------
ALTER TABLE tbl_ventas_detalle
  ADD COLUMN IF NOT EXISTS uuid_sync UUID DEFAULT gen_random_uuid() NOT NULL,
  ADD COLUMN IF NOT EXISTS sincronizado BOOLEAN DEFAULT FALSE NOT NULL,
  ADD COLUMN IF NOT EXISTS terminal_origen VARCHAR(50);

UPDATE tbl_ventas_detalle SET uuid_sync = gen_random_uuid() WHERE uuid_sync IS NULL;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'uq_ventas_detalle_uuid_sync'
  ) THEN
    ALTER TABLE tbl_ventas_detalle ADD CONSTRAINT uq_ventas_detalle_uuid_sync UNIQUE (uuid_sync);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ventas_detalle_sincronizado ON tbl_ventas_detalle (sincronizado) WHERE sincronizado = FALSE;

-- ----------------------------------------------------------------------------
-- 7. tbl_inventarios
-- ----------------------------------------------------------------------------
ALTER TABLE tbl_inventarios
  ADD COLUMN IF NOT EXISTS uuid_sync UUID DEFAULT gen_random_uuid() NOT NULL,
  ADD COLUMN IF NOT EXISTS sincronizado BOOLEAN DEFAULT FALSE NOT NULL,
  ADD COLUMN IF NOT EXISTS terminal_origen VARCHAR(50);

UPDATE tbl_inventarios SET uuid_sync = gen_random_uuid() WHERE uuid_sync IS NULL;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'uq_inventarios_uuid_sync'
  ) THEN
    ALTER TABLE tbl_inventarios ADD CONSTRAINT uq_inventarios_uuid_sync UNIQUE (uuid_sync);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_inventarios_sincronizado ON tbl_inventarios (sincronizado) WHERE sincronizado = FALSE;
