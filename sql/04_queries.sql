-- =====================================================================
-- RutaSegura - Useful queries (PostgreSQL)
-- File 04: example queries for reports and for the presentation.
-- These do not modify data; run any of them on their own.
-- =====================================================================

-- 1. Number of tables in the database (28)
SELECT COUNT(*) AS tables
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

-- 2. Users with their role (role comes from the roles table)
SELECT role_name, full_name, email, active FROM v_users_by_role ORDER BY role_code, full_name;

-- 3. Passwords are never stored: only a PBKDF2 hash (first 40 characters shown)
SELECT email, LEFT(password_hash, 40) || '...' AS stored_value FROM users ORDER BY id;

-- 4. Weather and road catalogs with the delay each one adds
SELECT 'clima' AS catalog, code, name, delay_minutes, weather_codes FROM weather_conditions
UNION ALL
SELECT 'vía', code, name, delay_minutes, NULL FROM road_conditions
ORDER BY catalog, delay_minutes;

-- 5. Routes with campus, bus, stops and students
SELECT * FROM v_route_overview ORDER BY route_id;

-- 6. Stops of route 1 in order with GPS coordinates
SELECT "order", name, latitude, longitude FROM stops WHERE route_id = 1 ORDER BY "order";

-- 7. Road graph: segments between stops with distance and minutes
SELECT r.name AS route, a.name AS from_stop, b.name AS to_stop, s.distance_km, s.travel_minutes
FROM route_segments s
JOIN routes r ON r.id = s.route_id
JOIN stops a  ON a.id = s.from_stop_id
JOIN stops b  ON b.id = s.to_stop_id
ORDER BY r.id, a."order", b."order";

-- 8. Students with their guardians and kinship (many-to-many)
SELECT st.first_name || ' ' || st.last_name AS student,
       g.first_name || ' ' || g.last_name   AS guardian,
       k.name                               AS relationship,
       sg.is_primary
FROM student_guardians sg
JOIN students st      ON st.id = sg.student_id
JOIN users g          ON g.id = sg.guardian_id
JOIN relationships k  ON k.id = sg.relationship_id
ORDER BY student, sg.is_primary DESC;

-- 9. Attendance percentage of each student
SELECT full_name, route_name, trips, boardings, attendance_percent
FROM v_student_attendance
ORDER BY attendance_percent NULLS LAST, full_name;

-- 10. Last 10 trips with weather, road and duration
SELECT trip_id, scheduled_date, route_name, driver_name, status, weather, road_condition,
       duration_minutes, boardings, drop_offs
FROM v_trip_summary
ORDER BY scheduled_date DESC, trip_id DESC
LIMIT 10;

-- 11. How weather and road affect the real duration (data used by the AI)
SELECT * FROM v_weather_delay_stats ORDER BY avg_duration_minutes DESC;

-- 12. Attendance per day (last 10 days with activity)
SELECT * FROM v_daily_attendance ORDER BY local_date DESC LIMIT 10;

-- 13. Open incidents
SELECT * FROM v_open_incidents ORDER BY severity DESC, created_at_local;

-- 14. Students who miss more on rainy days
SELECT st.first_name || ' ' || st.last_name AS student,
       COUNT(*) FILTER (WHERE w.code IN ('rain', 'storm'))                       AS rainy_trips,
       COUNT(*) FILTER (WHERE w.code IN ('rain', 'storm') AND a.id IS NULL)      AS rainy_absences,
       COUNT(*) FILTER (WHERE w.code NOT IN ('rain', 'storm'))                   AS other_trips,
       COUNT(*) FILTER (WHERE w.code NOT IN ('rain', 'storm') AND a.id IS NULL)  AS other_absences
FROM students st
JOIN trips t              ON t.route_id = st.route_id AND t.direction = 'outbound'
JOIN trip_statuses ts     ON ts.id = t.status_id AND ts.code = 'finished'
JOIN weather_conditions w ON w.id = t.weather_id
LEFT JOIN attendance a    ON a.trip_id = t.id AND a.student_id = st.id
    AND a.event_type_id = (SELECT id FROM event_types WHERE code = 'boarding')
GROUP BY st.id
ORDER BY rainy_absences DESC;

-- 15. Failed login attempts in the last 24 hours (account lock after 5)
SELECT email, COUNT(*) AS failures, MAX(created_at) AS last_attempt
FROM login_attempts
WHERE NOT success AND created_at > (now() AT TIME ZONE 'UTC') - INTERVAL '24 hours'
GROUP BY email
ORDER BY failures DESC;

-- =====================================================================
-- Data the API loads into its data structures
-- =====================================================================

-- 16. Singly / doubly linked list: stops of each route in order (outbound).
--     The return itinerary is the same list walked backwards.
SELECT r.name AS route, s."order", s.name AS stop
FROM routes r
JOIN stops s ON s.route_id = r.id
WHERE r.active
ORDER BY r.id, s."order";

-- 17. Graph: adjacency list of the road network (each segment is an edge with its weight)
SELECT r.name AS route,
       a.name AS from_stop,
       b.name AS to_stop,
       rs.distance_km,
       rs.travel_minutes
FROM route_segments rs
JOIN stops a  ON a.id = rs.from_stop_id
JOIN stops b  ON b.id = rs.to_stop_id
JOIN routes r ON r.id = rs.route_id
ORDER BY r.id, a."order", b."order";

-- 18. BST: keys used to find a student when the QR card is scanned
SELECT qr_code AS bst_key, first_name || ' ' || last_name AS student
FROM students
WHERE active
ORDER BY qr_code;

-- 19. N-ary tree: school -> campus -> grade -> number of students (the leaves)
SELECT sc.name AS school, c.name AS campus, g.name AS grade, COUNT(st.id) AS students
FROM schools sc
JOIN campuses c  ON c.school_id = sc.id
JOIN students st ON st.campus_id = c.id AND st.active
JOIN grades g    ON g.id = st.grade_id
GROUP BY sc.name, c.name, g.name, g.sort_order
ORDER BY sc.name, c.name, g.sort_order;
