-- =====================================================================
-- RutaSegura - Demo data (PostgreSQL)
-- File 02: users, routes, stops, students, trips and attendance history.
-- Run after 01_schema.sql.
--
-- Demo passwords (hashed with PBKDF2-SHA256, same algorithm as the API):
--   coordinator  admin@rutasegura.com        Admin123*
--   driver       conductor@rutasegura.com    Conductor123*
--   driver       conductor2@rutasegura.com   Conductor123*
--   monitor      monitor@rutasegura.com      Monitor123*
--   guardian     acudiente@rutasegura.com    Acudiente123*
--   guardian     acudiente2@rutasegura.com   Acudiente123*
--   guardian     acudiente3@rutasegura.com   Acudiente123*
--
-- Times are stored in UTC. The helper below builds a UTC timestamp from a
-- Colombian local time (America/Bogota) N days ago, so the history always
-- looks recent no matter when the script is run.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.local_time(days_ago INTEGER, local_clock TIME)
RETURNS TIMESTAMP
LANGUAGE sql
AS $$
    SELECT ((((NOW() AT TIME ZONE 'America/Bogota')::date - days_ago) + local_clock)
            AT TIME ZONE 'America/Bogota') AT TIME ZONE 'UTC'
$$;


-- ---------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------
INSERT INTO users (id, name, email, password_hash, role) VALUES
(1, 'Coordinador RutaSegura', 'admin@rutasegura.com',
    'pbkdf2_sha256$310000$789691ef0dc5132770b8928c5a27a2f6$4c17eff4ac60fd3436d6eb0f2a684076fde6aa12ffd508b095d9698fbce96adb', 'coordinator'),
(2, 'Carlos Conductor', 'conductor@rutasegura.com',
    'pbkdf2_sha256$310000$717f825fab0b83fc9881c46b889c7812$28fc2674c281c4b315b91ed2566b30ffbbbb52bcaa001097e86fabd89b794f26', 'driver'),
(3, 'Laura Acudiente', 'acudiente@rutasegura.com',
    'pbkdf2_sha256$310000$abcd80a14e2448393c3ffe2091a1e4d9$00ee4126da8fb1b350598b8927dbe4c7bf96bc3459225a78cc6165a201de9e57', 'guardian'),
(4, 'Pedro Ramírez', 'conductor2@rutasegura.com',
    'pbkdf2_sha256$310000$717f825fab0b83fc9881c46b889c7812$28fc2674c281c4b315b91ed2566b30ffbbbb52bcaa001097e86fabd89b794f26', 'driver'),
(5, 'Marta Gómez', 'monitor@rutasegura.com',
    'pbkdf2_sha256$310000$7cf49f7446455600595ba1264d987e06$a3086f2663922234a035ab7587708c92597a1d9d03e10559b6a09199e0902275', 'monitor'),
(6, 'Rosa Delgado', 'acudiente2@rutasegura.com',
    'pbkdf2_sha256$310000$abcd80a14e2448393c3ffe2091a1e4d9$00ee4126da8fb1b350598b8927dbe4c7bf96bc3459225a78cc6165a201de9e57', 'guardian'),
(7, 'José Benavides', 'acudiente3@rutasegura.com',
    'pbkdf2_sha256$310000$abcd80a14e2448393c3ffe2091a1e4d9$00ee4126da8fb1b350598b8927dbe4c7bf96bc3459225a78cc6165a201de9e57', 'guardian');


-- ---------------------------------------------------------------------
-- Routes and stops (coordinates around Pasto, Nariño)
-- ---------------------------------------------------------------------
INSERT INTO routes (id, name, description) VALUES
(1, 'Ruta Rural 01', 'Veredas cercanas a la institución'),
(2, 'Ruta Rural 02', 'Veredas del sector norte');

