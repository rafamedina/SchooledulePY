# Módulos para la gestión de autenticación y redirección
from django.contrib.auth import logout
from django.shortcuts import redirect


def custom_logout(request):
    """
    Vista personalizada para el cierre de sesión.
    Limpia los datos de contexto multi-tenancy de la sesión antes de desautenticar.
    """
    if request.method == "POST":
        # Elimina las variables de contexto activo para evitar interferencias en el middleware
        if "active_rol_id" in request.session:
            del request.session["active_rol_id"]
        if "active_centro_id" in request.session:
            del request.session["active_centro_id"]

        # Ejecuta la lógica de desautenticación estándar de Django
        logout(request)

    # Redirige a la página de inicio de sesión tras el logout
    return redirect("users:login")
