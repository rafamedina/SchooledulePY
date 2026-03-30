#!/bin/sh
# Script de entrada para la orquestación de servicios Django dentro del contenedor Docker.
# Gestiona la inicialización de archivos estáticos, migraciones y el arranque del servidor.

# Configura la salida inmediata ante cualquier error detectado durante la ejecución.
# 'set -e' detiene el script si un comando devuelve un código de salida distinto de cero.
set -e

# Inicia el proceso de recolección de archivos estáticos (CSS, JS, imágenes).
# 'python manage.py collectstatic --no-input' compila los activos en la ruta definida en STATIC_ROOT.
# El flag '--no-input' omite confirmaciones interactivas, vital para entornos de contenedores.
echo "Recopilando archivos estáticos para el servidor..."
python manage.py collectstatic --no-input

# Bloque de decisión para la estrategia de migración.
#
# Problema: El script SQL V1__Initial_Schema.sql crea TODAS las tablas (aplicación + Django)
# antes de que Django arranque. Si Django ejecuta 'migrate' normal, intentará crear esas
# tablas de nuevo y fallará con 'relation already exists'.
#
# Solución: Detección de primer arranque.
#   - Se comprueba si la tabla 'django_migrations' tiene registros.
#   - Si no tiene (primer arranque), se ejecuta 'migrate --fake' para registrar
#     todas las migraciones como aplicadas sin ejecutar DDL.
#     Después se ejecuta un script Python que fuerza la creación de los registros
#     internos de Django (content types y permissions) que 'post_migrate' normalmente
#     crearía pero que 'migrate --fake' omite.
#   - Si tiene registros (arranques posteriores), se ejecuta 'migrate' normal.

MIGRATION_COUNT=$(python -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()
from django.db import connection
cursor = connection.cursor()
try:
    cursor.execute('SELECT COUNT(*) FROM django_migrations')
    print(cursor.fetchone()[0])
except Exception:
    print('0')
" 2>/dev/null)

if [ "$MIGRATION_COUNT" = "0" ]; then
    # Primer arranque: TODAS las tablas fueron creadas por V1__Initial_Schema.sql.
    # Se usa '--fake' para registrar las migraciones sin ejecutar DDL.
    echo "Primer arranque detectado. Registrando migraciones existentes (--fake)..."
    python manage.py migrate --fake --no-input

    # Forzar la creación de content types y permissions.
    # 'migrate --fake' no dispara la lógica de post_migrate que crea estos registros.
    # Este script los crea manualmente para que el sistema de permisos de Django funcione.
    echo "Poblando tablas internas de Django (content types y permissions)..."
    python -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

# Crear todos los content types para cada modelo registrado en las apps instaladas.
from django.contrib.contenttypes.management import create_contenttypes
from django.apps import apps
for app_config in apps.get_app_configs():
    create_contenttypes(app_config, verbosity=0)

# Crear todos los permissions para cada modelo registrado.
from django.contrib.auth.management import create_permissions
for app_config in apps.get_app_configs():
    create_permissions(app_config, verbosity=0)

print('Content types y permissions creados correctamente.')
"
else
    # Arranque posterior: las migraciones previas ya están registradas.
    # Se aplican solo las migraciones nuevas de forma estándar.
    echo "Ejecutando migraciones de base de datos pendientes..."
    python manage.py migrate --no-input
fi

# Traspasa el control de ejecución al comando principal definido en el Dockerfile o docker-compose.
# 'exec "$@"' reemplaza el proceso actual (shell) por el comando especificado (ej. Gunicorn).
# Esto mantiene el ID de proceso 1 (PID 1), permitiendo que Docker gestione señales de apagado correctamente.
echo "Iniciando proceso principal del servidor de aplicaciones..."
exec "$@"
