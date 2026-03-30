-- ==================================================================
-- SCHOOLEDULE - ESQUEMA DEFINITIVO v4 (DJANGO + OPTIMIZACIONES)
-- ==================================================================
-- Fusión del esquema compatible con Django y las mejoras de ingeniería
-- del esquema optimizado. Ejecutado por PostgreSQL en docker-entrypoint-initdb.d
-- exclusivamente durante la primera creación del volumen de datos.
--
-- Características:
--   - Columnas requeridas por Django (AbstractBaseUser, PermissionsMixin)
--   - Tablas internas de Django para compatibilidad con 'migrate --fake'
--   - CHECK constraints para integridad de datos
--   - Índices en claves foráneas y tablas M2M para rendimiento
--   - Auditoría genérica (cualquier tabla, no solo calificaciones)
--   - JSONB con DEFAULT '{}' para evitar nulos
--   - TIMESTAMP WITH TIME ZONE en todas las columnas temporales
--   - ON DELETE CASCADE/RESTRICT consistente en todas las FKs
--   - Validación de email mediante regex a nivel de base de datos
-- ==================================================================

-- Reinicio del esquema para asegurar un despliegue limpio.
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- ==================================================================
-- 1. DOMINIOS Y ENUMERACIONES
-- ==================================================================

-- Define el dominio de estados permitidos para la matrícula de un alumno.
CREATE TYPE estado_matricula AS ENUM ('ACTIVA', 'BAJA', 'CONVALIDADO');
-- Define las categorías de actividades evaluables en el currículo.
CREATE TYPE tipo_actividad AS ENUM ('EXAMEN', 'PRACTICA', 'RECUPERACION', 'ACTITUD');

-- ==================================================================
-- 2. GESTIÓN DE IDENTIDAD Y CONTROL DE ACCESO (IAM)
-- ==================================================================

-- 2.1 Catálogo de roles del sistema.
-- Almacena los perfiles de acceso disponibles (ROLE_ADMIN, ROLE_PROFESOR, ROLE_ALUMNO).
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

-- 2.2 Entidad de usuario centralizada.
-- El esquema incluye las columnas requeridas por Django (AbstractBaseUser + PermissionsMixin):
--   - password_hash: mapeado desde el campo 'password' de Django via db_column.
--   - last_login: campo de AbstractBaseUser para rastrear el último inicio de sesión.
--   - is_superuser: campo de PermissionsMixin para privilegios globales.
--   - is_staff: campo de Django para acceso al panel de administración.
--   - is_active: campo de Django para indicar si la cuenta está habilitada.
CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    -- Longitud 512 para soportar algoritmos modernos (Argon2id, BCrypt+SHA256).
    password_hash VARCHAR(512) NOT NULL,
    -- Campos requeridos por Django AbstractBaseUser y PermissionsMixin.
    last_login TIMESTAMP WITH TIME ZONE NULL,
    is_superuser BOOLEAN NOT NULL DEFAULT FALSE,
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    -- Validación de formato de email mediante regex a nivel de base de datos.
    email VARCHAR(150) UNIQUE CHECK (
        email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    ),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_staff BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- 2.3 Relación N:M para roles de usuario.
-- Incluye 'id SERIAL' para compatibilidad con el modelo Django UserRole (BigAutoField PK).
CREATE TABLE usuarios_roles (
    id SERIAL PRIMARY KEY,
    usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    rol_id INT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    UNIQUE (usuario_id, rol_id)
);

-- Índices para optimizar la verificación de permisos en consultas de autorización.
CREATE INDEX idx_usuarios_roles_usuario ON usuarios_roles(usuario_id);
CREATE INDEX idx_usuarios_roles_rol ON usuarios_roles(rol_id);

-- ==================================================================
-- 3. TABLAS INTERNAS DE DJANGO
-- ==================================================================
-- Django requiere estas tablas para su sistema de permisos, sesiones y
-- registro de migraciones. Se crean aquí con el esquema exacto que Django
-- espera para que 'migrate --fake' registre las migraciones sin ejecutar DDL.

