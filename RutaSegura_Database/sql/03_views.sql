-- =====================================================================
-- RutaSegura - Reporting views (PostgreSQL)
-- File 03: read-only views used for reports and dashboards.
-- Local times are shown in Colombia time (America/Bogota).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- v_route_overview: each route with its number of stops and students
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_route_overview AS
SELECT
    r.id                          AS route_id,
    r.name                        AS route_name,
    r.active,
    COUNT(DISTINCT s.id)          AS stop_count,
    COUNT(DISTINCT st.id)         AS student_count
FROM routes r
LEFT JOIN stops s     ON s.route_id = r.id
LEFT JOIN students st ON st.route_id = r.id AND st.active
GROUP BY r.id, r.name, r.active;


-- ---------------------------------------------------------------------
-- v_trip_summary: trips with route, driver, duration and event counts
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_trip_summary AS
SELECT
    t.id                                                         AS trip_id,
    r.name                                                       AS route_name,
    u.name                                                       AS driver_name,
    t.status,
    (t.started_at  AT TIME ZONE 'UTC') AT TIME ZONE 'America/Bogota' AS started_at_local,
    (t.finished_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Bogota' AS finished_at_local,
    ROUND(EXTRACT(EPOCH FROM (t.finished_at - t.started_at)) / 60)  AS duration_minutes,
    COUNT(a.id) FILTER (WHERE a.event_type = 'boarding')            AS boardings,
    COUNT(a.id) FILTER (WHERE a.event_type = 'drop_off')            AS drop_offs
FROM trips t
JOIN routes r      ON r.id = t.route_id
LEFT JOIN users u  ON u.id = t.driver_id
LEFT JOIN attendance a ON a.trip_id = t.id
GROUP BY t.id, r.name, u.name, t.status, t.started_at, t.finished_at;


-- ---------------------------------------------------------------------
-- v_student_last_status: the latest event of every student
-- (where each student is right now: on the bus, at school, or no record)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_student_last_status AS
SELECT
    st.id                                       AS student_id,
    st.full_name,
    g.name                                      AS guardian_name,
    r.name                                      AS route_name,
    last_event.event_type                       AS last_event_type,
    sp.name                                     AS last_stop_name,
    (last_event."timestamp" AT TIME ZONE 'UTC') AT TIME ZONE 'America/Bogota' AS last_event_local
FROM students st
LEFT JOIN users g  ON g.id = st.guardian_id
LEFT JOIN routes r ON r.id = st.route_id
LEFT JOIN LATERAL (
    SELECT a.event_type, a.stop_id, a."timestamp"
    FROM attendance a
    WHERE a.student_id = st.id
    ORDER BY a."timestamp" DESC
    LIMIT 1
) AS last_event ON TRUE
LEFT JOIN stops sp ON sp.id = last_event.stop_id;


-- ---------------------------------------------------------------------
-- v_daily_attendance: per day and route, how many students boarded
-- compared with how many are assigned (attendance rate)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_daily_attendance AS
WITH boardings AS (
    SELECT
        ((a."timestamp" AT TIME ZONE 'UTC') AT TIME ZONE 'America/Bogota')::date AS local_date,
        t.route_id,
        COUNT(DISTINCT a.student_id) AS students_boarded
    FROM attendance a
    JOIN trips t ON t.id = a.trip_id
    WHERE a.event_type = 'boarding'
    GROUP BY 1, 2
)
SELECT
    b.local_date,
    r.name                                    AS route_name,
    b.students_boarded,
    ro.student_count                          AS students_assigned,
    ROUND(100.0 * b.students_boarded / NULLIF(ro.student_count, 0), 1) AS attendance_rate_percent
FROM boardings b
JOIN routes r            ON r.id = b.route_id
JOIN v_route_overview ro ON ro.route_id = b.route_id;

COMMIT;
