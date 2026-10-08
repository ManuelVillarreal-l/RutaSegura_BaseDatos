# RutaSegura — Database

PostgreSQL database of RutaSegura, the smart rural school transport system.

This repository holds the SQL that defines and documents the database used by the
[RutaSegura API](https://rutasegura-api-g7n4.onrender.com/docs). The database itself is
hosted on Render (PostgreSQL 16).

## Contents
```
sql/
  01_schema.sql     Tables, primary/foreign keys, CHECK constraints and indexes
  02_seed.sql       Demo data: users, routes, stops, students, trips and attendance
  03_views.sql      Reporting views (trip summary, student status, daily attendance)
  04_queries.sql    Example queries for reports (read-only)
docs/
  er_diagram.png    Entity-relationship diagram
  er_diagram.mmd    Diagram source (Mermaid)
apply_database.py   Runs the scripts against any PostgreSQL database
requirements.txt
```

## Entity-relationship diagram
![ER diagram](docs/er_diagram.png)

| Table | Purpose |
|---|---|
| `users` | Everyone who logs in: coordinators, drivers, monitors and guardians |
| `routes` | School bus routes |
| `stops` | Ordered stops of each route, with GPS coordinates |
| `students` | Students with a unique QR code, their guardian, route and pickup stop |
| `trips` | One run of a route by a driver (`scheduled` → `in_progress` → `finished`) |
| `attendance` | Boarding / drop-off events of each student on a trip |

### Integrity rules
- `role` ∈ {`guardian`, `driver`, `monitor`, `coordinator`}
- `trips.status` ∈ {`scheduled`, `in_progress`, `finished`}, and `finished_at ≥ started_at`
- `attendance.event_type` ∈ {`boarding`, `drop_off`}, `method` ∈ {`qr`, `manual`}
- Unique e-mail (lowercase), unique QR code, unique route name, unique stop order per route
- Latitude between −90 and 90, longitude between −180 and 180
- Deleting a route deletes its stops; deleting a student deletes its attendance history
- All timestamps are stored in UTC; the views convert them to Colombia time (`America/Bogota`)

## Views
| View | Shows |
|---|---|
| `v_route_overview` | Each route with its number of stops and students |
| `v_trip_summary` | Each trip with route, driver, duration, boardings and drop-offs |
| `v_student_last_status` | The latest event of every student (on the bus, at school, no record) |
| `v_daily_attendance` | Per day and route: students boarded vs. assigned (attendance rate) |

## How to apply the scripts
Requires Python 3.11+.

```bash
pip install -r requirements.txt

# Create tables + demo data + views (asks for confirmation: it drops existing tables)
python apply_database.py "postgresql://USER:PASSWORD@HOST/DATABASE"

# Run the example queries (read-only)
python apply_database.py "postgresql://USER:PASSWORD@HOST/DATABASE" --queries
```

On Render, use the **External Database URL** of `rutasegura-db`
(Dashboard → `rutasegura-db` → **Connect** → **External**).

The scripts can also be run with `psql -f sql/01_schema.sql` (and so on) or pasted into any
PostgreSQL client such as pgAdmin or DBeaver.

## Demo users
| Role | E-mail | Password |
|---|---|---|
| coordinator | admin@rutasegura.com | Admin123* |
| driver | conductor@rutasegura.com | Conductor123* |
| driver | conductor2@rutasegura.com | Conductor123* |
| monitor | monitor@rutasegura.com | Monitor123* |
| guardian | acudiente@rutasegura.com | Acudiente123* |
| guardian | acudiente2@rutasegura.com | Acudiente123* |
| guardian | acudiente3@rutasegura.com | Acudiente123* |

## Related repositories
- Backend (API): FastAPI — creates the same tables automatically if they do not exist
- Frontend: React + TypeScript web application



