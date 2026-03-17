# Módulos para pruebas unitarias de integración y gestión de base de datos
import pytest
from django.db import connection
import os


def load_initial_schema():
    """
    Carga manualmente el esquema SQL inicial en la base de datos de pruebas.
    Necesario porque pytest-django solo usa las migraciones de Django.
    """
    schema_path = os.path.join("database", "scripts", "V1__Initial_Schema.sql")
    with open(schema_path, "r", encoding="utf-8") as f:
        sql = f.read()

    with connection.cursor() as cursor:
        # Ejecuta el script SQL completo para crear tablas y triggers
        cursor.execute(sql)


# Decorador que habilita el acceso a la base de datos para la función de prueba
@pytest.mark.django_db
def test_calificaciones_audit_trigger():
    """
    Verifica que el trigger de base de datos 'trigger_auditoria_notas' funcione
    correctamente utilizando SQL nativo para evitar conflictos de esquemas con el ORM.
    Valida que se inserte un registro en 'auditoria_notas'.
    """
    # 0. Carga el esquema real de PostgreSQL para tener los triggers y todas las tablas
    load_initial_schema()

    # 1. Realiza las operaciones mediante SQL nativo para asegurar compatibilidad total con el esquema V1
    with connection.cursor() as cursor:
        # Inserta el curso académico
        cursor.execute(
            "INSERT INTO cursos_academicos (id, nombre, fecha_inicio, fecha_fin, activo) VALUES (200, '25-26', '2025-09-01', '2026-06-30', true)"
        )
        # Inserta el módulo
        cursor.execute(
            "INSERT INTO modulos (id, codigo, nombre) VALUES (200, 'TEST_AUDIT', 'Modulo de Auditoria')"
        )
        # Inserta el grupo (Referencia al centro con ID 1 creado en V1)
        cursor.execute(
            "INSERT INTO grupos (id, nombre, centro_id, curso_academico_id) VALUES (200, 'G_AUDIT', 1, 200)"
        )
        # Inserta la impartición (Referencia al usuario con ID 1 creado en V1)
        cursor.execute(
            "INSERT INTO imparticiones (id, modulo_id, grupo_id, profesor_id, centro_id) VALUES (200, 200, 200, 1, 1)"
        )
        # Inserta la matrícula
        cursor.execute(
            "INSERT INTO matriculas (id, alumno_id, imparticion_id, centro_id) VALUES (200, 1, 200, 1)"
        )
        # Inserta el periodo de evaluación
        cursor.execute(
            "INSERT INTO periodos_evaluacion (id, imparticion_id, nombre) VALUES (200, 200, '1EV')"
        )
        # Inserta el item evaluable
        cursor.execute(
            "INSERT INTO items_evaluables (id, imparticion_id, periodo_evaluacion_id, nombre, tipo) VALUES (200, 200, 200, 'Examen Audit', 'EXAMEN')"
        )
        # Inserta la calificación inicial
        cursor.execute(
            "INSERT INTO calificaciones (id, matricula_id, item_evaluable_id, valor) VALUES (200, 200, 200, 5.00)"
        )

    # 2. Modifica la calificación para disparar el trigger
    with connection.cursor() as cursor:
        # Cambia la nota de 5.00 a 8.50
        cursor.execute("UPDATE calificaciones SET valor = 8.50 WHERE id = 200")

    # 3. Verifica que se haya generado el registro de auditoría en PostgreSQL
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT valor_anterior, valor_nuevo FROM auditoria_notas WHERE calificacion_id = 200"
        )
        audit_record = cursor.fetchone()

        # Comprueba que el registro exista
        assert audit_record is not None
        # Verifica que el valor anterior capturado por el trigger sea el correcto
        assert float(audit_record[0]) == 5.00
        # Verifica que el valor nuevo capturado por el trigger sea el correcto
        assert float(audit_record[1]) == 8.50
