# RutaSegura — Database

PostgreSQL database of RutaSegura, the smart rural school transport system.

This repository holds the SQL that defines and documents the database used by the
[RutaSegura API](https://rutasegura-api-g7n4.onrender.com/docs). The database itself is
hosted on Render (PostgreSQL 16). **28 tables**, 7 reporting views and 15 example queries.

## Contents
```
sql/
  01_schema.sql     28 tables: primary/foreign keys, UNIQUE, CHECK constraints and indexes
  02_seed.sql       Demo data: catalogs, school, users, routes, students and 3 weeks of history
  03_views.sql      Reporting views
  04_queries.sql    Example queries for reports and the presentation (read-only)
docs/
  er_diagram.png    Entity-relationship diagram
  er_diagram.mmd    Diagram source (Mermaid)
apply_database.py   Runs the scripts against any PostgreSQL database
requirements.txt
```

`01_schema.sql`, `02_seed.sql` and the diagram are generated from the backend models
(`app/models.py`) and seed (`app/seed.py`), so the database and the API always match.

## Entity-relationship diagram
![ER diagram](docs/er_diagram.png)

### Tables
| Group | Table | Purpose |
|---|---|---|
| Catalogs | `roles` | User roles (coordinator, driver, monitor, guardian), related to `users.role_id` |
| | `document_types` | CC, TI, RC, CE |
| | `relationships` | Kinship between guardian and student |
| | `grades` | Transition to eleventh grade, in order |
| | `trip_statuses` | Scheduled, in progress, finished |
| | `event_types` | Boarding, drop-off |
| | `check_in_methods` | QR code or manual |
| | `weather_conditions` | Weather states, the delay minutes they add and their Open-Meteo codes |
| | `road_conditions` | Road states and the delay minutes they add |
| | `incident_types` | Incident types with severity 1–3 |
| Organization | `schools` | Rural educational institution (DANE code) |
| | `campuses` | Campuses with GPS position |
| | `vehicles` | Buses: plate, brand, model year, capacity |
| People | `users` | Everyone who logs in. Password stored only as a one-way hash |
| | `drivers` | Driver license (number, category, expiry) and assigned vehicle |
| | `student_guardians` | Many-to-many: a student can have up to 4 guardians, one primary |
| Routes | `routes` | School routes with campus and vehicle |
| | `stops` | Ordered stops with GPS coordinates |
| | `route_segments` | Roads between stops (distance and minutes): edges of the route graph |
| Students | `students` | Document, grade, campus, route, stop and unique QR code |
| Operation | `trips` | A run of a route: driver, monitor, vehicle, status, weather, road, direction |
| | `attendance` | Boarding / drop-off events (idempotent with `client_event_id`) |
| | `vehicle_locations` | GPS positions sent by the bus |
| | `incidents` | Incidents reported during a trip |
| Security & AI | `login_attempts` | Login history: an account locks for 15 min after 5 failures |
| | `notifications` | Messages for guardians and coordinators |
| | `delay_predictions` | Delay predictions made by the AI model |
| | `audit_logs` | Who did what and when |

### Weather and road conditions live in the database
They are not hardcoded. To add a new weather state, insert a row (or use the
coordinator's *Catálogos* page in the app):
```sql
INSERT INTO weather_conditions (code, name, delay_minutes, weather_codes, active)
VALUES ('hail', 'Granizo', 12, '77,85,86', true);
```

### Password security
- The browser sends `SHA-256(email:password)`; the real password never travels.
- The database stores `pbkdf2_sha256$310000$salt$hash` of that digest: it cannot be reversed.
- Query 3 in `04_queries.sql` shows what is really stored.

### Integrity rules (CHECK / UNIQUE)
- Unique e-mail, document (type + number), plate, license number, QR code, route name, catalog codes
- Stop order between 1 and 50, unique per route; segments between two different stops
- Latitude between −90 and 90, longitude between −180 and 180
- Delay minutes 0–120, vehicle capacity 1–60, speed 0–200 km/h, incident severity 1–3
- `finished_at ≥ started_at`, trip direction `outbound` or `return`, license category B1–C3
- All timestamps are stored in UTC; the views convert them to Colombia time (`America/Bogota`)

## Views
| View | Shows |
|---|---|
| `v_users_by_role` | Users with the name of their role and document type |
| `v_route_overview` | Each route with campus, bus, stops and students |
| `v_trip_summary` | Each trip with people, weather, road, duration, boardings and drop-offs |
| `v_student_attendance` | Attendance percentage of every student |
| `v_daily_attendance` | Boardings and drop-offs per day |
| `v_open_incidents` | Incidents not resolved yet |
| `v_weather_delay_stats` | Real average duration per weather and road (the AI training data) |

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
(Dashboard → `rutasegura-db` → **Connect** → **External**). Never publish that URL: it
contains the database password.

The demo history is moved automatically so that it always ends on the day the script runs.

## Demo users
| Role | E-mail | Password |
|---|---|---|
| coordinator | admin@rutasegura.com | Admin123* |
| driver | conductor@rutasegura.com · conductor2@ · conductor3@ | Conductor123* |
| monitor | monitor@rutasegura.com · monitor2@ | Monitor123* |
| guardian | acudiente@rutasegura.com · acudiente2@ · acudiente3@ · acudiente4@ | Acudiente123* |

## Related repositories
- Backend (API): FastAPI — creates the same tables automatically if they do not exist
- Frontend: React + TypeScript web application
