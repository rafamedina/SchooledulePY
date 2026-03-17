# Módulos para pruebas unitarias de integración y gestión de URLs
import pytest
from django.urls import reverse
from django.contrib.auth import get_user_model

# Obtiene la clase del modelo de usuario configurado (CustomUser)
User = get_user_model()


# Decorador que habilita el acceso a la base de datos para la función de prueba
@pytest.mark.django_db
def test_login_successful_redirects_to_context_selection(client):
    """
    Verifica que un usuario con credenciales válidas sea autenticado
    y redirigido a la selección de Centro/Rol por el middleware.
    """
    # 1. Crea un usuario de prueba con contraseña hasheada (BCrypt)
    password = "securepassword123"
    User.objects.create_user(
        username="auth_test", password=password, nombre="A", apellidos="T"
    )

    # 2. Envía la petición POST al formulario de inicio de sesión
    response = client.post(
        reverse("users:login"), {"username": "auth_test", "password": password}
    )

    # 3. Comprueba que se redirija tras el login exitoso (Código 302)
    # Django redirige a LOGIN_REDIRECT_URL ('home'), pero el Middleware
    # intercepta y redirige a 'core:select_context' porque no hay contexto en sesión.
    assert response.status_code == 302

    # Sigue la cadena de redirecciones para verificar el destino final
    # Primero va a 'home' (/)
    assert response.url == "/"

    # Al acceder a /, el middleware lo manda a select-context
    response_final = client.get("/")
    assert response_final.status_code == 302
    assert response_final.url == reverse("core:select_context")


# Decorador para pruebas de base de datos
@pytest.mark.django_db
def test_login_failed_shows_error(client):
    """
    Verifica que el sistema rechace credenciales incorrectas
    y permanezca en la página de login con mensajes de error.
    """
    # 1. Crea un usuario de prueba
    User.objects.create_user(
        username="fail_test", password="correct_pw", nombre="F", apellidos="T"
    )

    # 2. Intenta iniciar sesión con contraseña errónea
    response = client.post(
        reverse("users:login"), {"username": "fail_test", "password": "wrong_password"}
    )

    # 3. Verifica que no haya redirección (Código 200 - Recarga de la misma página)
    assert response.status_code == 200
    # Comprueba que el formulario en el contexto contenga errores
    assert response.context["form"].errors is not None
    # Verifica que el mensaje de error personalizado esté presente en el HTML
    assert b"Nombre de usuario o contrase\xc3\xb1a incorrectos." in response.content


# Decorador para pruebas de base de datos
@pytest.mark.django_db
def test_logout_redirects_to_login(client):
    """
    Verifica que al cerrar la sesión se destruya el contexto del usuario
    y se le redirija a la página de acceso según la configuración.
    """
    # 1. Autentica un usuario
    user = User.objects.create_user(
        username="logout_test", password="pw", nombre="L", apellidos="T"
    )
    client.force_login(user)

    # 2. Ejecuta la petición de cierre de sesión
    # En Django 5.0+, LogoutView requiere POST por defecto por seguridad
    response = client.post(reverse("users:logout"))

    # 3. Comprueba la redirección al login (Código 302)
    assert response.status_code == 302
    assert response.url == reverse("users:login")

    # 4. Verifica que ya no esté autenticado
    assert "_auth_user_id" not in client.session
