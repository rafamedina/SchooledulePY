# Arquitectura e Infraestructura de Schooledule

Este documento describe la lógica de diseño y la implementación técnica del entorno de ejecución de Schooledule. Se centra en la justificación de la infraestructura basada en contenedores y la seguridad del sistema.

## 1. Estrategia de Contenedores

El proyecto emplea una arquitectura de contenedores inmutables. Este método garantiza la paridad entre los entornos de desarrollo y producción. La infraestructura se define mediante código para asegurar la reproducibilidad total del sistema.

## 2. Implementación de Docker y Construcción Multietapa

El servidor de aplicaciones web utiliza un proceso de construcción dividido en tres fases funcionales. Este diseño separa las herramientas de compilación del entorno de ejecución final.

### Fase 1: Base (Entorno Común)

Utiliza la imagen oficial Python 3.12 basada en Debian Bookworm Slim. Esta elección equilibra la compatibilidad de librerías con un tamaño de disco reducido. Define las variables de entorno de sistema. Establece la identidad del usuario django. Este usuario carece de privilegios administrativos para limitar el alcance de posibles brechas de seguridad.

### Fase 2: Builder (Gestión de Artefactos)

Instala las cabeceras de desarrollo de PostgreSQL y compiladores de C. Crea un entorno virtual aislado en la ruta /opt/venv. Instala las dependencias especificadas en requirements.txt dentro de este entorno. Esta fase se descarta una vez finalizada la construcción. Los compiladores y archivos temporales de instalación no forman parte de la imagen de producción.

### Fase 3: Final (Entorno de Producción)

Hereda únicamente la configuración base y el entorno virtual generado en la fase anterior. Integra el código fuente de la carpeta src. Configura el script de entrada entrypoint.sh. La imagen resultante contiene exclusivamente los binarios necesarios para ejecutar Django y Gunicorn. Este enfoque reduce la superficie de ataque al eliminar herramientas que un atacante podría utilizar tras una intrusión.

## 3. Orquestación y Redes

Docker Compose gestiona la interconexión de los servicios definidos en el ecosistema.

- Aislamiento de Red: El sistema implementa una red backend privada. El servicio de base de datos PostgreSQL solo acepta conexiones provenientes del contenedor web. No existe exposición de la base de datos hacia el exterior del entorno Docker.
- Persistencia de Datos: Utiliza volúmenes con nombre para los datos de PostgreSQL y archivos estáticos. Los datos persisten independientemente del estado de los contenedores.
- Monitorización de Salud: El sistema ejecuta comprobaciones automáticas de estado. El contenedor web solo se considera operativo si el servicio de base de datos responde positivamente a la herramienta pg_isready.

## 4. Orquestación Interna (Entrypoint)

El script entrypoint.sh coordina las tareas críticas antes de ceder el control al servidor de aplicaciones. Realiza la migración automática del esquema de base de datos. Recopila los activos estáticos para su servicio eficiente. Utiliza la instrucción exec para asegurar que Gunicorn tome el control total del proceso. Esto permite que el sistema de orquestación de Docker gestione las señales de apagado de forma correcta.
