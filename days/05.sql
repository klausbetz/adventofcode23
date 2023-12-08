CREATE TEMPORARY TABLE tmp_input AS
SELECT ROW_NUMBER() OVER () AS line_number, line
FROM input;

CREATE TEMPORARY TABLE tmp_seeds AS
SELECT (REGEXP_MATCHES(line, '\d+', 'gm'))[1]::numeric AS seed
FROM (SELECT line FROM input LIMIT 1) first_line;

CREATE OR REPLACE FUNCTION parse_lines(text_to_search text)
  RETURNS table
          (
            destination_start numeric,
            destination_end   numeric,
            source_start      numeric,
            source_end        numeric,
            length            numeric,
            destination_diff  numeric
          )
AS
$$
BEGIN
  RETURN QUERY SELECT parsed_lines.destination_start,
                      parsed_lines.destination_start + parsed_lines.length - 1   AS destination_end,
                      parsed_lines.source_start,
                      parsed_lines.source_start + parsed_lines.length - 1        AS source_end,
                      parsed_lines.length                                        AS length,
                      parsed_lines.destination_start - parsed_lines.source_start AS destination_diff
               FROM (SELECT (REGEXP_MATCH(tmp_input.line, '^\d+'))[1]::numeric          AS destination_start,
                            TRIM((REGEXP_MATCH(tmp_input.line, '\s\d+\s'))[1])::numeric AS source_start,
                            (REGEXP_MATCH(tmp_input.line, '\d+$'))[1]::numeric          AS length
                     FROM (SELECT range.start, range.end
                           FROM ((SELECT start.line_number     AS start,
                                         tmp_input.line_number AS end
                                  FROM (SELECT line_number
                                        FROM tmp_input
                                        WHERE line LIKE CONCAT(text_to_search, '%')) start,
                                       tmp_input
                                  WHERE tmp_input.line_number > start.line_number
                                    AND tmp_input.line IS NULL
                                  ORDER BY tmp_input.line_number)

                                 UNION ALL

                                 (SELECT start.line_number         AS start,
                                         tmp_input.line_number + 1 AS end
                                  FROM (SELECT line_number
                                        FROM tmp_input
                                        WHERE line LIKE CONCAT(text_to_search, '%')) start,
                                       tmp_input
                                  WHERE tmp_input.line_number > start.line_number
                                  ORDER BY tmp_input.line_number DESC)) range
                           LIMIT 1) range,
                          tmp_input
                     WHERE tmp_input.line_number > range.start
                       AND tmp_input.line_number < range.end
                     ORDER BY tmp_input.line_number) parsed_lines;
  RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE tmp_seed_to_soil AS
SELECT *
FROM parse_lines('seed-to-soil');

CREATE TABLE tmp_soil_to_fertilizer AS
SELECT *
FROM parse_lines('soil-to-fertilizer');

CREATE TABLE tmp_fertilizer_to_water AS
SELECT *
FROM parse_lines('fertilizer-to-water');

CREATE TABLE tmp_water_to_light AS
SELECT *
FROM parse_lines('water-to-light');

CREATE TABLE tmp_light_to_temperature AS
SELECT *
FROM parse_lines('light-to-temperature');

CREATE TABLE tmp_temperature_to_humidity AS
SELECT *
FROM parse_lines('temperature-to-humidity');

CREATE TABLE tmp_humidity_to_location AS
SELECT *
FROM parse_lines('humidity-to-location');

SELECT MIN(location.location) AS part1
FROM (SELECT humidity.*, COALESCE(humidity.humidity + s8.destination_diff, humidity.humidity) AS location
      FROM (SELECT temperature.*, COALESCE(temperature.temperature + s7.destination_diff, temperature.temperature) AS humidity
            FROM (SELECT light.*, COALESCE(light.light + s6.destination_diff, light.light) AS temperature
                  FROM (SELECT water.*, COALESCE(water.water + s5.destination_diff, water.water) AS light
                        FROM (SELECT fertilizer.*, COALESCE(fertilizer.fertilizer + s4.destination_diff, fertilizer.fertilizer) AS water
                              FROM (SELECT soil.*, COALESCE(soil.soil + s3.destination_diff, soil.soil) AS fertilizer
                                    FROM (SELECT s.seed, COALESCE(s.seed + s2.destination_diff, s.seed) AS soil
                                          FROM tmp_seeds s
                                                 LEFT OUTER JOIN tmp_seed_to_soil s2 ON s.seed >= s2.source_start AND s.seed <= s2.source_end) soil
                                           LEFT OUTER JOIN tmp_soil_to_fertilizer s3
                                                           ON soil.soil >= s3.source_start AND soil.soil <= s3.source_end) fertilizer
                                     LEFT OUTER JOIN tmp_fertilizer_to_water s4
                                                     ON fertilizer.fertilizer >= s4.source_start AND fertilizer.fertilizer <= s4.source_end) water
                               LEFT OUTER JOIN tmp_water_to_light s5
                                               ON water.water >= s5.source_start AND water.water <= s5.source_end) light
                         LEFT OUTER JOIN tmp_light_to_temperature s6
                                         ON light.light >= s6.source_start AND light.light <= s6.source_end) temperature
                   LEFT OUTER JOIN tmp_temperature_to_humidity s7
                                   ON temperature.temperature >= s7.source_start AND temperature.temperature <= s7.source_end) humidity
             LEFT OUTER JOIN tmp_humidity_to_location s8
                             ON humidity.humidity >= s8.source_start AND humidity.humidity <= s8.source_end) location;