-- Tabla de tipos de contenido (django.contrib.contenttypes).
-- Django la puebla automáticamente mediante la señal post_migrate.
CREATE TABLE django_content_type (
    id SERIAL PRIMARY KEY,
    app_label VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    UNIQUE (app_label, model)
);

-- Tabla de permisos (django.contrib.auth).
-- Django la puebla automáticamente mediante la señal post_migrate.
CREATE TABLE auth_permission (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    content_type_id INT NOT NULL REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED,
    codename VARCHAR(100) NOT NULL,
    UNIQUE (content_type_id, codename)
);

-- Tabla de grupos (django.contrib.auth).
CREATE TABLE auth_group (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL UNIQUE
);

-- Tabla intermedia grupo-permiso (django.contrib.auth).
CREATE TABLE auth_group_permissions (
    id SERIAL PRIMARY KEY,
    group_id INT NOT NULL REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED,
    permission_id INT NOT NULL REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED,
    UNIQUE (group_id, permission_id)
);

-- Tabla intermedia usuario-grupo (Django auth).
-- Django nombra esta tabla como {db_table}_{field_name} = usuarios_groups.
CREATE TABLE usuarios_groups (
    id SERIAL PRIMARY KEY,
    customuser_id BIGINT NOT NULL REFERENCES usuarios(id) DEFERRABLE INITIALLY DEFERRED,
    group_id INT NOT NULL REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED,
    UNIQUE (customuser_id, group_id)
);

-- Tabla intermedia usuario-permiso (Django auth).
-- Django nombra esta tabla como {db_table}_{field_name} = usuarios_user_permissions.
CREATE TABLE usuarios_user_permissions (
    id SERIAL PRIMARY KEY,
    customuser_id BIGINT NOT NULL REFERENCES usuarios(id) DEFERRABLE INITIALLY DEFERRED,
    permission_id INT NOT NULL REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED,
    UNIQUE (customuser_id, permission_id)
);

