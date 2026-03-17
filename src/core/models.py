# Módulos de Django para la gestión de modelos y peticiones
from django.db import models

# Almacén local de hilos para guardar la petición actual de forma segura
import threading

# Variable global protegida para almacenar el objeto request en el hilo de ejecución
_thread_locals = threading.local()


def get_current_request():
    """
    Obtiene el objeto request almacenado en el hilo de ejecución actual.
    """
    return getattr(_thread_locals, "request", None)


# Gestor de base de datos que filtra automáticamente por el centro activo en la sesión
class TenantManager(models.Manager):
    """
    Manager personalizado para aplicar aislamiento de datos (Multi-tenancy).
    Filtra todas las consultas basándose en el 'active_centro_id' almacenado en la sesión.
    """

    def get_queryset(self):
        """
        Sobrescribe el queryset por defecto para inyectar el filtro de centro.
        """
        # Obtiene la petición actual mediante el acceso a hilos locales
        request = get_current_request()
        # Recupera el QuerySet base del motor de Django
        queryset = super().get_queryset()

        # Si hay una petición activa con un centro seleccionado en la sesión
        if request and hasattr(request, "session"):
            centro_id = request.session.get("active_centro_id")
            if centro_id:
                # Aplica el filtro restrictivo por el identificador del centro
                return queryset.filter(centro_id=centro_id)

        # Si no hay contexto de sesión, retorna el QuerySet sin filtrar (ej. scripts o admin)
        return queryset


# Modelo que representa las asignaturas o módulos profesionales
class Modulo(models.Model):
    """
    Representa un módulo educativo o asignatura.
    Mapea a la tabla 'modulos' del esquema PostgreSQL.
    """

    codigo = models.CharField(max_length=20)
    nombre = models.CharField(max_length=150)

    class Meta:
        db_table = "modulos"
        verbose_name = "módulo"
        verbose_name_plural = "módulos"

    def __str__(self):
        return f"{self.codigo} - {self.nombre}"


# Modelo que representa un conjunto de alumnos (aula/clase) con aislamiento de datos
class Grupo(models.Model):
    """
    Entidad que agrupa alumnos con filtrado automático por centro (Multi-tenant).
    """

    nombre = models.CharField(max_length=50)
    centro = models.ForeignKey(
        "users.Centro", on_delete=models.CASCADE, db_column="centro_id"
    )
    curso_academico_id = models.IntegerField()

    # Asigna el gestor de tenencia para filtrar las consultas automáticamente
    objects = TenantManager()
    # Mantiene el gestor estándar disponible para casos excepcionales
    unfiltered_objects = models.Manager()

    class Meta:
        db_table = "grupos"
        verbose_name = "grupo"
        verbose_name_plural = "grupos"

    def __str__(self):
        return self.nombre
