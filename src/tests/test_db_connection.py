# Módulo para el framework de pruebas unitarias
import pytest

# Módulo de Django para gestionar las conexiones a la base de datos
from django.db import connections

# Excepción que se lanza cuando hay errores en la operación de la base de datos
from django.db.utils import OperationalError


# Decorador que habilita el acceso a la base de datos para la función de prueba
@pytest.mark.django_db
def test_db_connection():
    """
    Verifica que la conexión a la base de datos esté activa y sea funcional.
    Utiliza el cursor de la conexión por defecto para ejecutar una consulta simple.
    """
    # Obtiene la conexión configurada como 'default' en settings.py
    db_conn = connections["default"]
    try:
        # Intenta instanciar un cursor para validar la comunicación física con el servidor
        db_conn.cursor()
    # Captura errores de conexión o fallos operacionales de PostgreSQL
    except OperationalError:
        # Falla la prueba con un mensaje descriptivo si el servidor no responde
        pytest.fail(
            "La base de datos no es accesible. Verifica la configuración de DATABASES y el estado del servidor PostgreSQL."
        )

    # Verifica que el motor de base de datos sea efectivamente PostgreSQL
    # 'postgresql' es el identificador del vendor para el backend configurado
    assert (
        db_conn.vendor == "postgresql"
    ), f"Se esperaba 'postgresql', pero se encontró '{db_conn.vendor}'"
