# Tech Stack - Schooledule

## Frontend & UI

- **Framework:** Django Templates (Server-Side Rendering).
- **Interactivity:** **HTMX** for modern, asynchronous UI patterns (AJAX) without heavy JavaScript frameworks.
- **Styling:** **Bootstrap 5** (or latest) for responsive layout and standardized administrative components.
- **Icons:** Bootstrap Icons or FontAwesome.

## Database

- **Engine:** PostgreSQL 14+ (as the central "brain" of the ecosystem).
- **Features:** Optimized relational schema with Row-Level Security (RLS) support and custom triggers for auditing.

## Security & Identity

- **Authentication:** Django's built-in authentication system with a custom `User` model.
- **Authorization:** Role-Based Access Control (RBAC) with groups and permissions mapped to `ADMIN`, `PROFESOR`, and `ALUMNO`.
- **Session Management:** Standard Django session middleware.

## Development & Deployment

- **Language:** Python 3.10+.
- **Database Driver:** `psycopg2-binary`.
- **Static Assets:** Django's built-in static file management.
