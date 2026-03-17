# Guía de Comandos Útiles - Schooledule

Este documento registra los comandos esenciales para la gestión, desarrollo y verificación del proyecto. Cada bloque incluye la descripción de su funcionalidad y el contexto de ejecución requerido.

## 1. Gestión de Infraestructura (Docker Compose)

Estos comandos deben ejecutarse desde la raíz del proyecto, donde reside el archivo `docker-compose.yml`.

### Construir e Iniciar el Entorno

Compila las imágenes personalizadas y levanta los servicios de base de datos y aplicación en segundo plano.

```bash
# --build asegura que se procesen cambios en el Dockerfile o requirements.txt.
# -d (detached) libera la terminal tras el arranque exitoso.
docker-compose up --build -d
```

### Detener los Servicios

Cesa la ejecución de los contenedores sin eliminar los volúmenes de datos persistentes.

```bash
# Detiene y elimina los contenedores y redes virtuales creadas.
docker-compose down
```

### Ver Logs en Tiempo Real

Permite monitorizar la salida estándar del servidor de aplicaciones para depuración.

```bash
# -f (follow) mantiene la salida abierta para ver nuevos eventos.
docker-compose logs -f web
```

---

## 2. Operaciones de Django (Dentro del Contenedor)

Para ejecutar comandos de Django, es necesario interactuar con el contenedor `schooledule-web`.

### Ejecutar Migraciones Manualmente

Aunque el `entrypoint.sh` lo hace automáticamente, a veces es necesario forzarlas o revisar el estado.

```bash
# 'exec' ejecuta el comando en el contenedor que ya está corriendo.
docker-compose exec web python manage.py migrate
```

### Crear Nuevas Migraciones

Genera los archivos de migración tras modificar los modelos en el código fuente.

```bash
# Escanea los cambios en models.py y genera los scripts en la carpeta migrations.
docker-compose exec web python manage.py makemigrations
```

### Crear Superusuario

Permite acceder al panel de administración de Django (`/admin`).

```bash
# Iniciará un proceso interactivo para definir username, email y password.
docker-compose exec web python manage.py createsuperuser
```

---

## 3. Calidad y Pruebas (Testing)

Comandos destinados a garantizar la integridad y el cumplimiento de los estándares del proyecto.

### Ejecutar Suite de Pruebas

Lanza todos los tests definidos en el directorio `src`.

```bash
# Django creará una base de datos temporal para las pruebas y la destruirá al finalizar.
docker-compose exec web python manage.py test
```

### Ejecutar Tests con Cobertura

Verifica qué porcentaje del código fuente está cubierto por las pruebas unitarias.

```bash
# Requiere la librería 'coverage' (incluida en el flujo de trabajo estándar).
docker-compose exec web coverage run manage.py test
docker-compose exec web coverage report
```

### Verificación de Estilo (Linting)

Asegura que el código cumple con las guías de estilo definidas.

```bash
# Ejecuta ruff para análisis estático y formateo.
docker-compose exec web ruff check .
```

---

## 4. Acceso Directo a Base de Datos (PostgreSQL)

Interacción directa con el "cerebro" del sistema.

### Terminal de PostgreSQL (psql)

Accede a la consola interactiva de la base de datos para ejecutar consultas SQL manuales.

```bash
# Se conecta al contenedor de la base de datos con el usuario definido en el .env.
docker-compose exec db psql -U postgres -d schooledule
```
