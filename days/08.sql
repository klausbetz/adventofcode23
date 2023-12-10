CREATE TEMPORARY TABLE parsed_element AS
SELECT (REGEXP_MATCH(line, '^\w+'))[1]       AS element,
       (REGEXP_MATCH(line, '\w+(?=,)'))[1]   AS left_element,
       (REGEXP_MATCH(line, '\w+(?=\)$)'))[1] AS right_element
FROM (SELECT *
      FROM input
      OFFSET 2) parsed_input;

CREATE OR REPLACE FUNCTION find_next_direction(round numeric /* starts at 0 */)
  RETURNS varchar -- L or R
AS
$$
DECLARE
  directions text;
BEGIN
  SELECT line INTO directions FROM input LIMIT 1;
  RETURN SUBSTR(directions, MOD(round, LENGTH(directions))::int + 1, 1);
END;
$$
  LANGUAGE plpgsql;

WITH RECURSIVE recursive_element AS (
  -- select AAA as starting point
  SELECT element,
         left_element,
         right_element,
         CASE WHEN (find_next_direction(0) = 'L') THEN left_element ELSE right_element END AS next_element,
         1                                                                                 AS recursion_level
  FROM parsed_element
  WHERE element = 'AAA'

  UNION ALL

  -- go recursively through the tree of L and R
  SELECT parsed_element.element,
         parsed_element.left_element,
         parsed_element.right_element,
         CASE
           WHEN (find_next_direction(recursion_level) = 'L') THEN parsed_element.left_element
           ELSE parsed_element.right_element END AS next_element,
         recursion_level + 1
  FROM parsed_element
         JOIN recursive_element ON parsed_element.element = recursive_element.next_element
  WHERE parsed_element.element != 'ZZZ')
SELECT MAX(recursion_level) AS part1
FROM recursive_element;

-- Part 2 (approaching using least-common-multiple strategy)
CREATE TEMPORARY TABLE recursion_until_z AS
WITH RECURSIVE recursive_element AS (
  -- select %A as starting point
  SELECT element,
         left_element,
         right_element,
         CASE WHEN (find_next_direction(0) = 'L') THEN left_element ELSE right_element END AS next_element,
         CASE
           WHEN (find_next_direction(0) = 'L') THEN CASE WHEN (left_element ILIKE '%Z') THEN 1 ELSE 0 END
           ELSE CASE WHEN (right_element ILIKE '%Z') THEN 1 ELSE 0 END END                 AS next_element_is_z,
         1                                                                                 AS recursion_level,
         element                                                                           AS start_element
  FROM parsed_element
  WHERE element ILIKE '%A'

  UNION ALL

  -- go recursively through the tree of L and R, but do it only 30_000 times
  SELECT parsed_element.element,
         parsed_element.left_element,
         parsed_element.right_element,
         CASE
           WHEN (find_next_direction(recursion_level) = 'L') THEN parsed_element.left_element
           ELSE parsed_element.right_element END                                          AS next_element,
         CASE
           WHEN (find_next_direction(recursion_level) = 'L') THEN CASE WHEN (parsed_element.left_element ILIKE '%Z') THEN 1 ELSE 0 END
           ELSE CASE WHEN (parsed_element.right_element ILIKE '%Z') THEN 1 ELSE 0 END END AS next_element_is_z,
         recursion_level + 1,
         start_element
  FROM parsed_element
         JOIN recursive_element ON parsed_element.element = recursive_element.next_element
  WHERE recursion_level <= 30000)
SELECT *
FROM recursive_element;

CREATE AGGREGATE lcm(numeric) (
  SFUNC = lcm,
  STYPE = numeric
  );

SELECT lcm(min_recursions) AS part2_least_common_mutliple
FROM (SELECT z.start_element, MIN(recursion_level) AS min_recursions
      FROM (SELECT *
            FROM recursion_until_z
            WHERE next_element_is_z = 1) z
      GROUP BY z.start_element
      ORDER BY MIN(z.recursion_level)) min_recursions;

DROP AGGREGATE IF EXISTS lcm(numeric);
DROP TABLE IF EXISTS recursion_until_z;
DROP FUNCTION IF EXISTS find_next_direction(round numeric);
DROP TABLE IF EXISTS parsed_element;