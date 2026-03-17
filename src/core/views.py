# Módulos de Django para la gestión de respuestas y lógica de vistas
from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages


# Decorador que asegura que solo usuarios autenticados accedan a la vista
@login_required
def select_context(request):
    """
    Vista que permite al usuario seleccionar un Rol y un Centro de trabajo.
    Valida que el usuario tenga permisos sobre las opciones seleccionadas.
    """
    # Procesa la selección enviada mediante el formulario POST
    if request.method == "POST":
        # Extrae los identificadores de Rol y Centro de los datos POST
        rol_id = request.POST.get("rol_id")
        centro_id = request.POST.get("centro_id")

        # Verifica que ambos campos hayan sido proporcionados
        if rol_id and centro_id:
            # Validación de pertenencia: comprueba que el usuario posea el rol elegido
            if not request.user.roles.filter(id=rol_id).exists():
                # Mensaje de error si intenta seleccionar un rol no asignado
                messages.error(request, "No tienes permiso para el rol seleccionado.")
                return redirect("core:select_context")

            # Validación de pertenencia: comprueba que el usuario pertenezca al centro elegido
            if not request.user.centros.filter(id=centro_id).exists():
                # Mensaje de error si intenta acceder a un centro no vinculado
                messages.error(request, "No perteneces al centro seleccionado.")
                return redirect("core:select_context")

            # Almacena las selecciones validadas en la sesión del usuario para persistencia
            request.session["active_rol_id"] = int(rol_id)
            request.session["active_centro_id"] = int(centro_id)

            # Redirige a la página principal una vez establecido el contexto
            return redirect("/")

    # Obtiene las opciones disponibles específicamente para el usuario actual
    context = {
        # Lista de roles asignados al usuario autenticado
        "user_roles": request.user.roles.all(),
        # Lista de centros educativos asociados al usuario
        "user_centros": request.user.centros.all(),
    }

    # Renderiza la plantilla de selección con el contexto generado
    return render(request, "core/select_context.html", context)
