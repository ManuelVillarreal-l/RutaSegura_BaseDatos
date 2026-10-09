-- =====================================================================
-- RutaSegura - Database schema (PostgreSQL)
-- File 01: drops and creates the 28 tables with their keys and checks.
-- Generated from the backend models (app/models.py) so both always match.
-- Passwords: only a PBKDF2 hash of the client-side SHA-256 digest is stored.
-- =====================================================================

BEGIN;

DROP VIEW IF EXISTS v_route_overview, v_trip_summary, v_student_attendance, v_daily_attendance,
    v_open_incidents, v_users_by_role, v_weather_delay_stats CASCADE;

DROP TABLE IF EXISTS student_guardians CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS vehicle_locations CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS route_segments CASCADE;
DROP TABLE IF EXISTS incidents CASCADE;
DROP TABLE IF EXISTS delay_predictions CASCADE;
DROP TABLE IF EXISTS trips CASCADE;
DROP TABLE IF EXISTS stops CASCADE;
DROP TABLE IF EXISTS routes CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS login_attempts CASCADE;
DROP TABLE IF EXISTS drivers CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS campuses CASCADE;
DROP TABLE IF EXISTS weather_conditions CASCADE;
DROP TABLE IF EXISTS vehicles CASCADE;
DROP TABLE IF EXISTS trip_statuses CASCADE;
DROP TABLE IF EXISTS schools CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS road_conditions CASCADE;
DROP TABLE IF EXISTS relationships CASCADE;
DROP TABLE IF EXISTS incident_types CASCADE;
DROP TABLE IF EXISTS grades CASCADE;
DROP TABLE IF EXISTS event_types CASCADE;
DROP TABLE IF EXISTS document_types CASCADE;
DROP TABLE IF EXISTS check_in_methods CASCADE;

-- ---------------------------------------------------------------------
-- check_in_methods: catalog - how an event was registered (manual or QR)
-- ---------------------------------------------------------------------
CREATE TABLE check_in_methods (
    id SERIAL NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(60) NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (code)
);

-- ---------------------------------------------------------------------
-- document_types: catalog - identity document types
-- ---------------------------------------------------------------------
CREATE TABLE document_types (
    id SERIAL NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(60) NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (code)
);

-- ---------------------------------------------------------------------
-- event_types: catalog - attendance events (boarding, drop-off)
-- ---------------------------------------------------------------------
CREATE TABLE event_types (
    id SERIAL NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(60) NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (code)
);

-- ---------------------------------------------------------------------
-- grades: catalog - school grades in order
-- ---------------------------------------------------------------------
CREATE TABLE grades (
    sort_order INTEGER NOT NULL,
    id SERIAL NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(60) NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_grades_sort_order CHECK (sort_order BETWEEN 0 AND 13),
    UNIQUE (code)
);

-- ---------------------------------------------------------------------
-- incident_types: catalog - incident types with severity 1-3
-- ---------------------------------------------------------------------
CREATE TABLE incident_types (
    severity INTEGER NOT NULL,
    id SERIAL NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(60) NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_incident_severity CHECK (severity BETWEEN 1 AND 3),
    UNIQUE (code)
);

-- ---------------------------------------------------------------------
-- relationships: catalog - kinship between guardian and student
-- ---------------------------------------------------------------------
CREATE TABLE relationships (
    id SERIAL NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(60) NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (code)
);

-- ---------------------------------------------------------------------
-- road_conditions: catalog - road states and their delay minutes (editable, not hardcoded)
-- ---------------------------------------------------------------------
CREATE TABLE road_conditions (
    delay_minutes INTEGER NOT NULL,
    id SERIAL NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(60) NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_road_delay CHECK (delay_minutes BETWEEN 0 AND 120),
    UNIQUE (code)
);

-- ---------------------------------------------------------------------
-- roles: catalog - user roles, related to users.role_id
-- ---------------------------------------------------------------------
CREATE TABLE roles (
    description VARCHAR(200),
    id SERIAL NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(60) NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (code)
);

-- ---------------------------------------------------------------------
-- schools: rural educational institutions
-- ---------------------------------------------------------------------
CREATE TABLE schools (
    id SERIAL NOT NULL,
    name VARCHAR(120) NOT NULL,
    dane_code VARCHAR(12) NOT NULL,
    municipality VARCHAR(80) NOT NULL,
    phone VARCHAR(10),
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (name),
    UNIQUE (dane_code)
);

-- ---------------------------------------------------------------------
-- trip_statuses: catalog - trip states (scheduled, in progress, finished)
-- ---------------------------------------------------------------------
CREATE TABLE trip_statuses (
    id SERIAL NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(60) NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (code)
);

