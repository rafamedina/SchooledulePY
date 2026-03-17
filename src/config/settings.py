"""
Configuración central del proyecto Django 'config'.
Generado automáticamente por 'django-admin startproject' versión 5.2.12.
Este archivo gestiona variables de entorno, aplicaciones, middleware y conexiones.
"""

# Módulo para interactuar con el sistema operativo
# Clase Path para manipulación de rutas de archivos de forma agnóstica al sistema
from pathlib import Path

# Función config para extraer variables del archivo .env de forma segura
from decouple import config

# Define la ruta raíz del proyecto (directorio 'src')
# Se obtiene resolviendo la ruta del archivo actual y subiendo dos niveles
BASE_DIR = Path(__file__).resolve().parent.parent

# Clave secreta para la seguridad criptográfica de la aplicación
# Se extrae de .env para evitar su exposición en el control de versiones
SECRET_KEY = config("SECRET_KEY", default="django-insecure-default-key")

# Modo de depuración que habilita mensajes de error detallados
# Se convierte a booleano desde el valor de cadena en .env
DEBUG = config("DEBUG", default=True, cast=bool)

# Lista de hosts/dominios permitidos para servir la aplicación
# Se divide la cadena de .env por comas para generar una lista de Python
ALLOWED_HOSTS = config("ALLOWED_HOSTS", default="localhost,127.0.0.1,0.0.0.0").split(
    ","
)

# Lista de aplicaciones instaladas y habilitadas en el proyecto Django
INSTALLED_APPS = [
    # Módulo de administración automática de Django
    "django.contrib.admin",
    # Sistema de autenticación de usuarios
    "django.contrib.auth",
    # Framework para tipos de contenido genéricos
    "django.contrib.contenttypes",
    # Gestión de sesiones de usuario
    "django.contrib.sessions",
    # Sistema de mensajes flash temporales
    "django.contrib.messages",
    # Gestión de archivos estáticos (CSS, JS, Imágenes)
    "django.contrib.staticfiles",
    # Aplicación local para la gestión de usuarios y perfiles
    "users.apps.UsersConfig",
    # Aplicación central para lógica transversal (middleware, vistas base)
    "core.apps.CoreConfig",
]

# Define el modelo de usuario personalizado que utilizará el sistema de autenticación
AUTH_USER_MODEL = "users.CustomUser"

# Lista de middleware que procesan las peticiones y respuestas HTTP
MIDDLEWARE = [
    # Mejora la seguridad añadiendo cabeceras HTTP específicas
    "django.middleware.security.SecurityMiddleware",
    # Habilita el soporte de sesiones en las peticiones
    "django.contrib.sessions.middleware.SessionMiddleware",
    # Añade funcionalidades comunes como el redireccionamiento de URLs
    "django.middleware.common.CommonMiddleware",
    # Protege contra ataques de falsificación de petición en sitios cruzados
    "django.middleware.csrf.CsrfViewMiddleware",
    # Asocia usuarios con peticiones utilizando sesiones
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    # Gestiona la persistencia de mensajes entre peticiones
    "django.contrib.messages.middleware.MessageMiddleware",
    # Previene ataques de clickjacking mediante cabeceras X-Frame-Options
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    # Middleware personalizado para la gestión de multi-tenencia y contexto activo
    "core.middleware.MultiTenancyMiddleware",
]

# Ruta al módulo principal de configuración de URLs del proyecto
ROOT_URLCONF = "config.urls"

# Configuración del motor de plantillas de Django
TEMPLATES = [
    {
        # Define el backend de procesamiento de plantillas (Django Standard)
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        # Directorios adicionales donde buscar plantillas fuera de las apps
        "DIRS": [BASE_DIR / "templates"],
        # Indica si se deben buscar plantillas dentro de cada aplicación
        "APP_DIRS": True,
        "OPTIONS": {
            # Procesadores de contexto que añaden variables globales a las plantillas
            "context_processors": [
                # Añade variables de depuración al contexto
                "django.template.context_processors.debug",
                # Añade el objeto de la petición (request) actual
                "django.template.context_processors.request",
                # Añade el objeto del usuario autenticado
                "django.contrib.auth.context_processors.auth",
                # Añade los mensajes del sistema al contexto
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# Punto de entrada para servidores web compatibles con WSGI (Gunicorn)
WSGI_APPLICATION = "config.wsgi.application"

# Configuración de la conexión a la base de datos PostgreSQL
DATABASES = {
    "default": {
        # Motor de base de datos específico para PostgreSQL
        "ENGINE": "django.db.backends.postgresql",
        # Nombre de la base de datos extraído de .env
        "NAME": config("DB_NAME", default="schooledule"),
        # Usuario de conexión extraído de .env
        "USER": config("DB_USER", default="postgres"),
        # Contraseña del usuario extraída de .env
        "PASSWORD": config("DB_PASSWORD", default="postgres_password"),
        # Dirección del host del servidor de base de datos
        "HOST": config("DB_HOST", default="localhost"),
        # Puerto de escucha del servidor PostgreSQL (convertido a entero)
        "PORT": config("DB_PORT", default="5432", cast=int),
    }
}

# Configuración de validadores de contraseñas para mejorar la seguridad
AUTH_PASSWORD_VALIDATORS = [
    {
        # Evita contraseñas similares a los atributos del usuario
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        # Impone una longitud mínima para las contraseñas
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        # Verifica que la contraseña no esté en una lista de comunes
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        # Evita contraseñas compuestas únicamente por números
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

# Configuración de internacionalización (Idioma: Español de España)
LANGUAGE_CODE = "es-es"

# Configuración de la zona horaria del servidor (Madrid, España)
TIME_ZONE = "Europe/Madrid"

# Habilita el sistema de traducción de Django
USE_I18N = True

# Habilita el soporte de zonas horarias en la base de datos
USE_TZ = True

# URL base para acceder a los archivos estáticos desde el navegador
STATIC_URL = "static/"
# Directorios adicionales donde se encuentran archivos estáticos globales
STATICFILES_DIRS = [BASE_DIR / "static"]
# Ruta absoluta donde se recolectarán los estáticos para producción
STATIC_ROOT = BASE_DIR.parent / "staticfiles"

# URL base para acceder a los archivos subidos por los usuarios
MEDIA_URL = "media/"
# Ruta absoluta en el sistema de archivos para almacenar las subidas
MEDIA_ROOT = BASE_DIR / "media"

# Define el tipo de campo por defecto para claves primarias autogeneradas
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Configuración de los algoritmos de hashing de contraseñas
# Se prioriza BCrypt para compatibilidad con el esquema inicial de la base de datos
PASSWORD_HASHERS = [
    # Utiliza BCrypt con SHA256 para mayor seguridad y compatibilidad con PG
    "django.contrib.auth.hashers.BCryptSHA256PasswordHasher",
    # Alternativa estándar de Django basada en PBKDF2
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2SHA1PasswordHasher",
    # Alternativa moderna Argon2 (requiere argon2-cffi)
    "django.contrib.auth.hashers.Argon2PasswordHasher",
]

# Configuración de redirecciones de autenticación
# URL donde se envía a los usuarios no autenticados
LOGIN_URL = "users:login"
# URL a la que se redirige tras un inicio de sesión exitoso
LOGIN_REDIRECT_URL = "home"
# URL a la que se redirige tras cerrar la sesión (vuelve al login)
LOGOUT_REDIRECT_URL = "users:login"
