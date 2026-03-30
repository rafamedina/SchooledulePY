-- ==================================================================
-- BASE DE DATOS TFG - VERSIÓN FINAL (ROLES N:M + AUDITORÍA PRO)
-- ==================================================================
-- Reinicio del esquema para asegurar un despliegue limpio.
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- ENUMS (Solo para estados, ya NO para roles)
-- Define el dominio de estados permitidos para la matrícula de un alumno.
CREATE TYPE estado_matricula AS ENUM ('ACTIVA', 'BAJA', 'CONVALIDADO');
-- Define las categorías de actividades evaluables en el currículo.
CREATE TYPE tipo_actividad AS ENUM ('EXAMEN', 'PRACTICA', 'RECUPERACION', 'ACTITUD');

-- ==================================================================
-- 1. GESTIÓN DE IDENTIDAD Y ROLES (MODIFICADO)
-- ==================================================================

-- 1.1 Tabla de Roles (Catálogo)
-- Almacena los perfiles de acceso disponibles en el sistema.
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE -- Ejemplos: 'ADMIN', 'PROFESOR', 'ALUMNO'
);

-- 1.2 Usuarios (Sin columna de rol directa)
-- Entidad central que representa a cualquier persona con acceso al sistema.
CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE, -- Identificador para el inicio de sesión.
    password_hash VARCHAR(255) NOT NULL, -- Almacenamiento seguro de credenciales.
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE,
    activo BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 1.3 Tabla Intermedia (Muchos a Muchos: Usuarios <-> Roles)
-- Permite que un usuario posea múltiples roles de forma simultánea.
CREATE TABLE usuarios_roles (
    usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    rol_id INT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (usuario_id, rol_id)
);

-- ==================================================================
-- 2. ESTRUCTURA ORGANIZATIVA
-- ==================================================================

-- Representa el centro educativo físico (Sede).
CREATE TABLE centros (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ubicacion VARCHAR(200),
    configuracion JSONB -- Almacena parámetros variables en formato flexible.
);

-- Define los periodos lectivos (ej. 2025-2026).
CREATE TABLE cursos_academicos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(20) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    activo BOOLEAN DEFAULT FALSE
);

-- Relación Profesor <-> Sede (Contexto de trabajo)
-- Vincula a los docentes con los centros donde imparten clase.
CREATE TABLE profesores_sedes (
    usuario_id INT NOT NULL REFERENCES usuarios(id),
    centro_id INT NOT NULL REFERENCES centros(id),
    PRIMARY KEY (usuario_id, centro_id)
);

-- ==================================================================
-- 3. CURRÍCULO
-- ==================================================================

-- Representa las asignaturas o módulos profesionales.
CREATE TABLE modulos (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) NOT NULL,
    nombre VARCHAR(150) NOT NULL
);

-- Define los objetivos de aprendizaje de cada módulo.
CREATE TABLE resultados_aprendizaje (
    id SERIAL PRIMARY KEY,
    modulo_id INT NOT NULL REFERENCES modulos(id),
    curso_academico_id INT NOT NULL REFERENCES cursos_academicos(id),
    codigo VARCHAR(20) NOT NULL,
    descripcion TEXT NOT NULL,
    peso_sugerido DECIMAL(5,2)
);

-- Desglose detallado de los resultados de aprendizaje.
CREATE TABLE criterios_evaluacion (
    id SERIAL PRIMARY KEY,
    resultado_aprendizaje_id INT NOT NULL REFERENCES resultados_aprendizaje(id),
    codigo VARCHAR(20) NOT NULL,
    descripcion TEXT NOT NULL
);

-- ==================================================================
-- 4. EJECUCIÓN (CON CORTAFUEGOS DE SEGURIDAD)
-- ==================================================================

-- Representa el conjunto de alumnos (aula/clase).
CREATE TABLE grupos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    centro_id INT NOT NULL REFERENCES centros(id),
    curso_academico_id INT NOT NULL REFERENCES cursos_academicos(id)
);

