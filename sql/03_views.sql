-- =====================================================================
-- RutaSegura - Reporting views (PostgreSQL)
-- File 03: read-only views used for reports and dashboards.
-- Timestamps are stored in UTC and shown here in Colombia time (America/Bogota).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- v_users_by_role: users joined with the roles table (roles are not hardcoded)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_users_by_role AS
SELECT
    u.id                                   AS user_id,
    r.code                                 AS role_code,
    r.name                                 AS role_name,
    u.first_name || ' ' || u.last_name     AS full_name,
    d.code                                 AS document_type,
    u.document_number,
    u.email,
    u.phone,
    u.active,
    (u.last_login_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Bogota' AS last_login_local
FROM users u
JOIN roles r          ON r.id = u.role_id
JOIN document_types d ON d.id = u.document_type_id;


-- ---------------------------------------------------------------------
-- v_route_overview: each route with campus, bus, stops and students
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_route_overview AS
SELECT
    r.id                     AS route_id,
    r.name                   AS route_name,
    c.name                   AS campus,
    v.plate                  AS vehicle_plate,
    v.capacity               AS vehicle_capacity,
    r.active,
    COUNT(DISTINCT s.id)     AS stop_count,
    COUNT(DISTINCT st.id)    AS student_count
FROM routes r
LEFT JOIN campuses c  ON c.id = r.campus_id
LEFT JOIN vehicles v  ON v.id = r.vehicle_id
LEFT JOIN stops s     ON s.route_id = r.id
LEFT JOIN students st ON st.route_id = r.id AND st.active
GROUP BY r.id, r.name, c.name, v.plate, v.capacity, r.active;


-- ---------------------------------------------------------------------
-- v_trip_summary: trips with people, weather, road, duration and events
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_trip_summary AS
SELECT
    t.id                                                             AS trip_id,
    t.scheduled_date,
    t.direction,
    r.name                                                           AS route_name,
    du.first_name || ' ' || du.last_name                             AS driver_name,
    mu.first_name || ' ' || mu.last_name                             AS monitor_name,
    ts.name                                                          AS status,
    w.name                                                           AS weather,
    rc.name                                                          AS road_condition,
    (t.started_at  AT TIME ZONE 'UTC') AT TIME ZONE 'America/Bogota' AS started_at_local,
    (t.finished_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Bogota' AS finished_at_local,
    ROUND(EXTRACT(EPOCH FROM (t.finished_at - t.started_at)) / 60)  AS duration_minutes,
    COUNT(a.id) FILTER (WHERE et.code = 'boarding')                  AS boardings,
    COUNT(a.id) FILTER (WHERE et.code = 'drop_off')                  AS drop_offs
FROM trips t
JOIN routes r                ON r.id = t.route_id
JOIN trip_statuses ts        ON ts.id = t.status_id
LEFT JOIN users du           ON du.id = t.driver_id
LEFT JOIN users mu           ON mu.id = t.monitor_id
LEFT JOIN weather_conditions w ON w.id = t.weather_id
LEFT JOIN road_conditions rc ON rc.id = t.road_condition_id
LEFT JOIN attendance a       ON a.trip_id = t.id
LEFT JOIN event_types et     ON et.id = a.event_type_id
GROUP BY t.id, r.name, du.first_name, du.last_name, mu.first_name, mu.last_name,
         ts.name, w.name, rc.name;


-- ---------------------------------------------------------------------
-- v_student_attendance: attendance rate of each student on finished outbound trips
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_student_attendance AS
WITH finished AS (
    SELECT t.id, t.route_id
    FROM trips t
    JOIN trip_statuses ts ON ts.id = t.status_id
    WHERE ts.code = 'finished' AND t.direction = 'outbound'
)
SELECT
    st.id                                         AS student_id,
    st.first_name || ' ' || st.last_name          AS full_name,
    g.name                                        AS grade,
    r.name                                        AS route_name,
    sp.name                                       AS stop_name,
    st.qr_code,
    COUNT(DISTINCT f.id)                          AS trips,
    COUNT(DISTINCT a.trip_id)                     AS boardings,
    ROUND(100.0 * COUNT(DISTINCT a.trip_id) / NULLIF(COUNT(DISTINCT f.id), 0), 1) AS attendance_percent
FROM students st
JOIN grades g          ON g.id = st.grade_id
LEFT JOIN routes r     ON r.id = st.route_id
LEFT JOIN stops sp     ON sp.id = st.stop_id
LEFT JOIN finished f   ON f.route_id = st.route_id
LEFT JOIN attendance a ON a.trip_id = f.id AND a.student_id = st.id
    AND a.event_type_id = (SELECT id FROM event_types WHERE code = 'boarding')
GROUP BY st.id, g.name, r.name, sp.name;


-- ---------------------------------------------------------------------
-- v_daily_attendance: boardings and drop-offs per local day
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_daily_attendance AS
SELECT
    ((a."timestamp" AT TIME ZONE 'UTC') AT TIME ZONE 'America/Bogota')::date AS local_date,
    COUNT(*) FILTER (WHERE et.code = 'boarding')                           AS boardings,
    COUNT(*) FILTER (WHERE et.code = 'drop_off')                           AS drop_offs,
    COUNT(DISTINCT a.student_id)                                          AS students
FROM attendance a
JOIN event_types et ON et.id = a.event_type_id
GROUP BY 1;


-- ---------------------------------------------------------------------
-- v_open_incidents: incidents not resolved yet, most severe first
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_open_incidents AS
SELECT
    i.id                                                             AS incident_id,
    it.name                                                          AS incident_type,
    it.severity,
    i.description,
    r.name                                                           AS route_name,
    u.first_name || ' ' || u.last_name                               AS reported_by,
    (i.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Bogota'  AS created_at_local
FROM incidents i
JOIN incident_types it ON it.id = i.incident_type_id
LEFT JOIN trips t      ON t.id = i.trip_id
LEFT JOIN routes r     ON r.id = t.route_id
LEFT JOIN users u      ON u.id = i.reported_by
WHERE i.resolved_at IS NULL;


-- ---------------------------------------------------------------------
-- v_weather_delay_stats: real average duration per weather and road condition
-- (the same history the AI regression model learns from)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_weather_delay_stats AS
SELECT
    w.name                                                           AS weather,
    w.delay_minutes                                                  AS weather_catalog_delay,
    rc.name                                                          AS road_condition,
    rc.delay_minutes                                                 AS road_catalog_delay,
    COUNT(*)                                                         AS trips,
    ROUND(AVG(EXTRACT(EPOCH FROM (t.finished_at - t.started_at)) / 60), 1) AS avg_duration_minutes
FROM trips t
JOIN weather_conditions w ON w.id = t.weather_id
JOIN road_conditions rc   ON rc.id = t.road_condition_id
WHERE t.finished_at IS NOT NULL AND t.started_at IS NOT NULL
GROUP BY w.name, w.delay_minutes, rc.name, rc.delay_minutes;

COMMIT;