-- Part 2

CREATE TEMPORARY TABLE tmp_seed_range AS
SELECT (REGEXP_MATCH(seed, '^\d+'))[1]::numeric AS seed, (REGEXP_MATCH(seed, '\d+$'))[1]::numeric AS length
FROM (SELECT (REGEXP_MATCHES(line, '\d+ \d+', 'gm'))[1] AS seed
      FROM (SELECT line FROM input LIMIT 1) first_line) seed_range;

CREATE INDEX idx1_1 ON tmp_seed_to_soil (destination_start);
CREATE INDEX idx1_2 ON tmp_seed_to_soil (destination_end);
CREATE INDEX idx2_1 ON tmp_soil_to_fertilizer (destination_start);
CREATE INDEX idx2_2 ON tmp_soil_to_fertilizer (destination_end);
CREATE INDEX idx3_1 ON tmp_fertilizer_to_water (destination_start);
CREATE INDEX idx3_2 ON tmp_fertilizer_to_water (destination_end);
CREATE INDEX idx4_1 ON tmp_water_to_light (destination_start);
CREATE INDEX idx4_2 ON tmp_water_to_light (destination_end);
CREATE INDEX idx5_1 ON tmp_light_to_temperature (destination_start);
CREATE INDEX idx5_2 ON tmp_light_to_temperature (destination_end);
CREATE INDEX idx6_1 ON tmp_temperature_to_humidity (destination_start);
CREATE INDEX idx6_2 ON tmp_temperature_to_humidity (destination_end);
CREATE INDEX idx7_1 ON tmp_humidity_to_location (destination_start);
CREATE INDEX idx7_2 ON tmp_humidity_to_location (destination_end);

CREATE TEMPORARY TABLE tmp_location AS
SELECT GENERATE_SERIES(0, 500000000) AS location;

CREATE SEQUENCE progress_seq START 1;

SELECT seed.*,
       TRUE AS seed_exists
FROM (SELECT soil.*, COALESCE(soil.soil - destination_diff, soil.soil) AS seed
      FROM (SELECT fertilizer.*, COALESCE(fertilizer.fertilizer - destination_diff, fertilizer.fertilizer) AS soil
            FROM (SELECT water.*, COALESCE(water.water - destination_diff, water.water) AS fertilizer
                  FROM (SELECT light.*, COALESCE(light.light - destination_diff, light.light) AS water
                        FROM (SELECT temp.*, COALESCE(temp.temp - destination_diff, temp.temp) AS light
                              FROM (SELECT humidity.*, COALESCE(humidity.humidity - destination_diff, humidity.humidity) AS temp
                                    FROM (SELECT location, COALESCE(location - destination_diff, location) AS humidity
                                          FROM tmp_location l
                                                 LEFT OUTER JOIN tmp_humidity_to_location t
                                                                 ON l.location >= t.destination_start AND l.location <= t.destination_end) humidity
                                           LEFT OUTER JOIN tmp_temperature_to_humidity t
                                                           ON humidity.humidity >= t.destination_start AND humidity.humidity <= t.destination_end) temp
                                     LEFT OUTER JOIN tmp_light_to_temperature t
                                                     ON temp >= t.destination_start AND temp <= t.destination_end) light
                               LEFT OUTER JOIN tmp_water_to_light t
                                               ON light.light >= t.destination_start AND light.light <= t.destination_end) water
                         LEFT OUTER JOIN tmp_fertilizer_to_water t
                                         ON water.water >= t.destination_start AND water.water <= t.destination_end) fertilizer
                   LEFT OUTER JOIN tmp_soil_to_fertilizer t
                                   ON fertilizer.fertilizer >= t.destination_start AND
                                      fertilizer.fertilizer <= t.destination_end) soil
             LEFT OUTER JOIN tmp_seed_to_soil t
                             ON soil.soil >= t.destination_start AND soil.soil <= t.destination_end) seed
WHERE EXISTS(SELECT 1
             FROM tmp_seed_range
             WHERE tmp_seed_range.seed >= seed.seed
               AND tmp_seed_range.seed + tmp_seed_range.length - 1 <= seed.seed)
LIMIT 1;

DROP SEQUENCE progress_seq;

DROP FUNCTION IF EXISTS parse_lines(text_to_search text);
DROP TABLE IF EXISTS tmp_location;
DROP TABLE IF EXISTS tmp_seed_range;
DROP TABLE IF EXISTS tmp_humidity_to_location;
DROP TABLE IF EXISTS tmp_temperature_to_humidity;
DROP TABLE IF EXISTS tmp_light_to_temperature;
DROP TABLE IF EXISTS tmp_water_to_light;
DROP TABLE IF EXISTS tmp_fertilizer_to_water;
DROP TABLE IF EXISTS tmp_soil_to_fertilizer;
DROP TABLE IF EXISTS tmp_seed_to_soil;
DROP TABLE IF EXISTS tmp_seeds;
DROP TABLE IF EXISTS tmp_input;