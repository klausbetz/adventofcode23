CREATE TEMPORARY TABLE record AS
SELECT time.time, distance.distance
FROM (SELECT time, ROW_NUMBER() OVER () AS position
      FROM (SELECT (REGEXP_MATCHES(line, '\d+', 'gm'))[1]::numeric AS time
            FROM (SELECT line FROM input LIMIT 1) line1) time) time,
     (SELECT distance, ROW_NUMBER() OVER () AS position
      FROM (SELECT (REGEXP_MATCHES(line, '\d+', 'gm'))[1]::numeric AS distance
            FROM (SELECT line FROM input OFFSET 1 LIMIT 1) line2) distance) distance
WHERE time.position = distance.position;

CREATE AGGREGATE mul(numeric) (
  SFUNC = numeric_mul,
  STYPE = numeric
  );

SELECT mul(record_count) AS part1
FROM (SELECT time, COUNT(attempt) AS record_count
      FROM (SELECT *
            FROM (SELECT try.*, try.hold * (try.time - try.hold) AS attempt
                  FROM (SELECT GENERATE_SERIES(0, record.time) AS hold, record.time, distance AS record_distance
                        FROM record) try) attempt
            WHERE attempt.attempt > record_distance) new_record
      GROUP BY time) grouped_records;

DELETE
FROM record;

INSERT INTO record (time, distance)
SELECT time, distance
FROM (SELECT (REGEXP_REPLACE(line, '\D+', '', 'gm'))::numeric AS time
      FROM (SELECT line FROM input LIMIT 1) line1) time,
     (SELECT (REGEXP_REPLACE(line, '\D+', '', 'gm'))::numeric AS distance
      FROM (SELECT line FROM input OFFSET 1 LIMIT 1) line2) distance;

SELECT mul(record_count) AS part2
FROM (SELECT time, COUNT(attempt) AS record_count
      FROM (SELECT *
            FROM (SELECT try.*, try.hold * (try.time - try.hold) AS attempt
                  FROM (SELECT GENERATE_SERIES(0, record.time) AS hold, record.time, distance AS record_distance
                        FROM record) try) attempt
            WHERE attempt.attempt > record_distance) new_record
      GROUP BY time) grouped_records;

DROP AGGREGATE mul(numeric);
DROP TABLE IF EXISTS record;