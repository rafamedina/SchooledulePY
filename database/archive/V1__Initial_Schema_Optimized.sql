-- ==================================================================
-- ESQUEMA INICIAL SCHOOLEDULE - VERSIÓN OPTIMIZADA (POSTGRES 14+)
-- ==================================================================
-- Basado en el esquema original con mejoras de seguridad, integridad y rendimiento.

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- ==================================================================
-- 1. DOMINIOS Y ENUMERACIONES
-- ==================================================================

CREATE TYPE estado_matricula AS ENUM ('ACTIVA', 'BAJA', 'CONVALIDADO');
CREATE TYPE tipo_actividad AS ENUM ('EXAMEN', 'PRACTICA', 'RECUPERACION', 'ACTITUD');

-- ==================================================================
-- 2. GESTIÓN DE IDENTIDAD Y CONTROL DE ACCESO (IAM)
-- ==================================================================

-- Catálogo de roles del sistema.
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

-- Entidad de usuario centralizada.
CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    -- password_hash aumentado a 512 para soportar algoritmos modernos (Argon2id/SHA-512).
    password_hash VARCHAR(512) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    -- Validación de formato de email mediante Regex.
    email VARCHAR(150) UNIQUE CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    activo BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Relación N:M para roles de usuario.
CREATE TABLE usuarios_roles (
    usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    rol_id INT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (usuario_id, rol_id)
);

-- Índices para optimizar la verificación de permisos.
CREATE INDEX idx_usuarios_roles_usuario ON usuarios_roles(usuario_id);
CREATE INDEX idx_usuarios_roles_rol ON usuarios_roles(rol_id);

-- ==================================================================
-- 3. ESTRUCTURA ACADÉMICA Y ORGANIZATIVA
-- ==================================================================

CREATE TABLE centros (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ubicacion VARCHAR(200),
    -- JSONB por defecto vacío para evitar nulos.
    configuracion JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE cursos_academicos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    centro_id INT NOT NULL REFERENCES centros(id) ON DELETE CASCADE,
    activo BOOLEAN DEFAULT FALSE,
    -- Restricción de consistencia temporal.
    CONSTRAINT check_fechas CHECK (fecha_fin > fecha_inicio)
);

CREATE TABLE profesores_sedes (
    usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    centro_id INT NOT NULL REFERENCES centros(id) ON DELETE CASCADE,
    PRIMARY KEY (usuario_id, centro_id)
);

-- ==================================================================
-- 4. GESTIÓN CURRICULAR
-- ==================================================================

CREATE TABLE modulos (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    nombre VARCHAR(150) NOT NULL
);

CREATE TABLE resultados_aprendizaje (
    id SERIAL PRIMARY KEY,
    modulo_id INT NOT NULL REFERENCES modulos(id) ON DELETE CASCADE,
    curso_academico_id INT NOT NULL REFERENCES cursos_academicos(id) ON DELETE CASCADE,
    codigo VARCHAR(20) NOT NULL,
    descripcion TEXT NOT NULL,
    peso_sugerido DECIMAL(5,2) DEFAULT 0.00
);

CREATE TABLE criterios_evaluacion (
    id SERIAL PRIMARY KEY,
    resultado_aprendizaje_id INT NOT NULL REFERENCES resultados_aprendizaje(id) ON DELETE CASCADE,
    codigo VARCHAR(20) NOT NULL,
    descripcion TEXT NOT NULL
);

-- ==================================================================
-- 5. PLANIFICACIÓN Y EJECUCIÓN ACADÉMICA
-- ==================================================================

CREATE TABLE grupos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    centro_id INT NOT NULL REFERENCES centros(id) ON DELETE CASCADE,
    curso_academico_id INT NOT NULL REFERENCES cursos_academicos(id) ON DELETE CASCADE
);

