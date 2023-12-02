CREATE TEMPORARY TABLE IF NOT EXISTS tmp_parsed_input
(
  game_id     int     NOT NULL,
  set_number  int     NOT NULL,
  pick_number int     NOT NULL,
  cube_amount int     NOT NULL,
  cube_color  varchar NOT NULL
);

INSERT INTO tmp_parsed_input (game_id, set_number, pick_number, cube_amount, cube_color)
SELECT game_id::numeric, set_number::numeric, pick_number::numeric, cube_amount::numeric, cube_color
FROM (SELECT parsed_set.game_id,
             parsed_set.set_number,
             ROW_NUMBER() OVER (PARTITION BY CONCAT(parsed_set.game_id, '_', parsed_set.set_number)) AS pick_number,
             (REGEXP_MATCH(parsed_set.pick, '\d+'))[1]                                               AS cube_amount,
             (REGEXP_MATCH(parsed_set.pick, 'red|green|blue'))[1]                                    AS cube_color
      FROM (SELECT parsed_sets.game_id,
                   ROW_NUMBER() OVER (PARTITION BY parsed_sets.game_id)                   AS set_number,
                   parsed_sets.picks,
                   (REGEXP_MATCHES(parsed_sets.picks, '\d+ (?:red|green|blue)', 'gm'))[1] AS pick
            FROM (SELECT (REGEXP_MATCH(line, '(?<=Game )\d+', ''))[1]         AS game_id,
                         (REGEXP_MATCHES(line, '(?<=: |; )([^;]+)', 'gm'))[1] AS picks
                  FROM input) parsed_sets) parsed_set) parsed_cubes;

SELECT SUM(game_id)
FROM (SELECT DISTINCT game_id
      FROM tmp_parsed_input t
      WHERE NOT EXISTS(SELECT t1.game_id
                       FROM tmp_parsed_input t1
                       WHERE t1.game_id = t.game_id
                         AND (t1.cube_amount > 12 AND t1.cube_color = 'red'
                         OR t1.cube_amount > 13 AND t1.cube_color = 'green'
                         OR t1.cube_amount > 14 AND t1.cube_color = 'blue'))
      ORDER BY game_id) valid_games;

DROP TABLE tmp_parsed_input;