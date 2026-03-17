# Initial Concept

"Schooledule" is a comprehensive platform designed to digitize and orchestrate the entire academic and administrative management of an educational center. Its fundamental purpose is to establish a unified and secure environment that connects management, teachers, and students, ensuring that information flows in a controlled and structured manner.

The central "brain" and single source of truth for this entire ecosystem is a PostgreSQL database.

Main functionalities:

1. **Intelligent Access and Multi-tenancy System:** Unified identity (one email/password) with multiple simultaneous roles (e.g., Administrator and Teacher). Selection of context at login to isolate privileges and dynamic interface.
2. **Functional Profiles and Data Isolation:** Strict isolation where teachers only see their students, students only see their grades, and administrators orchestrate everything.
3. **Automation and Intelligent Assistance:** Asynchronous notifications for database state changes and an AI-driven student assistant for humanized responses based on PostgreSQL data.

---

# Product Definition - Schooledule

## Vision

Schooledule is a unified platform for digitalizing and orchestrating academic and administrative management in educational centers. It serves as a secure bridge between administration, faculty, and students, with a PostgreSQL database acting as the single source of truth.

## Target Users

- **Administrators (Dirección/Jefatura):** Manage infrastructure, users, enrollments, and course structures.
- **Teachers (Profesorado):** Manage grades, course content, and student interactions within their specific jurisdiction.
- **Students (Alumnado):** Access personal schedules, grades, and academic summaries.

## Core Features (MVP Priority: Identity & Access)

- **Unified Identity System:** One set of credentials for all roles.
- **Dynamic Context Selection:** Users with multiple roles (e.g., Teacher and Student) must select their active role upon login to isolate privileges.
- **Data Isolation:** Structural "firewalls" in the database ensure teachers only see their assigned courses and students only see their own data.
- **Academic Management:** Full lifecycle management from "Cursos Académicos" and "Módulos" to "Resultados de Aprendizaje" and "Criterios de Evaluación".
- **Advanced Grading & Auditing:** Comprehensive grading system with periods, items, and a forensically-sound audit trail for grade modifications.

## Intelligent Notifications

- **Grade Alerts:** Immediate notification when new grades are published.
- **Schedule Changes:** Real-time updates for weekly schedule modifications.
- **Administrative Deadlines:** Automated reminders for upcoming tasks.

## Technical Foundation

- **Framework:** Django (Python) for full-stack development.
- **Database:** PostgreSQL with a relational schema optimized for RLS (Row-Level Security) and auditing triggers.
- **Security:** Django's built-in authentication system with custom user models and role-based access control (RBAC).
