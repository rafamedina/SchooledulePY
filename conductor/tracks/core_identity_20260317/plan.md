# Implementation Plan: Core Identity System and Multi-tenancy Isolation

## Phase 1: Project Initialization & Database Setup

- [ ] Task: Initialize Django project and connect to PostgreSQL
  - [ ] Write Tests (TDD): Create `tests/test_db_connection.py` using `pytest`. Verify database connection and schema access.
  - [ ] Implement: Set up Django project in `src/`, configure `DATABASES`, and run initial inspection/migrations.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Project Initialization & Database Setup' (Protocol in workflow.md)

## Phase 2: Core Identity & Custom User Model

- [ ] Task: Implement Custom User Model
  - [ ] Write Tests (TDD): Use `pytest` and `factory_boy` to verify user creation, authentication, and fields.
  - [ ] Implement: Create `CustomUser` model inheriting from `AbstractBaseUser` and `PermissionsMixin`.
- [ ] Task: Implement Role Mapping
  - [ ] Write Tests: Verify roles `ROLE_ADMIN`, `ROLE_PROFESOR`, `ROLE_ALUMNO` are correctly assigned to users
  - [ ] Implement: Map Django Groups to the existing `roles` table and implement the many-to-many relationship
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Core Identity & Custom User Model' (Protocol in workflow.md)

## Phase 3: Multi-tenancy & Role Selection

- [ ] Task: Implement Multi-tenancy (Centros)
  - [ ] Write Tests: Verify that users are associated with one or more `Centros`
  - [ ] Implement: Integrate `Centros` model and create the relationship with `CustomUser`
- [ ] Task: Implement Dynamic Role and Centro Selection
  - [ ] Write Tests: Verify that users are redirected to a selection page if they have multiple roles/centros
  - [ ] Implement: Create selection view and middleware to store active role/centro in session
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Multi-tenancy & Role Selection' (Protocol in workflow.md)

## Phase 4: Data Isolation & Security

- [ ] Task: Implement Application-Level Data Isolation
  - [ ] Write Tests: Verify that queries for `Modulos` or `Grupos` are filtered by the active `centro_id`
  - [ ] Implement: Create a base manager or middleware to automatically filter queries by `centro_id`
- [ ] Task: Verify Database Triggers and Auditing
  - [ ] Write Tests: Verify that the `trigger_auditoria_notas` correctly records changes in `calificaciones`
  - [ ] Implement: Ensure Django operations trigger the existing PostgreSQL audit logic
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Data Isolation & Security' (Protocol in workflow.md)