-- ---------------------------------------------------------------------
-- vehicles: school buses with plate and capacity
-- ---------------------------------------------------------------------
CREATE TABLE vehicles (
    id SERIAL NOT NULL,
    plate VARCHAR(6) NOT NULL,
    brand VARCHAR(40) NOT NULL,
    model_year INTEGER NOT NULL,
    capacity INTEGER NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_vehicles_capacity CHECK (capacity BETWEEN 1 AND 60),
    CONSTRAINT ck_vehicles_year CHECK (model_year BETWEEN 1990 AND 2100),
    UNIQUE (plate)
);

-- ---------------------------------------------------------------------
-- weather_conditions: catalog - weather states, delay minutes and Open-Meteo codes (editable)
-- ---------------------------------------------------------------------
CREATE TABLE weather_conditions (
    delay_minutes INTEGER NOT NULL,
    weather_codes VARCHAR(120),
    id SERIAL NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(60) NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_weather_delay CHECK (delay_minutes BETWEEN 0 AND 120),
    UNIQUE (code)
);

-- ---------------------------------------------------------------------
-- campuses: campuses of each school with GPS position
-- ---------------------------------------------------------------------
CREATE TABLE campuses (
    id SERIAL NOT NULL,
    school_id INTEGER NOT NULL,
    name VARCHAR(120) NOT NULL,
    address VARCHAR(150),
    latitude FLOAT,
    longitude FLOAT,
    PRIMARY KEY (id),
    CONSTRAINT uq_campuses_school_name UNIQUE (school_id, name),
    FOREIGN KEY(school_id) REFERENCES schools (id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- users: system users; role in roles table; password stored only as PBKDF2(SHA-256)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id SERIAL NOT NULL,
    role_id INTEGER NOT NULL,
    document_type_id INTEGER NOT NULL,
    document_number VARCHAR(10) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(120) NOT NULL,
    phone VARCHAR(10) NOT NULL,
    password_hash VARCHAR(200) NOT NULL,
    active BOOLEAN NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    last_login_at TIMESTAMP WITHOUT TIME ZONE,
    PRIMARY KEY (id),
    CONSTRAINT uq_users_document UNIQUE (document_type_id, document_number),
    FOREIGN KEY(role_id) REFERENCES roles (id),
    FOREIGN KEY(document_type_id) REFERENCES document_types (id)
);
CREATE UNIQUE INDEX ix_users_email ON users (email);
CREATE INDEX ix_users_role_id ON users (role_id);

-- ---------------------------------------------------------------------
-- audit_logs: who did what and when
-- ---------------------------------------------------------------------
CREATE TABLE audit_logs (
    id SERIAL NOT NULL,
    user_id INTEGER,
    action VARCHAR(40) NOT NULL,
    entity VARCHAR(40) NOT NULL,
    entity_id INTEGER,
    detail VARCHAR(300),
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE SET NULL
);
CREATE INDEX ix_audit_logs_created ON audit_logs (created_at);

-- ---------------------------------------------------------------------
-- drivers: driver license data linked to a user
-- ---------------------------------------------------------------------
CREATE TABLE drivers (
    id SERIAL NOT NULL,
    user_id INTEGER NOT NULL,
    license_number VARCHAR(12) NOT NULL,
    license_category VARCHAR(2) NOT NULL,
    license_expires_on DATE NOT NULL,
    vehicle_id INTEGER,
    PRIMARY KEY (id),
    CONSTRAINT ck_drivers_category CHECK (license_category IN ('B1','B2','B3','C1','C2','C3')),
    UNIQUE (user_id),
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE,
    UNIQUE (license_number),
    FOREIGN KEY(vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL
);

-- ---------------------------------------------------------------------
-- login_attempts: login history used to lock accounts after 5 failures
-- ---------------------------------------------------------------------
CREATE TABLE login_attempts (
    id SERIAL NOT NULL,
    email VARCHAR(120) NOT NULL,
    user_id INTEGER,
    success BOOLEAN NOT NULL,
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE SET NULL
);
CREATE INDEX ix_login_attempts_email ON login_attempts (email);

-- ---------------------------------------------------------------------
-- notifications: messages for guardians and coordinators
-- ---------------------------------------------------------------------
CREATE TABLE notifications (
    id SERIAL NOT NULL,
    user_id INTEGER NOT NULL,
    kind VARCHAR(30) NOT NULL,
    title VARCHAR(100) NOT NULL,
    message VARCHAR(300) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    read_at TIMESTAMP WITHOUT TIME ZONE,
    PRIMARY KEY (id),
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE INDEX ix_notifications_user_created ON notifications (user_id, created_at);

-- ---------------------------------------------------------------------
-- routes: school routes
-- ---------------------------------------------------------------------
CREATE TABLE routes (
    id SERIAL NOT NULL,
    name VARCHAR(80) NOT NULL,
    description VARCHAR(200),
    campus_id INTEGER NOT NULL,
    vehicle_id INTEGER,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (name),
    FOREIGN KEY(campus_id) REFERENCES campuses (id),
    FOREIGN KEY(vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL
);

-- ---------------------------------------------------------------------
-- stops: ordered stops of a route with GPS coordinates
-- ---------------------------------------------------------------------
CREATE TABLE stops (
    id SERIAL NOT NULL,
    route_id INTEGER NOT NULL,
    name VARCHAR(80) NOT NULL,
    "order" INTEGER NOT NULL,
    latitude FLOAT NOT NULL,
    longitude FLOAT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_stops_route_order UNIQUE (route_id, "order"),
    CONSTRAINT ck_stops_order CHECK ("order" BETWEEN 1 AND 50),
    CONSTRAINT ck_stops_latitude CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT ck_stops_longitude CHECK (longitude BETWEEN -180 AND 180),
    FOREIGN KEY(route_id) REFERENCES routes (id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- trips: daily trips with weather and road condition from the catalogs
-- ---------------------------------------------------------------------
CREATE TABLE trips (
    id SERIAL NOT NULL,
    route_id INTEGER NOT NULL,
    driver_id INTEGER NOT NULL,
    monitor_id INTEGER,
    vehicle_id INTEGER,
    status_id INTEGER NOT NULL,
    weather_id INTEGER,
    road_condition_id INTEGER,
    direction VARCHAR(10) NOT NULL,
    scheduled_date DATE NOT NULL,
    started_at TIMESTAMP WITHOUT TIME ZONE,
    finished_at TIMESTAMP WITHOUT TIME ZONE,
    PRIMARY KEY (id),
    CONSTRAINT ck_trips_direction CHECK (direction IN ('outbound','return')),
    CONSTRAINT ck_trips_times CHECK (finished_at IS NULL OR started_at IS NULL OR finished_at >= started_at),
    FOREIGN KEY(route_id) REFERENCES routes (id),
    FOREIGN KEY(driver_id) REFERENCES users (id),
    FOREIGN KEY(monitor_id) REFERENCES users (id) ON DELETE SET NULL,
    FOREIGN KEY(vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL,
    FOREIGN KEY(status_id) REFERENCES trip_statuses (id),
    FOREIGN KEY(weather_id) REFERENCES weather_conditions (id),
    FOREIGN KEY(road_condition_id) REFERENCES road_conditions (id)
);
CREATE INDEX ix_trips_route_id ON trips (route_id);
CREATE INDEX ix_trips_status_id ON trips (status_id);

-- ---------------------------------------------------------------------
-- delay_predictions: AI delay predictions saved for analysis
-- ---------------------------------------------------------------------
CREATE TABLE delay_predictions (
    id SERIAL NOT NULL,
    route_id INTEGER,
    trip_id INTEGER,
    weather_id INTEGER NOT NULL,
    road_condition_id INTEGER NOT NULL,
    stops_remaining INTEGER NOT NULL,
    predicted_minutes FLOAT NOT NULL,
    model VARCHAR(20) NOT NULL,
    created_by INTEGER,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(route_id) REFERENCES routes (id) ON DELETE SET NULL,
    FOREIGN KEY(trip_id) REFERENCES trips (id) ON DELETE SET NULL,
    FOREIGN KEY(weather_id) REFERENCES weather_conditions (id),
    FOREIGN KEY(road_condition_id) REFERENCES road_conditions (id),
    FOREIGN KEY(created_by) REFERENCES users (id) ON DELETE SET NULL
);

-- ---------------------------------------------------------------------
-- incidents: incidents reported during a trip
-- ---------------------------------------------------------------------
CREATE TABLE incidents (
    id SERIAL NOT NULL,
    trip_id INTEGER,
    incident_type_id INTEGER NOT NULL,
    reported_by INTEGER NOT NULL,
    description VARCHAR(500) NOT NULL,
    latitude FLOAT,
    longitude FLOAT,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    resolved_at TIMESTAMP WITHOUT TIME ZONE,
    PRIMARY KEY (id),
    FOREIGN KEY(trip_id) REFERENCES trips (id) ON DELETE SET NULL,
    FOREIGN KEY(incident_type_id) REFERENCES incident_types (id),
    FOREIGN KEY(reported_by) REFERENCES users (id)
);

-- ---------------------------------------------------------------------
-- route_segments: road segments between stops (weighted graph edges)
-- ---------------------------------------------------------------------
CREATE TABLE route_segments (
    id SERIAL NOT NULL,
    route_id INTEGER NOT NULL,
    from_stop_id INTEGER NOT NULL,
    to_stop_id INTEGER NOT NULL,
    distance_km FLOAT NOT NULL,
    travel_minutes INTEGER NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_route_segments_pair UNIQUE (from_stop_id, to_stop_id),
    CONSTRAINT ck_route_segments_distinct CHECK (from_stop_id <> to_stop_id),
    CONSTRAINT ck_route_segments_distance CHECK (distance_km > 0 AND distance_km <= 200),
    CONSTRAINT ck_route_segments_minutes CHECK (travel_minutes BETWEEN 1 AND 300),
    FOREIGN KEY(route_id) REFERENCES routes (id) ON DELETE CASCADE,
    FOREIGN KEY(from_stop_id) REFERENCES stops (id) ON DELETE CASCADE,
    FOREIGN KEY(to_stop_id) REFERENCES stops (id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- students: students with their route, stop and unique QR code
-- ---------------------------------------------------------------------
CREATE TABLE students (
    id SERIAL NOT NULL,
    document_type_id INTEGER NOT NULL,
    document_number VARCHAR(10) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_date DATE NOT NULL,
    grade_id INTEGER NOT NULL,
    campus_id INTEGER NOT NULL,
    route_id INTEGER,
    stop_id INTEGER,
    qr_code VARCHAR(20) NOT NULL,
    active BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_students_document UNIQUE (document_type_id, document_number),
    FOREIGN KEY(document_type_id) REFERENCES document_types (id),
    FOREIGN KEY(grade_id) REFERENCES grades (id),
    FOREIGN KEY(campus_id) REFERENCES campuses (id),
    FOREIGN KEY(route_id) REFERENCES routes (id) ON DELETE SET NULL,
    FOREIGN KEY(stop_id) REFERENCES stops (id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX ix_students_qr_code ON students (qr_code);
CREATE INDEX ix_students_route_id ON students (route_id);

-- ---------------------------------------------------------------------
-- vehicle_locations: GPS positions sent by the bus during a trip
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_locations (
    id SERIAL NOT NULL,
    trip_id INTEGER NOT NULL,
    latitude FLOAT NOT NULL,
    longitude FLOAT NOT NULL,
    speed_kmh FLOAT,
    accuracy_m FLOAT,
    recorded_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_locations_latitude CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT ck_locations_longitude CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT ck_locations_speed CHECK (speed_kmh IS NULL OR speed_kmh BETWEEN 0 AND 200),
    FOREIGN KEY(trip_id) REFERENCES trips (id) ON DELETE CASCADE
);
CREATE INDEX ix_vehicle_locations_trip_time ON vehicle_locations (trip_id, recorded_at);

-- ---------------------------------------------------------------------
-- attendance: boarding and drop-off events (idempotent with client_event_id)
-- ---------------------------------------------------------------------
CREATE TABLE attendance (
    id SERIAL NOT NULL,
    student_id INTEGER NOT NULL,
    trip_id INTEGER NOT NULL,
    stop_id INTEGER,
    event_type_id INTEGER NOT NULL,
    method_id INTEGER NOT NULL,
    recorded_by INTEGER,
    latitude FLOAT,
    longitude FLOAT,
    client_event_id VARCHAR(36),
    timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(student_id) REFERENCES students (id) ON DELETE CASCADE,
    FOREIGN KEY(trip_id) REFERENCES trips (id) ON DELETE CASCADE,
    FOREIGN KEY(stop_id) REFERENCES stops (id) ON DELETE SET NULL,
    FOREIGN KEY(event_type_id) REFERENCES event_types (id),
    FOREIGN KEY(method_id) REFERENCES check_in_methods (id),
    FOREIGN KEY(recorded_by) REFERENCES users (id) ON DELETE SET NULL,
    UNIQUE (client_event_id)
);
CREATE INDEX ix_attendance_student_time ON attendance (student_id, timestamp);
CREATE INDEX ix_attendance_trip_id ON attendance (trip_id);

-- ---------------------------------------------------------------------
-- student_guardians: many-to-many relation between students and guardians
-- ---------------------------------------------------------------------
CREATE TABLE student_guardians (
    id SERIAL NOT NULL,
    student_id INTEGER NOT NULL,
    guardian_id INTEGER NOT NULL,
    relationship_id INTEGER NOT NULL,
    is_primary BOOLEAN NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_student_guardians UNIQUE (student_id, guardian_id),
    FOREIGN KEY(student_id) REFERENCES students (id) ON DELETE CASCADE,
    FOREIGN KEY(guardian_id) REFERENCES users (id) ON DELETE CASCADE,
    FOREIGN KEY(relationship_id) REFERENCES relationships (id)
);
CREATE INDEX ix_student_guardians_guardian ON student_guardians (guardian_id);

COMMIT;