CREATE TABLE imparticiones (
    id SERIAL PRIMARY KEY,
    modulo_id INT NOT NULL REFERENCES modulos(id) ON DELETE RESTRICT,
    grupo_id INT NOT NULL REFERENCES grupos(id) ON DELETE CASCADE,
    profesor_id INT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    centro_id INT NOT NULL REFERENCES centros(id) ON DELETE CASCADE,
    configuracion_evaluacion JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE matriculas (
    id SERIAL PRIMARY KEY,
    alumno_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    imparticion_id INT NOT NULL REFERENCES imparticiones(id) ON DELETE CASCADE,
    centro_id INT NOT NULL REFERENCES centros(id) ON DELETE CASCADE,
    es_repetidor BOOLEAN DEFAULT FALSE,
    estado estado_matricula DEFAULT 'ACTIVA',
    UNIQUE(alumno_id, imparticion_id)
);

-- ==================================================================
-- 6. EVALUACIÓN Y SEGUIMIENTO
-- ==================================================================

CREATE TABLE periodos_evaluacion (
    id SERIAL PRIMARY KEY,
    imparticion_id INT NOT NULL REFERENCES imparticiones(id) ON DELETE CASCADE,
    nombre VARCHAR(50) NOT NULL,
    peso DECIMAL(5,2) DEFAULT 0.00,
    cerrado BOOLEAN DEFAULT FALSE
);

CREATE TABLE items_evaluables (
    id SERIAL PRIMARY KEY,
    imparticion_id INT NOT NULL REFERENCES imparticiones(id) ON DELETE CASCADE,
    periodo_evaluacion_id INT NOT NULL REFERENCES periodos_evaluacion(id) ON DELETE CASCADE,
    nombre VARCHAR(100) NOT NULL,
    fecha DATE,
    tipo tipo_actividad NOT NULL,
    configuracion_rubrica JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE calificaciones (
    id SERIAL PRIMARY KEY,
    matricula_id INT NOT NULL REFERENCES matriculas(id) ON DELETE CASCADE,
    item_evaluable_id INT NOT NULL REFERENCES items_evaluables(id) ON DELETE CASCADE,
    valor DECIMAL(5,2) DEFAULT 0.00,
    comentario TEXT,
    fecha_modificacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(matricula_id, item_evaluable_id)
);

-- ==================================================================
-- 7. AUDITORÍA INTEGRAL
-- ==================================================================

CREATE TABLE auditoria_log (
    id SERIAL PRIMARY KEY,
    tabla_afectada VARCHAR(50) NOT NULL,
    operacion VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    usuario_responsable VARCHAR(100),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION fn_registrar_auditoria()
RETURNS TRIGGER AS $$
DECLARE
    app_user TEXT;
BEGIN
    -- Captura del usuario desde la sesión o el sistema.
    BEGIN
        app_user := current_setting('app.current_user', true);
    EXCEPTION WHEN OTHERS THEN
        app_user := current_user;
    END;

    IF app_user IS NULL OR app_user = '' THEN
        app_user := 'DB_SYSTEM';
    END IF;

    IF (TG_OP = 'DELETE') THEN
        INSERT INTO auditoria_log(tabla_afectada, operacion, usuario_responsable, datos_anteriores)
        VALUES (TG_RELNAME, TG_OP, app_user, to_jsonb(OLD));
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO auditoria_log(tabla_afectada, operacion, usuario_responsable, datos_anteriores, datos_nuevos)
        VALUES (TG_RELNAME, TG_OP, app_user, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO auditoria_log(tabla_afectada, operacion, usuario_responsable, datos_nuevos)
        VALUES (TG_RELNAME, TG_OP, app_user, to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Activación de auditoría en tablas críticas.
CREATE TRIGGER tr_auditoria_usuarios AFTER INSERT OR UPDATE OR DELETE ON usuarios FOR EACH ROW EXECUTE FUNCTION fn_registrar_auditoria();
CREATE TRIGGER tr_auditoria_calificaciones AFTER INSERT OR UPDATE OR DELETE ON calificaciones FOR EACH ROW EXECUTE FUNCTION fn_registrar_auditoria();

-- ==================================================================
-- 8. DATOS SEMILLA (CONSISTENCIA DE ROLES)
-- ==================================================================

INSERT INTO roles (id, nombre) VALUES
(1, 'ROLE_ADMIN'),
(2, 'ROLE_PROFESOR'),
(3, 'ROLE_ALUMNO');

INSERT INTO centros (id, nombre, ubicacion) VALUES
(1, 'IES Central', 'Madrid');

-- Contraseña por defecto: 1234
INSERT INTO usuarios (id, username, password_hash, nombre, apellidos, email, activo) VALUES
(1, 'admin', '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Super', 'Admin', 'admin@tfg.com', true),
(2, 'profe1', '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Juan', 'Garcia', 'juan@tfg.com', true),
(3, 'alumno1', '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Ana', 'Lopez', 'ana@tfg.com', true),
(4, 'profe_alumno', '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Pedro', 'Mix', 'pedro@tfg.com', true);

INSERT INTO usuarios_roles (usuario_id, rol_id) VALUES
(1, 1), (2, 2), (3, 3), (4, 2), (4, 3);

SELECT setval('roles_id_seq', (SELECT MAX(id) FROM roles));
SELECT setval('usuarios_id_seq', (SELECT MAX(id) FROM usuarios));
SELECT setval('centros_id_seq', (SELECT MAX(id) FROM centros));
