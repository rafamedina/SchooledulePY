# Módulos para redirección y gestión de URLs
from django.shortcuts import redirect
from django.urls import reverse

# Importación del almacenamiento local de hilos de core.models
from .models import _thread_locals


# Middleware para gestionar el contexto de multi-tenencia (Centro y Rol activo)
class MultiTenancyMiddleware:
    """
    Middleware que asegura la selección de contexto y almacena la petición actual.
    Habilita el filtrado automático por centro en los modelos multi-tenant.
    """

    def __init__(self, get_response):
        # Almacena la función para obtener la respuesta del siguiente middleware/vista.
        self.get_response = get_response

    def __call__(self, request):
        """
        Lógica ejecutada en cada petición HTTP entrante.
        """
        # Almacena el objeto request en el hilo local antes de procesar la vista.
        # Esto permite que el TenantManager acceda a la sesión para filtrar consultas.
        _thread_locals.request = request

        # Solo aplica validaciones para usuarios que han iniciado sesión.
        # Es fundamental verificar request.user.is_authenticated para evitar
        # interferir con procesos de logout o usuarios anónimos.
        if hasattr(request, "user") and request.user.is_authenticated:
            # Lista de nombres de URLs exentas de la validación para evitar bucles de redirección.
            exempt_urls = [
                reverse("users:login"),  # Vista de inicio de sesión.
                reverse("users:logout"),  # Vista de cierre de sesión.
                reverse("core:select_context"),  # Vista de selección de contexto.
                reverse("admin:index"),  # Panel de administración de Django.
            ]

            # Verifica si la URL actual no está en la lista de exenciones.
            if request.path not in exempt_urls and not request.path.startswith(
                "/admin/"
            ):
                # Comprueba si el centro_id y el rol_id están presentes en el objeto de sesión.
                centro_id = request.session.get("active_centro_id")
                rol_id = request.session.get("active_rol_id")

                # Si falta alguno de los dos, redirige a la página de selección.
                if not centro_id or not rol_id:
                    # El usuario debe elegir su contexto de trabajo antes de continuar.
                    return redirect("core:select_context")

        # Continúa con el procesamiento de la petición.
        response = self.get_response(request)

        # Limpia el objeto request del hilo local tras finalizar la petición.
        # Evita la contaminación de datos entre diferentes hilos o peticiones.
        if hasattr(_thread_locals, "request"):
            del _thread_locals.request

        return response
