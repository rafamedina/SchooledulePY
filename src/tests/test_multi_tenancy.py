# Módulos para pruebas unitarias de integración y gestión de URLs
import pytest
from django.urls import reverse
from django.contrib.auth import get_user_model
from users.models import Role, Centro

# Obtiene la clase del modelo de usuario configurado (CustomUser)
User = get_user_model()


# Decorador que habilita el acceso a la base de datos para la función de prueba
@pytest.mark.django_db
def test_middleware_redirects_unselected_context(client):
    """
    Verifica que el MultiTenancyMiddleware redirija a la página de selección
    si un usuario autenticado no ha elegido un Rol ni un Centro.
    """
    # Crea un usuario de prueba para la autenticación
    user = User.objects.create_user(
        username="redirect_test", password="pw", nombre="R", apellidos="T"
    )
    # Realiza el inicio de sesión en el cliente de pruebas de Django
    client.force_login(user)

    # Intenta acceder a la página de inicio
    response = client.get(reverse("home"))

    # Comprueba que la respuesta sea un redireccionamiento (Código 302)
    assert response.status_code == 302
    # Verifica que el destino de la redirección sea la vista de selección de contexto
    assert response.url == reverse("core:select_context")


# Decorador para pruebas de base de datos
@pytest.mark.django_db
def test_select_context_view_persists_in_session(client):
    """
    Verifica que la selección de Rol y Centro en la vista 'select_context'
    se guarde correctamente en el objeto de sesión del usuario.
    """
    # Crea los datos maestros necesarios para el contexto
    rol = Role.objects.create(nombre="ROLE_ADMIN")
    centro = Centro.objects.create(nombre="Centro Test")

    # Crea un usuario y le asigna los permisos necesarios
    user = User.objects.create_user(
        username="persist_test", password="pw", nombre="P", apellidos="T"
    )
    user.roles.add(rol)
    user.centros.add(centro)

    # Inicia sesión forzada
    client.force_login(user)

    # Envía el formulario de selección mediante una petición POST
    response = client.post(
        reverse("core:select_context"), {"rol_id": rol.id, "centro_id": centro.id}
    )

    # Comprueba que tras la selección se redirija a la página principal (home)
    assert response.status_code == 302
    assert response.url == "/"

    # Verifica que los identificadores seleccionados persistan en la sesión del cliente
    assert client.session.get("active_rol_id") == rol.id
    assert client.session.get("active_centro_id") == centro.id


# Decorador para pruebas de base de datos
@pytest.mark.django_db
def test_middleware_allows_access_with_context(client):
    """
    Verifica que el middleware permita el acceso a la aplicación una vez
    que el usuario tiene un Rol y un Centro establecidos en su sesión.
    """
    # Configuración de usuario y contexto
    user = User.objects.create_user(
        username="access_test", password="pw", nombre="A", apellidos="T"
    )
    client.force_login(user)

    # Inyecta manualmente los valores en la sesión para simular una selección previa
    session = client.session
    session["active_rol_id"] = 1
    session["active_centro_id"] = 1
    session.save()

    # Intenta acceder a la página de inicio
    response = client.get(reverse("home"))

    # Comprueba que el acceso sea exitoso (Código 200) sin redirecciones
    assert response.status_code == 200
    # Verifica que el contenido de la respuesta sea el esperado por la vista 'home_temp'
    assert b"Dashboard SchooledulePY" in response.content
