-- =====================================================================
-- RutaSegura - Database schema (PostgreSQL)
-- File 01: tables, keys, constraints and indexes.
--
-- WARNING: this script DROPS the existing tables and recreates them.
-- All data in these tables is deleted. Run 02_seed.sql afterwards.
--
-- The table and column names match the backend models (app/models.py),
-- so the API works on top of this schema without any change.
-- =====================================================================

BEGIN;

-- Drop in reverse dependency order.
DROP VIEW IF EXISTS v_trip_summary CASCADE;
DROP VIEW IF EXISTS v_student_last_status CASCADE;
DROP VIEW IF EXISTS v_daily_attendance CASCADE;
DROP VIEW IF EXISTS v_route_overview CASCADE;

DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS trips CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS stops CASCADE;
DROP TABLE IF EXISTS routes CASCADE;
DROP TABLE IF EXISTS users CASCADE;


-- ---------------------------------------------------------------------
-- users: everyone who logs in (coordinators, drivers, monitors, guardians)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(120) NOT NULL,
    email         VARCHAR(180) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(30)  NOT NULL DEFAULT 'guardian',
    active        BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT ck_users_role
        CHECK (role IN ('guardian', 'driver', 'monitor', 'coordinator')),
    CONSTRAINT ck_users_email_lowercase
        CHECK (email = LOWER(email)),
    CONSTRAINT ck_users_email_format
        CHECK (email LIKE '%_@_%._%')
);

CREATE UNIQUE INDEX ix_users_email ON users (email);
CREATE INDEX ix_users_role ON users (role);


-- ---------------------------------------------------------------------
-- routes: school bus routes
-- ---------------------------------------------------------------------
CREATE TABLE routes (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(120) NOT NULL,
    description TEXT,
    active      BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT routes_name_key UNIQUE (name)
);


-- ---------------------------------------------------------------------
-- stops: ordered stops of each route (with GPS coordinates)
-- ---------------------------------------------------------------------
CREATE TABLE stops (
    id        SERIAL PRIMARY KEY,
    route_id  INTEGER NOT NULL REFERENCES routes (id) ON DELETE CASCADE,
    name      VARCHAR(150) NOT NULL,
    "order"   INTEGER NOT NULL,
    latitude  DOUBLE PRECISION,
    longitude DOUBLE PRECISION,

    CONSTRAINT ck_stops_order_positive CHECK ("order" > 0),
    CONSTRAINT ck_stops_latitude  CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_stops_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    CONSTRAINT uq_stops_route_order UNIQUE (route_id, "order")
);

CREATE INDEX ix_stops_route_id ON stops (route_id);


-- ---------------------------------------------------------------------
-- students: each student has a unique QR code, a guardian, a route and a stop
-- ---------------------------------------------------------------------
CREATE TABLE students (
    id          SERIAL PRIMARY KEY,
    full_name   VARCHAR(150) NOT NULL,
    grade       VARCHAR(50)  NOT NULL,
    school      VARCHAR(150) NOT NULL,
    qr_code     VARCHAR(80)  NOT NULL,
    guardian_id INTEGER REFERENCES users (id)  ON DELETE SET NULL,
    route_id    INTEGER REFERENCES routes (id) ON DELETE SET NULL,
    stop_id     INTEGER REFERENCES stops (id)  ON DELETE SET NULL,
    active      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE UNIQUE INDEX ix_students_qr_code ON students (qr_code);
CREATE INDEX ix_students_guardian_id ON students (guardian_id);
CREATE INDEX ix_students_route_id ON students (route_id);


-- ---------------------------------------------------------------------
-- trips: one run of a route by a driver (times stored in UTC)
-- ---------------------------------------------------------------------
CREATE TABLE trips (
    id          SERIAL PRIMARY KEY,
    route_id    INTEGER NOT NULL REFERENCES routes (id),
    driver_id   INTEGER REFERENCES users (id) ON DELETE SET NULL,
    status      VARCHAR(30) NOT NULL DEFAULT 'scheduled',
    started_at  TIMESTAMP,
    finished_at TIMESTAMP,

    CONSTRAINT ck_trips_status
        CHECK (status IN ('scheduled', 'in_progress', 'finished')),
    CONSTRAINT ck_trips_finish_after_start
        CHECK (finished_at IS NULL OR started_at IS NULL OR finished_at >= started_at)
);

CREATE INDEX ix_trips_route_id ON trips (route_id);
CREATE INDEX ix_trips_status ON trips (status);


-- ---------------------------------------------------------------------
-- attendance: boarding / drop-off events (times stored in UTC)
-- ---------------------------------------------------------------------
CREATE TABLE attendance (
    id         SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students (id) ON DELETE CASCADE,
    trip_id    INTEGER NOT NULL REFERENCES trips (id)    ON DELETE CASCADE,
    stop_id    INTEGER REFERENCES stops (id) ON DELETE SET NULL,
    event_type VARCHAR(20) NOT NULL,
    "timestamp" TIMESTAMP  NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC'),
    method     VARCHAR(30) NOT NULL DEFAULT 'qr',

    CONSTRAINT ck_attendance_event_type CHECK (event_type IN ('boarding', 'drop_off')),
    CONSTRAINT ck_attendance_method     CHECK (method IN ('qr', 'manual'))
);

CREATE INDEX ix_attendance_student_time ON attendance (student_id, "timestamp" DESC);
CREATE INDEX ix_attendance_trip_id ON attendance (trip_id);

COMMIT;



