-- Part 1
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_input
(
  row_number int  NOT NULL,
  line       text NOT NULL
);

INSERT INTO tmp_input(row_number, line)
SELECT ROW_NUMBER() OVER (), line
FROM input;

CREATE OR REPLACE FUNCTION find_matches_and_positions(column_text text, regex_pattern text)
  RETURNS table
          (
            matched_text text,
            match_start  integer
          )
AS
$$
DECLARE
  substr_start        integer = 0;
  last_match_length   integer = 0;
  decrease            integer = 0;
  substring           text;
  current_match_start integer;
  rec                 record;
BEGIN
  FOR rec IN
    SELECT matches[1] AS matched_text
    FROM REGEXP_MATCHES(column_text, regex_pattern, 'gm') AS matches
    LOOP
      substring = SUBSTRING(column_text, substr_start, LENGTH(column_text));
      current_match_start = POSITION(rec.matched_text IN substring) - decrease;
      RETURN QUERY SELECT rec.matched_text, current_match_start + substr_start;
      last_match_length = LENGTH(rec.matched_text);
      substr_start = substr_start + current_match_start + last_match_length;
      decrease = 1; -- deduct 1 from the position after the first match, as positions would be to high by 1 cause of substring
    END LOOP;
  RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE TEMPORARY TABLE tmp_symbol_position AS
SELECT row_number, matched_text, match_start
FROM tmp_input, find_matches_and_positions(line, '[^\d.\n]+');

CREATE TEMPORARY TABLE tmp_part_number AS
SELECT row_number, matched_text, match_start
FROM tmp_input, find_matches_and_positions(line, '\d+');

SELECT SUM(p.matched_text::numeric) AS part1
FROM tmp_part_number p
WHERE EXISTS(SELECT 1
             FROM tmp_symbol_position s1
             WHERE s1.row_number = p.row_number - 1
               AND s1.match_start >= p.match_start - 1
               AND s1.match_start + LENGTH(s1.matched_text) <= p.match_start + LENGTH(p.matched_text) + 1)
   OR EXISTS(SELECT 1
             FROM tmp_symbol_position s2
             WHERE s2.row_number = p.row_number
               AND s2.match_start >= p.match_start - 1
               AND s2.match_start + LENGTH(s2.matched_text) <= p.match_start + LENGTH(p.matched_text) + 1)
   OR EXISTS(SELECT 1
             FROM tmp_symbol_position s3
             WHERE s3.row_number = p.row_number + 1
               AND s3.match_start >= p.match_start - 1
               AND s3.match_start + LENGTH(s3.matched_text) <= p.match_start + LENGTH(p.matched_text) + 1);

-- Part 2
-- aggregate for multiplying numbers
CREATE AGGREGATE mul(numeric) (
  SFUNC = numeric_mul,
  STYPE = numeric
  );

SELECT SUM(ratio)
FROM (SELECT mul(part_number::numeric) AS ratio
      FROM (SELECT s.row_number AS symbol_row, s.match_start AS symbol_postition, p.matched_text AS part_number
            FROM tmp_symbol_position s,
                 tmp_part_number p
            WHERE s.matched_text = '*'
              AND (s.row_number = p.row_number - 1
                     AND s.match_start >= p.match_start - 1
                     AND s.match_start + LENGTH(s.matched_text) <= p.match_start + LENGTH(p.matched_text) + 1
              OR s.row_number = p.row_number
                     AND s.match_start >= p.match_start - 1
                     AND s.match_start + LENGTH(s.matched_text) <= p.match_start + LENGTH(p.matched_text) + 1
              OR s.row_number = p.row_number + 1
                     AND s.match_start >= p.match_start - 1
                     AND s.match_start + LENGTH(s.matched_text) <= p.match_start + LENGTH(p.matched_text) + 1)) matching_gears
      GROUP BY CONCAT(symbol_row, '_', symbol_postition), symbol_row, symbol_postition
      HAVING COUNT(part_number) = 2) ratios;

DROP TABLE IF EXISTS tmp_input;
DROP TABLE IF EXISTS tmp_symbol_position;
DROP TABLE IF EXISTS tmp_part_number;
DROP AGGREGATE IF EXISTS mul(numeric);
DROP FUNCTION IF EXISTS find_matches_and_positions(column_text text, regex_pattern text);