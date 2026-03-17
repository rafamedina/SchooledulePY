# Implementation Plan: Core Identity System and Multi-tenancy Isolation

## Phase 1: Project Initialization & Database Setup

- [x] Task: Initialize Django project and connect to PostgreSQL
  - [x] Write Tests (TDD): Create `tests/test_db_connection.py` using `pytest`. Verify database connection and schema access.
  - [x] Implement: Set up Django project in `src/`, configure `DATABASES`, and run initial inspection/migrations.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Project Initialization & Database Setup' (Protocol in workflow.md)

## Phase 2: Core Identity & Custom User Model

- [x] Task: Implement Custom User Model
  - [x] Write Tests (TDD): Use `pytest` and `factory_boy` to verify user creation, authentication, and fields.
  - [x] Implement: Create `CustomUser` model inheriting from `AbstractBaseUser` and `PermissionsMixin`.
- [x] Task: Implement Role Mapping
  - [x] Write Tests: Verify roles `ROLE_ADMIN`, `ROLE_PROFESOR`, `ROLE_ALUMNO` are correctly assigned to users
  - [x] Implement: Map Django Groups to the existing `roles` table and implement the many-to-many relationship
- [x] Task: Conductor - User Manual Verification 'Phase 2: Core Identity & Custom User Model' (Protocol in workflow.md)

## Phase 3: Multi-tenancy & Role Selection

- [x] Task: Implement Multi-tenancy (Centros)
  - [x] Write Tests: Verify that users are associated with one or more `Centros`
  - [x] Implement: Integrate `Centros` model and create the relationship with `CustomUser`
- [x] Task: Implement Dynamic Role and Centro Selection
  - [x] Write Tests: Verify that users are redirected to a selection page if they have multiple roles/centros
  - [x] Implement: Create selection view and middleware to store active role/centro in session
- [x] Task: Conductor - User Manual Verification 'Phase 3: Multi-tenancy & Role Selection' (Protocol in workflow.md)

## Phase 4: Data Isolation & Security

- [x] Task: Implement Application-Level Data Isolation
  - [x] Write Tests: Verify that queries for `Modulos` or `Grupos` are filtered by the active `centro_id`
  - [x] Implement: Create a base manager or middleware to automatically filter queries by `centro_id`
- [x] Task: Verify Database Triggers and Auditing
  - [x] Write Tests: Verify that the `trigger_auditoria_notas` correctly records changes in `calificaciones`
  - [x] Implement: Ensure Django operations trigger the existing PostgreSQL audit logic
- [x] Task: Conductor - User Manual Verification 'Phase 4: Data Isolation & Security' (Protocol in workflow.md)