-- Tabla de registro de migraciones de Django.
CREATE TABLE django_migrations (
    id SERIAL PRIMARY KEY,
    app VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    applied TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Tabla de sesiones de Django.
CREATE TABLE django_session (
    session_key VARCHAR(40) PRIMARY KEY,
    session_data TEXT NOT NULL,
    expire_date TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX django_session_expire_date_idx ON django_session (expire_date);

-- Tabla de log del panel de administración de Django.
CREATE TABLE django_admin_log (
    id SERIAL PRIMARY KEY,
    action_time TIMESTAMP WITH TIME ZONE NOT NULL,
    object_id TEXT NULL,
    object_repr VARCHAR(200) NOT NULL,
    action_flag SMALLINT NOT NULL CHECK (action_flag >= 0),
    change_message TEXT NOT NULL,
    content_type_id INT NULL REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED,
    user_id BIGINT NOT NULL REFERENCES usuarios(id) DEFERRABLE INITIALLY DEFERRED
);

-- ==================================================================
-- 4. ESTRUCTURA ACADÉMICA Y ORGANIZATIVA
-- ==================================================================

-- Representa el centro educativo físico (Sede).
CREATE TABLE centros (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ubicacion VARCHAR(200),
    -- JSONB por defecto vacío para evitar nulos en consultas.
    configuracion JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- Define los periodos lectivos (ej. 2025-2026).
CREATE TABLE cursos_academicos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    centro_id INT NOT NULL REFERENCES centros(id) ON DELETE CASCADE,
    activo BOOLEAN NOT NULL DEFAULT FALSE,
    -- Restricción de consistencia temporal: el fin debe ser posterior al inicio.
    CONSTRAINT chk_cursos_fechas CHECK (fecha_fin > fecha_inicio)
);

-- Índice para búsquedas frecuentes de cursos por centro.
CREATE INDEX idx_cursos_academicos_centro ON cursos_academicos(centro_id);

-- Relación Profesor <-> Sede (Contexto de trabajo multi-campus).
-- Columnas 'customuser_id' y 'centro_id' coinciden con las que Django genera
-- para el ManyToManyField(db_table="profesores_sedes").
CREATE TABLE profesores_sedes (
    id SERIAL PRIMARY KEY,
    customuser_id BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    centro_id INT NOT NULL REFERENCES centros(id) ON DELETE CASCADE,
    UNIQUE (customuser_id, centro_id)
);

-- ==================================================================
-- 5. GESTIÓN CURRICULAR
-- ==================================================================

-- Representa las asignaturas o módulos profesionales.
CREATE TABLE modulos (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    nombre VARCHAR(150) NOT NULL
);

-- Define los objetivos de aprendizaje de cada módulo.
CREATE TABLE resultados_aprendizaje (
    id SERIAL PRIMARY KEY,
    modulo_id INT NOT NULL REFERENCES modulos(id) ON DELETE CASCADE,
    curso_academico_id INT NOT NULL REFERENCES cursos_academicos(id) ON DELETE CASCADE,
    codigo VARCHAR(20) NOT NULL,
    descripcion TEXT NOT NULL,
    peso_sugerido DECIMAL(5,2) NOT NULL DEFAULT 0.00
);

-- Índices para las FKs de resultados_aprendizaje (joins frecuentes).
CREATE INDEX idx_ra_modulo ON resultados_aprendizaje(modulo_id);
CREATE INDEX idx_ra_curso ON resultados_aprendizaje(curso_academico_id);

-- Desglose detallado de los resultados de aprendizaje (criterios de evaluación).
CREATE TABLE criterios_evaluacion (
    id SERIAL PRIMARY KEY,
    resultado_aprendizaje_id INT NOT NULL REFERENCES resultados_aprendizaje(id) ON DELETE CASCADE,
    codigo VARCHAR(20) NOT NULL,
    descripcion TEXT NOT NULL
);

CREATE INDEX idx_ce_resultado ON criterios_evaluacion(resultado_aprendizaje_id);

-- ==================================================================
-- 6. PLANIFICACIÓN Y EJECUCIÓN ACADÉMICA
-- ==================================================================

-- Representa el conjunto de alumnos (aula/clase).
CREATE TABLE grupos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    centro_id INT NOT NULL REFERENCES centros(id) ON DELETE CASCADE,
    curso_academico_id INT NOT NULL REFERENCES cursos_academicos(id) ON DELETE CASCADE
);

-- Índices para filtrado por centro (multi-tenancy) y curso.
CREATE INDEX idx_grupos_centro ON grupos(centro_id);
CREATE INDEX idx_grupos_curso ON grupos(curso_academico_id);

-- Vinculación de profesor, módulo y grupo en un centro específico.
CREATE TABLE imparticiones (
    id SERIAL PRIMARY KEY,
    modulo_id INT NOT NULL REFERENCES modulos(id) ON DELETE RESTRICT,
    grupo_id INT NOT NULL REFERENCES grupos(id) ON DELETE CASCADE,
    -- RESTRICT: no se puede borrar un profesor con imparticiones activas.
    profesor_id INT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    -- CORTAFUEGOS: Redundancia de centro para seguridad por filas (RLS).
    centro_id INT NOT NULL REFERENCES centros(id) ON DELETE CASCADE,
    -- Configuración de evaluación flexible (pesos, teoría/práctica).
    configuracion_evaluacion JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- Índices para las consultas más frecuentes en imparticiones.
CREATE INDEX idx_imparticiones_profesor ON imparticiones(profesor_id);
CREATE INDEX idx_imparticiones_grupo ON imparticiones(grupo_id);
CREATE INDEX idx_imparticiones_centro ON imparticiones(centro_id);

-- Inscripción formal de un alumno en una impartición concreta.
CREATE TABLE matriculas (
    id SERIAL PRIMARY KEY,
    alumno_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    imparticion_id INT NOT NULL REFERENCES imparticiones(id) ON DELETE CASCADE,
    -- CORTAFUEGOS: Validación de sede.
    centro_id INT NOT NULL REFERENCES centros(id) ON DELETE CASCADE,
    es_repetidor BOOLEAN NOT NULL DEFAULT FALSE,
    estado estado_matricula NOT NULL DEFAULT 'ACTIVA',
    UNIQUE(alumno_id, imparticion_id)
);

CREATE INDEX idx_matriculas_alumno ON matriculas(alumno_id);
CREATE INDEX idx_matriculas_imparticion ON matriculas(imparticion_id);
CREATE INDEX idx_matriculas_centro ON matriculas(centro_id);

-- ==================================================================
-- 7. EVALUACIÓN Y CALIFICACIONES
-- ==================================================================

-- Define los hitos temporales de evaluación (ej. 1ª Evaluación).
CREATE TABLE periodos_evaluacion (
    id SERIAL PRIMARY KEY,
    imparticion_id INT NOT NULL REFERENCES imparticiones(id) ON DELETE CASCADE,
    nombre VARCHAR(50) NOT NULL,
    peso DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    cerrado BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_periodos_imparticion ON periodos_evaluacion(imparticion_id);

-- Representa una tarea, examen o actividad concreta.
CREATE TABLE items_evaluables (
    id SERIAL PRIMARY KEY,
    imparticion_id INT NOT NULL REFERENCES imparticiones(id) ON DELETE CASCADE,
    periodo_evaluacion_id INT NOT NULL REFERENCES periodos_evaluacion(id) ON DELETE CASCADE,
    nombre VARCHAR(100) NOT NULL,
    fecha DATE,
    tipo tipo_actividad NOT NULL,
    -- Configuración de la rúbrica flexible en formato JSON.
    configuracion_rubrica JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX idx_items_imparticion ON items_evaluables(imparticion_id);
CREATE INDEX idx_items_periodo ON items_evaluables(periodo_evaluacion_id);

-- Registro de la nota obtenida por un alumno en un item evaluable.
CREATE TABLE calificaciones (
    id SERIAL PRIMARY KEY,
    matricula_id INT NOT NULL REFERENCES matriculas(id) ON DELETE CASCADE,
    item_evaluable_id INT NOT NULL REFERENCES items_evaluables(id) ON DELETE CASCADE,
    valor DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    comentario TEXT,
    fecha_modificacion TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(matricula_id, item_evaluable_id)
);

CREATE INDEX idx_calificaciones_matricula ON calificaciones(matricula_id);
CREATE INDEX idx_calificaciones_item ON calificaciones(item_evaluable_id);

-- ==================================================================
-- 8. AUDITORÍA INTEGRAL
-- ==================================================================
-- Sistema de auditoría genérico que registra INSERT, UPDATE y DELETE
-- en cualquier tabla donde se active el trigger correspondiente.
-- Almacena los datos anteriores y nuevos como JSONB para trazabilidad completa.

CREATE TABLE auditoria_log (
    id SERIAL PRIMARY KEY,
    -- Nombre de la tabla donde ocurrió el cambio (inyectado por TG_RELNAME).
    tabla_afectada VARCHAR(50) NOT NULL,
    -- Tipo de operación: INSERT, UPDATE o DELETE.
    operacion VARCHAR(10) NOT NULL,
    -- Usuario que realizó el cambio (desde la sesión Django o el usuario de DB).
    usuario_responsable VARCHAR(100) NOT NULL,
    -- Estado del registro antes del cambio (NULL para INSERT).
    datos_anteriores JSONB,
    -- Estado del registro después del cambio (NULL para DELETE).
    datos_nuevos JSONB,
    -- Marca temporal con zona horaria del momento del cambio.
    fecha TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Índices para consultas frecuentes de auditoría.
CREATE INDEX idx_auditoria_tabla ON auditoria_log(tabla_afectada);
CREATE INDEX idx_auditoria_fecha ON auditoria_log(fecha);
CREATE INDEX idx_auditoria_usuario ON auditoria_log(usuario_responsable);

-- Función genérica de auditoría que registra cualquier cambio en la tabla activada.
-- Captura el usuario desde la variable de sesión 'app.current_user' inyectada por Django.
CREATE OR REPLACE FUNCTION fn_registrar_auditoria()
RETURNS TRIGGER AS $$
DECLARE
    app_user TEXT;
BEGIN
    -- Captura del usuario desde la sesión de Django o el sistema de DB.
    BEGIN
        app_user := current_setting('app.current_user', true);
    EXCEPTION WHEN OTHERS THEN
        app_user := current_user;
    END;

    IF app_user IS NULL OR app_user = '' THEN
        app_user := 'DB_SYSTEM';
    END IF;

    -- Registro del cambio según el tipo de operación.
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

-- Activación de auditoría en tablas críticas del sistema.
-- Cada trigger captura INSERT, UPDATE y DELETE en la tabla correspondiente.
CREATE TRIGGER tr_auditoria_usuarios
    AFTER INSERT OR UPDATE OR DELETE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION fn_registrar_auditoria();

CREATE TRIGGER tr_auditoria_calificaciones
    AFTER INSERT OR UPDATE OR DELETE ON calificaciones
    FOR EACH ROW EXECUTE FUNCTION fn_registrar_auditoria();

CREATE TRIGGER tr_auditoria_matriculas
    AFTER INSERT OR UPDATE OR DELETE ON matriculas
    FOR EACH ROW EXECUTE FUNCTION fn_registrar_auditoria();

CREATE TRIGGER tr_auditoria_roles
    AFTER INSERT OR UPDATE OR DELETE ON usuarios_roles
    FOR EACH ROW EXECUTE FUNCTION fn_registrar_auditoria();

-- ==================================================================
-- 9. DATOS SEMILLA
-- ==================================================================

-- Roles base del sistema.
INSERT INTO roles (id, nombre) VALUES
(1, 'ROLE_ADMIN'),
(2, 'ROLE_PROFESOR'),
(3, 'ROLE_ALUMNO');

-- Centro educativo inicial.
INSERT INTO centros (id, nombre, ubicacion) VALUES
(1, 'IES Central', 'Madrid');

-- Usuarios de prueba (Contraseña: 1234 para todos, hash BCrypt).
-- Se incluyen las columnas de Django: is_superuser, is_staff, is_active.
INSERT INTO usuarios (id, username, password_hash, nombre, apellidos, email, activo, is_superuser, is_staff, is_active) VALUES
(1, 'admin',         '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Super', 'Admin',  'admin@tfg.com', true, true,  true,  true),
(2, 'profe1',        '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Juan',  'Garcia', 'juan@tfg.com',  true, false, false, true),
(3, 'alumno1',       '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Ana',   'Lopez',  'ana@tfg.com',   true, false, false, true),
(4, 'profe_alumno',  '$2a$10$LwjJeRKHaydg2n5bPd.5guuBwZow7V6dZTfit.vl6Re3xgdR88aLi', 'Pedro', 'Mix',    'pedro@tfg.com', true, false, false, true);

-- Asignación de roles a los usuarios.
-- El usuario 'profe_alumno' tiene doble rol para pruebas de multi-rol.
INSERT INTO usuarios_roles (usuario_id, rol_id) VALUES
(1, 1), (2, 2), (3, 3), (4, 2), (4, 3);

-- Sincronización de secuencias tras inserción manual de IDs.
-- Evita colisiones al insertar nuevos registros con SERIAL.
SELECT setval('roles_id_seq', (SELECT MAX(id) FROM roles));
SELECT setval('usuarios_id_seq', (SELECT MAX(id) FROM usuarios));
SELECT setval('centros_id_seq', (SELECT MAX(id) FROM centros));
SELECT setval('usuarios_roles_id_seq', (SELECT MAX(id) FROM usuarios_roles));

-- ==================================================================
-- 10. TABLAS DE SPRING SESSION (LEGADO JAVA)
-- ==================================================================
-- Mantenidas para compatibilidad con sistemas externos que aún
-- utilicen el backend Java original de SchooleduleJava.

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
