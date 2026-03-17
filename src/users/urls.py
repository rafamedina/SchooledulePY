# Módulos para la gestión de URLs y vistas de autenticación nativas de Django
from django.urls import path
from django.contrib.auth import views as auth_views
from . import views

# Espacio de nombres para la aplicación de usuarios
app_name = "users"

# Definición de rutas para el ciclo de vida de la sesión de usuario
urlpatterns = [
    # Vista de inicio de sesión: utiliza la implementación estándar de Django
    # 'template_name' especifica la ubicación de la interfaz de usuario
    path(
        "login/",
        auth_views.LoginView.as_view(template_name="registration/login.html"),
        name="login",
    ),
    # Vista de cierre de sesión personalizada: limpia contexto multi-tenant y desautentica
    path("logout/", views.custom_logout, name="logout"),
]