-- Vinculación de profesor, módulo y grupo en un centro específico.
CREATE TABLE imparticiones (
    id SERIAL PRIMARY KEY,
    modulo_id INT NOT NULL REFERENCES modulos(id),
    grupo_id INT NOT NULL REFERENCES grupos(id),
    profesor_id INT NOT NULL REFERENCES usuarios(id),
    -- CORTAFUEGOS: Redundancia para seguridad por filas (RLS).
    centro_id INT NOT NULL REFERENCES centros(id),
    -- Configuración de evaluación (Pesos, Teoría/Práctica).
    configuracion_evaluacion JSONB
);

-- Inscripción formal de un alumno en una impartición concreta.
CREATE TABLE matriculas (
    id SERIAL PRIMARY KEY,
    alumno_id INT NOT NULL REFERENCES usuarios(id),
    imparticion_id INT NOT NULL REFERENCES imparticiones(id),
    -- CORTAFUEGOS: Validación de sede.
    centro_id INT NOT NULL REFERENCES centros(id),
    es_repetidor BOOLEAN DEFAULT FALSE,
    estado estado_matricula DEFAULT 'ACTIVA',
    UNIQUE(alumno_id, imparticion_id)
);

-- ==================================================================
-- 5. EVALUACIÓN Y CALIFICACIONES
-- ==================================================================

-- Define los hitos temporales de evaluación (ej. 1ª Evaluación).
CREATE TABLE periodos_evaluacion (
    id SERIAL PRIMARY KEY,
    imparticion_id INT NOT NULL REFERENCES imparticiones(id),
    nombre VARCHAR(50) NOT NULL,
    peso DECIMAL(5,2),
    cerrado BOOLEAN DEFAULT FALSE
);

-- Representa una tarea, examen o actividad concreta.
CREATE TABLE items_evaluables (
    id SERIAL PRIMARY KEY,
    imparticion_id INT NOT NULL REFERENCES imparticiones(id),
    periodo_evaluacion_id INT NOT NULL REFERENCES periodos_evaluacion(id),
    nombre VARCHAR(100) NOT NULL,
    fecha DATE,
    tipo tipo_actividad NOT NULL, -- EXAMEN, RECUPERACION...
    configuracion_rubrica JSONB
);

-- Registro de la nota obtenida por un alumno en un item evaluable.
CREATE TABLE calificaciones (
    id SERIAL PRIMARY KEY,
    matricula_id INT NOT NULL REFERENCES matriculas(id),
    item_evaluable_id INT NOT NULL REFERENCES items_evaluables(id),
    valor DECIMAL(5,2),
    comentario TEXT,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(matricula_id, item_evaluable_id)
);

-- ==================================================================
-- 6. AUDITORÍA FORENSE (TRIGGER)
-- ==================================================================

-- Histórico de cambios en las calificaciones para trazabilidad y seguridad.
CREATE TABLE auditoria_notas (
    id SERIAL PRIMARY KEY,
    calificacion_id INT NOT NULL REFERENCES calificaciones(id),
    valor_anterior DECIMAL(5,2),
    valor_nuevo DECIMAL(5,2),
    usuario_responsable VARCHAR(100),
    fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    motivo VARCHAR(255)
);

-- Función encargada de registrar los cambios de notas en la tabla de auditoría.
CREATE OR REPLACE FUNCTION registrar_cambio_nota()
RETURNS TRIGGER AS $$
DECLARE
    app_user TEXT;
BEGIN
    -- Intentamos leer la variable de sesión inyectada por la aplicación.
    BEGIN
        app_user := current_setting('app.current_user', true);
    EXCEPTION WHEN OTHERS THEN
        app_user := current_user;
    END;

    IF app_user IS NULL OR app_user = '' THEN
        app_user := 'SYSTEM_DB';
    END IF;

    -- Solo registra si el valor de la nota ha cambiado realmente.
    IF (TG_OP = 'UPDATE' AND OLD.valor <> NEW.valor) THEN
        INSERT INTO auditoria_notas (calificacion_id, valor_anterior, valor_nuevo, usuario_responsable, motivo)
        VALUES (NEW.id, OLD.valor, NEW.valor, app_user, 'Modificación registrada');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger que se dispara tras cada actualización en la tabla de calificaciones.
CREATE TRIGGER trigger_auditoria_notas
    AFTER UPDATE ON calificaciones
    FOR EACH ROW
    EXECUTE FUNCTION registrar_cambio_nota();