INSERT INTO stops (id, route_id, name, "order", latitude, longitude) VALUES
(1, 1, 'Vereda El Encano',      1, 1.145, -77.079),
(2, 1, 'Vereda La Laguna',      2, 1.162, -77.088),
(3, 1, 'Institución Educativa', 3, 1.213, -77.281),
(4, 2, 'Vereda Mapachico',      1, 1.241, -77.298),
(5, 2, 'Vereda Genoy',          2, 1.256, -77.327),
(6, 2, 'Institución Educativa', 3, 1.213, -77.281);


-- ---------------------------------------------------------------------
-- Students
-- ---------------------------------------------------------------------
INSERT INTO students (id, full_name, grade, school, qr_code, guardian_id, route_id, stop_id) VALUES
(1, 'Juan Pérez Demo',     '8°', 'Institución Educativa Rural', 'RS-DEMO-0001', 3, 1, 1),
(2, 'Valentina Pérez',     '5°', 'Institución Educativa Rural', 'RS-DEMO-0002', 3, 1, 2),
(3, 'Santiago Delgado',    '7°', 'Institución Educativa Rural', 'RS-DEMO-0003', 6, 1, 1),
(4, 'Camila Delgado',      '3°', 'Institución Educativa Rural', 'RS-DEMO-0004', 6, 2, 4),
(5, 'Mateo Benavides',     '9°', 'Institución Educativa Rural', 'RS-DEMO-0005', 7, 2, 5),
(6, 'Isabella Benavides',  '6°', 'Institución Educativa Rural', 'RS-DEMO-0006', 7, 2, 4);


-- ---------------------------------------------------------------------
-- Trips: two finished yesterday, two scheduled for today
-- ---------------------------------------------------------------------
INSERT INTO trips (id, route_id, driver_id, status, started_at, finished_at) VALUES
(1, 1, 2, 'finished',  pg_temp.local_time(1, '06:00'), pg_temp.local_time(1, '06:48')),
(2, 2, 4, 'finished',  pg_temp.local_time(1, '06:10'), pg_temp.local_time(1, '07:02')),
(3, 1, 2, 'scheduled', NULL, NULL),
(4, 2, 4, 'scheduled', NULL, NULL);


-- ---------------------------------------------------------------------
-- Attendance history from yesterday's trips.
-- Santiago Delgado (id 3) did not board yesterday (absence example).
-- ---------------------------------------------------------------------
INSERT INTO attendance (student_id, trip_id, stop_id, event_type, method, "timestamp") VALUES
(1, 1, 1, 'boarding', 'qr',     pg_temp.local_time(1, '06:12')),
(2, 1, 2, 'boarding', 'qr',     pg_temp.local_time(1, '06:21')),
(1, 1, 3, 'drop_off', 'qr',     pg_temp.local_time(1, '06:46')),
(2, 1, 3, 'drop_off', 'manual', pg_temp.local_time(1, '06:47')),
(4, 2, 4, 'boarding', 'qr',     pg_temp.local_time(1, '06:18')),
(6, 2, 4, 'boarding', 'qr',     pg_temp.local_time(1, '06:19')),
(5, 2, 5, 'boarding', 'qr',     pg_temp.local_time(1, '06:31')),
(4, 2, 6, 'drop_off', 'qr',     pg_temp.local_time(1, '07:00')),
(6, 2, 6, 'drop_off', 'qr',     pg_temp.local_time(1, '07:00')),
(5, 2, 6, 'drop_off', 'qr',     pg_temp.local_time(1, '07:01'));


-- ---------------------------------------------------------------------
-- Move the id sequences past the inserted rows, so the API can keep
-- creating new records without primary key conflicts.
-- ---------------------------------------------------------------------
SELECT setval('users_id_seq',      (SELECT MAX(id) FROM users));
SELECT setval('routes_id_seq',     (SELECT MAX(id) FROM routes));
SELECT setval('stops_id_seq',      (SELECT MAX(id) FROM stops));
SELECT setval('students_id_seq',   (SELECT MAX(id) FROM students));
SELECT setval('trips_id_seq',      (SELECT MAX(id) FROM trips));
SELECT setval('attendance_id_seq', (SELECT MAX(id) FROM attendance));

COMMIT;
