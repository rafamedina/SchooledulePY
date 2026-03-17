# Script de automatización para la ejecución de pruebas en el entorno local de desarrollo.
# Este script asegura que las pruebas se conecten al servidor PostgreSQL de la máquina host.

# Establece la variable de entorno DB_HOST a 'localhost'.
# Esta configuración tiene prioridad sobre el archivo .env gracias a python-decouple.
# Permite que pytest encuentre la base de datos fuera de la red aislada de Docker.
$env:DB_HOST = "localhost"

# Activa el entorno virtual (.venv) para cargar las librerías necesarias (Django, pytest, etc.).
# El operador '&' ejecuta el script de activación en el contexto actual de la sesión.
& .venv\Scripts\Activate.ps1

# Invoca el motor de pruebas pytest sobre el directorio de tests del código fuente.
# La configuración de Django y los patrones de búsqueda se extraen del archivo pytest.ini.
pytest src/tests/
