#!/bin/sh
# Script de entrada para la orquestación de servicios Django dentro del contenedor Docker.

# Configura la salida inmediata ante cualquier error detectado durante la ejecución.
# 'set -e' detiene el script si un comando devuelve un código de salida distinto de cero.
set -e

# Inicia el proceso de recolección de archivos estáticos (CSS, JS, imágenes).
# 'python manage.py collectstatic --no-input' compila los activos en la ruta definida en STATIC_ROOT.
# El flag '--no-input' omite confirmaciones interactivas, vital para entornos de contenedores.
echo "Recopilando archivos estáticos para el servidor..."
python manage.py collectstatic --no-input

# Inicia la sincronización del esquema de la base de datos PostgreSQL.
# 'python manage.py migrate --no-input' aplica las migraciones pendientes detectadas.
# Esto asegura que la base de datos esté alineada con los modelos definidos en el código fuente.
echo "Ejecutando migraciones de base de datos pendientes..."
python manage.py migrate --no-input

# Traspasa el control de ejecución al comando principal definido en el Dockerfile o docker-compose.
# 'exec "$@"' reemplaza el proceso actual (shell) por el comando especificado (ej. Gunicorn).
# Esto mantiene el ID de proceso 1 (PID 1), permitiendo que Docker gestione señales de apagado correctamente.
echo "Iniciando proceso principal del servidor de aplicaciones..."
exec "$@"
