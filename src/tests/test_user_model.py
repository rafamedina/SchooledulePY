# Módulos para pruebas unitarias y gestión del modelo de usuario
import pytest
from django.contrib.auth import get_user_model
from django.db.utils import IntegrityError
from users.models import Role, Centro

# Obtiene la clase del modelo de usuario configurado (CustomUser)
User = get_user_model()


# Decorador que habilita el acceso a la base de datos para la función de prueba
@pytest.mark.django_db
def test_create_user():
    """
    Verifica que se pueda crear un usuario normal con los campos obligatorios definidos.
    Asegura que la contraseña se almacene de forma segura mediante hashing.
    """
    # Crea una instancia de usuario utilizando el gestor personalizado
    user = User.objects.create_user(
        username="testuser",
        password="testpassword123",
        nombre="Test",
        apellidos="User",
        email="test@example.com",
    )
    # Comprueba que el nombre de usuario sea el correcto
    assert user.username == "testuser"
    # Comprueba que el nombre de pila se haya guardado correctamente
    assert user.nombre == "Test"
    # Verifica que la contraseña no se guarde en texto plano
    assert user.check_password("testpassword123")
    # Comprueba que la representación en cadena sea la esperada
    assert str(user) == "Test User (testuser)"
    # Verifica que no tenga permisos de administrador por defecto
    assert not user.is_staff
    # Verifica que la cuenta esté activa por defecto
    assert user.activo


# Decorador para pruebas de base de datos
@pytest.mark.django_db
def test_create_superuser():
    """
    Verifica que la creación de un superusuario asigne correctamente los privilegios elevados.
    Asegura el acceso al panel de administración (is_staff) y permisos globales (is_superuser).
    """
    # Crea un superusuario con permisos totales
    admin_user = User.objects.create_superuser(
        username="adminuser",
        password="adminpassword123",
        nombre="Admin",
        apellidos="User",
    )
    # Comprueba que el flag is_staff esté activado
    assert admin_user.is_staff
    # Comprueba que el flag is_superuser (PermissionsMixin) esté activado
    assert admin_user.is_superuser
    # Verifica que la cuenta esté marcada como activa
    assert admin_user.activo


# Decorador para pruebas de base de datos
@pytest.mark.django_db
def test_username_uniqueness():
    """
    Verifica que el sistema impida la creación de dos usuarios con el mismo 'username'.
    Garantiza la integridad referencial definida en el esquema de PostgreSQL.
    """
    # Crea el primer usuario
    User.objects.create_user(
        username="unique", password="pw", nombre="N", apellidos="A"
    )
    # Intenta crear un segundo usuario con el mismo identificador
    with pytest.raises(IntegrityError):
        # El intento debe lanzar una excepción de integridad de base de datos
        User.objects.create_user(
            username="unique", password="pw2", nombre="N2", apellidos="A2"
        )


# Decorador para pruebas de base de datos
@pytest.mark.django_db
def test_user_roles_assignment():
    """
    Verifica que un usuario pueda tener múltiples roles asignados simultáneamente.
    Valida la relación N:M a través de la tabla intermedia 'usuarios_roles'.
    """
    # Crea los roles necesarios en la base de datos de pruebas
    rol_admin = Role.objects.create(nombre="ROLE_ADMIN")
    rol_profe = Role.objects.create(nombre="ROLE_PROFESOR")

    # Crea un usuario de prueba
    user = User.objects.create_user(
        username="multirole", password="pw", nombre="M", apellidos="R"
    )

    # Asigna ambos roles al usuario
    user.roles.add(rol_admin)
    user.roles.add(rol_profe)

    # Verifica que el usuario tenga exactamente 2 roles
    assert user.roles.count() == 2
    # Comprueba que los roles asignados sean los correctos
    assert rol_admin in user.roles.all()
    assert rol_profe in user.roles.all()


# Decorador para pruebas de base de datos
@pytest.mark.django_db
def test_user_centros_assignment():
    """
    Verifica que un usuario pueda estar vinculado a múltiples centros educativos.
    Valida la relación N:M mapeada a la tabla 'profesores_sedes'.
    """
    # Crea los centros de prueba
    centro_a = Centro.objects.create(nombre="Centro A", ubicacion="Sede Norte")
    centro_b = Centro.objects.create(nombre="Centro B", ubicacion="Sede Sur")

    # Crea un usuario de prueba (ej. un profesor)
    user = User.objects.create_user(
        username="profe_sedes", password="pw", nombre="P", apellidos="S"
    )

    # Vincula al usuario con ambos centros
    user.centros.add(centro_a)
    user.centros.add(centro_b)

    # Verifica la cantidad de centros asociados
    assert user.centros.count() == 2
    # Comprueba la pertenencia a los centros específicos
    assert centro_a in user.centros.all()
    assert centro_b in user.centros.all()
