-- Part 1
SELECT SUM(calibration.calibration_value) as part1
FROM (SELECT numbers.digits,
             CONCAT(SUBSTR(numbers.digits, 1, 1), SUBSTR(numbers.digits, LENGTH(numbers.digits), 1))::numeric AS calibration_value
      FROM (SELECT REGEXP_REPLACE(line, '\D', '', 'g') AS digits
            FROM input) numbers) calibration;

-- Part 2
CREATE TEMPORARY TABLE tmp_input
(
  id            serial,
  line          text,
  replaced_line text
);
INSERT INTO tmp_input (line, replaced_line)
SELECT line, line
FROM input;

CREATE TEMPORARY TABLE mapping
(
  text   varchar,
  number varchar
);
INSERT INTO mapping (text, number)
VALUES ('one', '1e'),
       ('two', '2o'),
       ('three', '3e'),
       ('four', '4'),
       ('five', '5e'),
       ('six', '6'),
       ('seven', '7n'),
       ('eight', '8t'),
       ('nine', '9e');

CREATE TEMPORARY TABLE mapping_position
(
  text   varchar,
  number varchar,
  index  int
);

DO
$$
  DECLARE
    map          record;
    rec          record;
    currentLine  varchar;
    mappingFound bool;
  BEGIN
    FOR rec IN SELECT * FROM tmp_input
      LOOP
        currentLine = rec.line;
        mappingFound = TRUE;

        WHILE mappingFound
          LOOP
            FOR map IN SELECT text, number
                       FROM mapping
              LOOP
                IF POSITION(map.text IN currentLine) > 0 THEN
                  INSERT INTO mapping_position(text, number, index) SELECT map.text, map.number, POSITION(map.text IN currentLine);
                END IF;
              END LOOP;

            IF NOT EXISTS(SELECT * FROM mapping_position) THEN
              mappingFound = FALSE;
            ELSE
              SELECT regexp_replace(currentLine, text, number) INTO currentLine FROM mapping_position ORDER BY index LIMIT 1;
              DELETE FROM mapping_position;
            END IF;
          END LOOP;

        UPDATE tmp_input
        SET replaced_line = currentLine
        WHERE id = rec.id;
      END LOOP;

    UPDATE tmp_input
    SET replaced_line = REGEXP_REPLACE(replaced_line, '\D', '', 'g');
  END;
$$;

SELECT SUM(calibration.calibration_value) as part2
FROM (SELECT numbers.*,
             CONCAT(SUBSTR(numbers.replaced_line, 1, 1),
                    SUBSTR(numbers.replaced_line, LENGTH(numbers.replaced_line), 1))::numeric AS calibration_value
      FROM tmp_input AS numbers) calibration;

DROP TABLE tmp_input;
DROP TABLE mapping;
DROP TABLE mapping_position;