-- ==================================================================
-- 7. DATOS INICIALES (SIN ACENTOS PARA EVITAR PROBLEMAS DE ENCODING)
-- ==================================================================

-- 1. Roles
INSERT INTO roles (id, nombre) VALUES (1, 'ADMIN'), (2, 'PROFESOR'), (3, 'ALUMNO');
-- 2. Centros
INSERT INTO centros (id, nombre, ubicacion) VALUES (1, 'IES Central', 'Madrid');

-- 3. Usuarios (Contraseña: 1234 para todos)
INSERT INTO usuarios (id, username, password_hash, nombre, apellidos, email, activo) VALUES
(1, 'admin', '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Super', 'Admin', 'admin@tfg.com', true),
(2, 'profe1', '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Juan', 'Garcia', 'juan@tfg.com', true),
(3, 'alumno1', '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Ana', 'Lopez', 'ana@tfg.com', true),
(4, 'profe_alumno', '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Pedro', 'Mix', 'pedro@tfg.com', true);

-- 4. Asignación de Roles
INSERT INTO usuarios_roles (usuario_id, rol_id) VALUES
(1, 1), (2, 2), (3, 3), (4, 2), (4, 3);

-- Sincronización de secuencias tras inserción manual de IDs.
SELECT setval('roles_id_seq', (SELECT MAX(id) FROM roles));
SELECT setval('usuarios_id_seq', (SELECT MAX(id) FROM usuarios));
SELECT setval('centros_id_seq', (SELECT MAX(id) FROM centros));

-- Tablas de soporte para Spring Session (Persistencia de sesiones en DB).
CREATE TABLE SPRING_SESSION (
    PRIMARY_ID CHAR(36) NOT NULL,
    SESSION_ID CHAR(36) NOT NULL,
    CREATION_TIME BIGINT NOT NULL,
    LAST_ACCESS_TIME BIGINT NOT NULL,
    MAX_INACTIVE_INTERVAL INT NOT NULL,
    EXPIRY_TIME BIGINT NOT NULL,
    PRINCIPAL_NAME VARCHAR(100),
    CONSTRAINT SPRING_SESSION_PK PRIMARY KEY (PRIMARY_ID)
);

CREATE UNIQUE INDEX SPRING_SESSION_IX1 ON SPRING_SESSION (SESSION_ID);
CREATE INDEX SPRING_SESSION_IX2 ON SPRING_SESSION (EXPIRY_TIME);
CREATE INDEX SPRING_SESSION_IX3 ON SPRING_SESSION (PRINCIPAL_NAME);

CREATE TABLE SPRING_SESSION_ATTRIBUTES (
    SESSION_PRIMARY_ID CHAR(36) NOT NULL,
    ATTRIBUTE_NAME VARCHAR(200) NOT NULL,
    ATTRIBUTE_BYTES BYTEA NOT NULL,
    CONSTRAINT SPRING_SESSION_ATTRIBUTES_PK PRIMARY KEY (SESSION_PRIMARY_ID, ATTRIBUTE_NAME),
    CONSTRAINT SPRING_SESSION_ATTRIBUTES_FK FOREIGN KEY (SESSION_PRIMARY_ID) REFERENCES SPRING_SESSION(PRIMARY_ID) ON DELETE CASCADE
);

-- Actualizaciones de consistencia de nombres de roles.
UPDATE roles SET nombre = 'ROLE_PROFESOR' WHERE nombre = 'ROFESOR' OR nombre = 'PROFESOR';
UPDATE roles SET nombre = 'ROLE_ADMIN' WHERE nombre = 'ADMIN';
UPDATE roles SET nombre = 'ROLE_ALUMNO' WHERE nombre = 'ALUMNO';

-- Asegurar contraseñas y estado de usuarios por defecto.
UPDATE usuarios SET password_hash = '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi'
WHERE email IN ('admin@tfg.com', 'juan@tfg.com', 'ana@tfg.com', 'pedro@tfg.com');

UPDATE usuarios SET activo = true
WHERE email IN ('admin@tfg.com', 'juan@tfg.com', 'ana@tfg.com', 'pedro@tfg.com');
