# Track Specification: Core Identity System and Multi-tenancy Isolation

## Goal

Implement the foundational identity and access control system for Schooledule, ensuring multi-tenant isolation and dynamic role selection.

## Scope

- **Custom User Model:** Implement a Django custom user model that aligns with the existing `usuarios` table in PostgreSQL.
- **Role Management:** Implement `ROLE_ADMIN`, `ROLE_PROFESOR`, and `ROLE_ALUMNO` using Django's group/permission system or a custom mapping.
- **Multi-tenancy:** Integrate the `Centros` (schools) entity and ensure all data is scoped to a specific center.
- **Dynamic Role Selection:** Create a login flow where users with multiple roles must select their active role for the session.
- **Data Isolation:** Implement initial Row-Level Security (RLS) or application-level filtering to ensure data isolation.

## Technical Details

- **Framework:** Django 4.2+.
- **Database:** PostgreSQL with existing schema (`usuarios`, `roles`, `usuarios_roles`, `centros`).
- **Auth:** `AbstractBaseUser` with email/username authentication.
- **Session:** Store the "active role" and "active centro" in the Django session.

## Acceptance Criteria

- Users can log in with their unique identity.
- Users with multiple roles are prompted to select one after login.
- Access to resources is strictly limited based on the active role and centro.
- Database queries are automatically filtered by `centro_id` where applicable.
- All grade changes are audited (using the existing triggers).
