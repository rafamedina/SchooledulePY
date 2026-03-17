# Módulos para pruebas unitarias de integración y gestión de URLs
import pytest
from django.contrib.auth import get_user_model
from users.models import Centro
from core.models import Grupo, _thread_locals

# Obtiene la clase del modelo de usuario configurado (CustomUser)
User = get_user_model()


# Decorador que habilita el acceso a la base de datos para la función de prueba
@pytest.mark.django_db
def test_data_isolation_by_centro(client):
    """
    Verifica que las consultas a modelos multi-tenant (ej. Grupo)
    devuelvan solo los registros pertenecientes al centro activo en la sesión.
    """
    # 1. Configuración de Centros
    centro_madrid = Centro.objects.create(nombre="IES Madrid")
    centro_sevilla = Centro.objects.create(nombre="IES Sevilla")

    # 2. Creación de Grupos asociados a diferentes centros
    # Se usa unfiltered_objects para asegurar la creación sin interferencia del manager
    Grupo.unfiltered_objects.create(
        nombre="Grupo A (MAD)", centro=centro_madrid, curso_academico_id=1
    )
    Grupo.unfiltered_objects.create(
        nombre="Grupo B (SEV)", centro=centro_sevilla, curso_academico_id=1
    )

    # 3. Configuración de Usuario y sesión
    user = User.objects.create_user(
        username="isolation_user", password="pw", nombre="I", apellidos="U"
    )
    client.force_login(user)

    # 4. Simulación de sesión con 'IES Madrid' activo
    session = client.session
    session["active_centro_id"] = centro_madrid.id
    session.save()

    # 5. Inyección manual del request en el hilo local para la prueba unitaria
    # En un entorno real, el Middleware realiza esta tarea.
    # En pytest, el código del test corre en un contexto donde el middleware ya pasó,
    # pero el acceso directo a los modelos en el test no tiene el request inyectado.
    from django.test import RequestFactory

    factory = RequestFactory()
    request = factory.get("/")
    request.user = user
    request.session = session
    _thread_locals.request = request

    try:
        # Verifica que solo se vea el grupo de Madrid utilizando el gestor por defecto
        grupos_visibles = Grupo.objects.all()
        assert grupos_visibles.count() == 1
        assert grupos_visibles.first().nombre == "Grupo A (MAD)"

        # 6. Cambio de contexto a 'IES Sevilla'
        request.session["active_centro_id"] = centro_sevilla.id

        # Verifica el cambio de visibilidad al centro de Sevilla
        grupos_visibles = Grupo.objects.all()
        assert grupos_visibles.count() == 1
        assert grupos_visibles.first().nombre == "Grupo B (SEV)"
    finally:
        # Limpieza del hilo local para evitar efectos secundarios en otros tests
        if hasattr(_thread_locals, "request"):
            del _thread_locals.request
