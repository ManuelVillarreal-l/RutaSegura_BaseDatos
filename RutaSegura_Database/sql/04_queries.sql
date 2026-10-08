-- =====================================================================
-- RutaSegura - Useful queries (PostgreSQL)
-- File 04: example queries for reports and for the presentation.
-- These do not modify data; run any of them on their own.
-- =====================================================================

-- 1. Routes with number of stops and students
SELECT * FROM v_route_overview ORDER BY route_id;

-- 2. Stops of a route in order (route 1)
SELECT "order", name, latitude, longitude
FROM stops
WHERE route_id = 1
ORDER BY "order";

-- 3. Students of each guardian
SELECT g.name AS guardian, st.full_name AS student, st.grade, r.name AS route
FROM students st
JOIN users g       ON g.id = st.guardian_id
LEFT JOIN routes r ON r.id = st.route_id
ORDER BY g.name, st.full_name;

-- 4. Where is every student right now (last event)
SELECT * FROM v_student_last_status ORDER BY full_name;

-- 5. Full history of one student (student 1), in Colombia time
SELECT a.event_type,
       sp.name AS stop,
       a.method,
       (a."timestamp" AT TIME ZONE 'UTC') AT TIME ZONE 'America/Bogota' AS local_time
FROM attendance a
LEFT JOIN stops sp ON sp.id = a.stop_id
WHERE a.student_id = 1
ORDER BY a."timestamp" DESC;

-- 6. Trip summary: duration, boardings and drop-offs
SELECT * FROM v_trip_summary ORDER BY trip_id;

-- 7. Daily attendance rate per route
SELECT * FROM v_daily_attendance ORDER BY local_date DESC, route_name;

-- 8. Students who did NOT board on a finished trip (absences)
SELECT t.id AS trip_id, r.name AS route, st.full_name AS absent_student
FROM trips t
JOIN routes r    ON r.id = t.route_id
JOIN students st ON st.route_id = t.route_id AND st.active
WHERE t.status = 'finished'
  AND NOT EXISTS (
      SELECT 1 FROM attendance a
      WHERE a.trip_id = t.id
        AND a.student_id = st.id
        AND a.event_type = 'boarding'
  )
ORDER BY t.id, st.full_name;

-- 9. Students who boarded but have no drop-off on that trip (safety alert)
SELECT a.trip_id, st.full_name
FROM attendance a
JOIN students st ON st.id = a.student_id
WHERE a.event_type = 'boarding'
  AND NOT EXISTS (
      SELECT 1 FROM attendance d
      WHERE d.trip_id = a.trip_id
        AND d.student_id = a.student_id
        AND d.event_type = 'drop_off'
  );

-- 10. Users by role
SELECT role, COUNT(*) AS total
FROM users
GROUP BY role
ORDER BY total DESC;
