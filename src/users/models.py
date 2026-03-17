# Módulos de Django para la gestión de modelos y autenticación
from django.db import models
from django.contrib.auth.models import (
    AbstractBaseUser,
    BaseUserManager,
    PermissionsMixin,
)
from django.utils import timezone


# Clase encargada de gestionar la creación de usuarios y superusuarios
class CustomUserManager(BaseUserManager):
    """
    Gestor personalizado para el modelo CustomUser.
    Define la lógica de creación de usuarios normales y de administración.
    """

    def create_user(self, username, password=None, **extra_fields):
        """
        Crea y guarda un usuario con el nombre de usuario y contraseña dados.
        """
        if not username:
            # Lanza un error si no se proporciona un nombre de usuario, campo obligatorio.
            raise ValueError("El nombre de usuario es obligatorio.")

        # Instancia el modelo con los campos adicionales recibidos.
        user = self.model(username=username, **extra_fields)
        # Establece la contraseña utilizando el sistema de hashing de Django.
        user.set_password(password)
        # Persiste el usuario en la base de datos configurada.
        user.save(using=self._db)
        return user

    def create_superuser(self, username, password=None, **extra_fields):
        """
        Crea y guarda un superusuario con permisos totales en el sistema.
        """
        # Configura los flags de privilegios por defecto para un superusuario.
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("activo", True)

        # Verifica que el superusuario tenga activado el acceso al panel de administración.
        if extra_fields.get("is_staff") is not True:
            raise ValueError("El superusuario debe tener is_staff=True.")
        # Verifica que el superusuario posea los privilegios globales de PermissionsMixin.
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("El superusuario debe tener is_superuser=True.")

        return self.create_user(username, password, **extra_fields)


# Modelo que representa los roles definidos en el catálogo de PostgreSQL
class Role(models.Model):
    """
    Catálogo de perfiles de acceso (ADMIN, PROFESOR, ALUMNO).
    Mapea directamente a la tabla 'roles' preexistente.
    """

    # Nombre único del rol, limitado a 50 caracteres según el esquema SQL.
    nombre = models.CharField(max_length=50, unique=True)

    class Meta:
        # Nombre de la tabla física en PostgreSQL.
        db_table = "roles"
        # Nombres legibles para el modelo en el panel de administración.
        verbose_name = "rol"
        verbose_name_plural = "roles"

    def __str__(self):
        # Representación en cadena del nombre del rol.
        return self.nombre


# Modelo que representa un centro educativo (Sede)
class Centro(models.Model):
    """
    Entidad que representa una sede o centro educativo.
    Mapea a la tabla 'centros' del esquema PostgreSQL.
    """

    # Nombre oficial del centro, limitado a 100 caracteres.
    nombre = models.CharField(max_length=100)
    # Dirección física o descripción de la ubicación del centro.
    ubicacion = models.CharField(max_length=200, null=True, blank=True)
    # Configuración específica del centro almacenada en formato JSON (JSONB en PG).
    configuracion = models.JSONField(null=True, blank=True)

    class Meta:
        # Nombre de la tabla física en PostgreSQL.
        db_table = "centros"
        # Nombres legibles para el modelo.
        verbose_name = "centro"
        verbose_name_plural = "centros"

    def __str__(self):
        # Representación en cadena del nombre del centro.
        return self.nombre


# Modelo de usuario personalizado que hereda de la base de autenticación de Django
class CustomUser(AbstractBaseUser, PermissionsMixin):
    """
    Representación de un usuario en el sistema SchooledulePY.
    Mapea directamente a la tabla 'usuarios' definida en el esquema de PostgreSQL.
    """

    # Identificador único para el inicio de sesión, limitado a 50 caracteres.
    username = models.CharField(max_length=50, unique=True)

    # Redefinición del campo password para mapearlo a 'password_hash' en PostgreSQL
    password = models.CharField(max_length=255, db_column="password_hash")

    # Nombre de pila del usuario, obligatorio para el perfil.
    nombre = models.CharField(max_length=100)
    # Apellidos del usuario, obligatorio para el perfil.
    apellidos = models.CharField(max_length=100)
    # Dirección de correo electrónico, debe ser única en todo el sistema.
    email = models.EmailField(max_length=150, unique=True, null=True, blank=True)
    # Estado de la cuenta: permite deshabilitar usuarios sin borrar sus datos.
    activo = models.BooleanField(default=True)
    # Fecha y hora en la que el usuario fue dado de alta.
    fecha_registro = models.DateTimeField(default=timezone.now)

    # Atributos internos de Django para compatibilidad con el sistema de permisos.
    # Define si el usuario puede acceder al sitio de administración.
    is_staff = models.BooleanField(default=False)
    # Indica si la cuenta está activa (alias de 'activo' para Django).
    is_active = models.BooleanField(default=True)

    # Relación de muchos a muchos con la tabla de roles mediante la tabla intermedia 'usuarios_roles'.
    roles = models.ManyToManyField(Role, through="UserRole", related_name="usuarios")

    # Relación con Centros (Multi-tenancy)
    # Un usuario puede estar vinculado a uno o varios centros (ej. profesor en dos centros).
    centros = models.ManyToManyField(
        Centro,
        db_table="profesores_sedes",  # Mapea a la tabla existente para profesores
        related_name="usuarios",
    )

    # Asigna el gestor personalizado definido anteriormente.
    objects = CustomUserManager()

    # Define el campo que se utilizará como identificador único en la autenticación.
    USERNAME_FIELD = "username"
    # Define los campos adicionales requeridos al crear un usuario mediante createsuperuser.
    REQUIRED_FIELDS = ["nombre", "apellidos"]

    class Meta:
        # Nombre de la tabla física en la base de datos PostgreSQL.
        # Debe coincidir exactamente con el esquema V1__Initial_Schema.sql.
        db_table = "usuarios"
        # Nombres legibles para el modelo en el panel de administración.
        verbose_name = "usuario"
        verbose_name_plural = "usuarios"

    def __str__(self):
        # Representación en cadena del objeto (Nombre Apellidos).
        return f"{self.nombre} {self.apellidos} ({self.username})"


# Tabla intermedia explícita para la relación entre Usuarios y Roles
class UserRole(models.Model):
    """
    Mapea la relación N:M entre usuarios y roles.
    Mapea a la tabla 'usuarios_roles' del esquema PostgreSQL.
    """

    # Vinculación con el usuario correspondiente.
    usuario = models.ForeignKey(
        CustomUser, on_delete=models.CASCADE, db_column="usuario_id"
    )
    # Vinculación con el rol correspondiente.
    rol = models.ForeignKey(Role, on_delete=models.CASCADE, db_column="rol_id")

    class Meta:
        # Nombre de la tabla física en PostgreSQL.
        db_table = "usuarios_roles"
        # Garantiza que la combinación usuario-rol sea única.
        unique_together = (("usuario", "rol"),)
        # Nombres legibles para la relación.
        verbose_name = "rol de usuario"
        verbose_name_plural = "roles de usuario"
