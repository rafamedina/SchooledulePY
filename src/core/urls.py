# Módulos para la gestión de URLs
from django.urls import path

# Importación de vistas de la aplicación core
from . import views

# Espacio de nombres para la aplicación core
app_name = "core"

# Definición de rutas específicas para la gestión transversal del sistema
urlpatterns = [
    # Ruta para la página de selección de Centro y Rol activo
    # Permite al usuario establecer su contexto de trabajo en la sesión
    path("select-context/", views.select_context, name="select_context"),
]
