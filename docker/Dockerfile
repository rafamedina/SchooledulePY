# Etapa 1: Base - Define el entorno compartido y el usuario restringido.
# Utiliza la imagen oficial de Python 3.12 basada en Debian Bookworm Slim para minimizar el tamaño.
FROM python:3.12-slim-bookworm AS base

# Configuración de variables de entorno críticas.
# PYTHONDONTWRITEBYTECODE=1 evita la generación de archivos .pyc en el contenedor.
# PYTHONUNBUFFERED=1 asegura que los logs se emitan en tiempo real sin almacenamiento intermedio.
# PYTHONPATH=/app define la raíz del proyecto para la resolución de módulos internos.
# PATH="/opt/venv/bin:$PATH" prioriza los binarios del entorno virtual sobre los del sistema.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    PATH="/opt/venv/bin:$PATH"

# Creación del grupo y usuario 'django' para la ejecución del servicio.
# Se utiliza el flag -r para crear una cuenta de sistema sin directorio home propio.
# Esto reduce la superficie de ataque al no utilizar el usuario root por defecto.
RUN groupadd -r django && useradd -r -g django django

# Etapa 2: Builder - Gestión de compilación y dependencias pesadas.
# Esta capa se descarta tras la construcción para no inflar la imagen final.
FROM base AS builder

# Instalación de herramientas de compilación necesarias para paquetes Python.
# build-essential incluye gcc y herramientas de enlace requeridas por psycopg2.
# libpq-dev proporciona las cabeceras de desarrollo de PostgreSQL.
# python3-dev es necesario para compilar extensiones de lenguaje C.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Inicialización del entorno virtual de Python en un directorio dedicado.
# Esto aísla las librerías del proyecto de las librerías del sistema operativo.
RUN python -m venv /opt/venv

# Transferencia del manifiesto de dependencias al constructor.
COPY requirements.txt .

# Actualización de pip e instalación de las dependencias definidas.
# --no-cache-dir evita el almacenamiento de binarios temporales, optimizando espacio.
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Etapa 3: Final - Imagen de ejecución optimizada.
# Hereda de la base para mantener la configuración de usuario y variables.
FROM base AS final

# Instalación de librerías de enlace dinámico requeridas en tiempo de ejecución.
# libpq5 es la librería cliente de PostgreSQL necesaria para la comunicación con la base de datos.
# curl se incluye para permitir la ejecución de los Healthchecks configurados.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Definición del directorio de trabajo principal dentro del contenedor.
WORKDIR /app

# Extracción selectiva del entorno virtual desde la etapa de construcción.
# Esto permite que la imagen final no contenga compiladores ni herramientas innecesarias.
COPY --from=builder /opt/venv /opt/venv

# Transferencia del código fuente desde la carpeta src local al contenedor.
# Se asigna la propiedad al usuario 'django' para permitir el acceso a archivos.
COPY --chown=django:django src/ .

# Transferencia de scripts de infraestructura de Docker.
# Se asegura que los scripts de arranque residan en la ruta esperada por la configuración.
COPY --chown=django:django docker/ /app/docker/

# Asignación de permisos de ejecución al script de entrada (entrypoint).
# Esto es vital para que Docker pueda iniciar el proceso de orquestación definido.
RUN chmod +x /app/docker/entrypoint.sh

# Creación de directorios de salida para archivos estáticos y media.
# STATIC_ROOT en settings.py se resuelve a /staticfiles (BASE_DIR.parent / "staticfiles").
# Sin este paso, el usuario 'django' no puede escribir en la raíz del filesystem.
RUN mkdir -p /staticfiles /app/media \
    && chown -R django:django /staticfiles /app/media

# Cambio al contexto de ejecución del usuario sin privilegios.
# A partir de esta línea, los procesos no tienen permisos de administración del sistema.
USER django

# Declaración del puerto de red interno que utilizará el servidor Gunicorn.
EXPOSE 8000

# Definición del script de entrada que gestionará migraciones y archivos estáticos.
# Este script se ejecuta cada vez que el contenedor inicia su ciclo de vida.
ENTRYPOINT ["/app/docker/entrypoint.sh"]

# Comando por defecto para iniciar el servidor de aplicaciones WSGI.
# Se utiliza Gunicorn con 3 procesos trabajadores vinculados a todas las interfaces en el puerto 8000.
# 'config.wsgi:application' referencia el punto de entrada de la aplicación Django.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "config.wsgi:application"]

# Mecanismo de monitorización de salud del contenedor.
# Realiza una petición local cada 30 segundos para verificar la respuesta del servidor.
# Un fallo persistente activará el estado 'unhealthy' en la orquestación.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health/ || exit 1
