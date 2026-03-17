"""
Configuración principal de rutas para el proyecto Django 'config'.
Mapea las peticiones HTTP a sus correspondientes vistas o aplicaciones.
"""

# Módulos de Django para la gestión de enrutamiento y respuestas
from django.contrib import admin
from django.urls import path, include
from django.http import HttpResponse


# Vista temporal para la raíz del proyecto para pruebas iniciales
def home_temp(request):
    """
    Función de prueba que muestra el estado de la sesión activa tras la selección.
    """
    # Extrae el Rol y Centro de la sesión del usuario
    rol = request.session.get("active_rol_id", "Ninguno")
    centro = request.session.get("active_centro_id", "Ninguno")
    # Retorna un cuerpo HTML simple indicando el contexto de trabajo establecido
    return HttpResponse(
        f"<h1>Dashboard SchooledulePY</h1><p>Rol activo: {rol}</p><p>Centro activo: {centro}</p>"
    )


# Lista de patrones de URL habilitados en el sistema
urlpatterns = [
    # Ruta al panel de administración del sistema
    path("admin/", admin.site.urls),
    # Inclusión de las rutas de la aplicación 'users' (Autenticación y Perfiles)
    path("auth/", include("users.urls")),
    # Inclusión de las rutas de la aplicación 'core' (Middleware y Contexto)
    path("core/", include("core.urls")),
    # Ruta raíz temporal para validación del Dashboard y Multi-tenancy
    path("", home_temp, name="home"),
]
