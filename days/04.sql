-- Part 1
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_input
(
  card_number int  NOT NULL,
  line        text NOT NULL
);

INSERT INTO tmp_input(card_number, line)
SELECT (REGEXP_MATCH(line, '\d+(?=:)'))[1]::numeric, line
FROM input;

CREATE TEMPORARY TABLE IF NOT EXISTS tmp_winning_number AS
SELECT card_number, (REGEXP_MATCHES(winning_numbers, '\d+', 'gm'))[1]::numeric AS winning_number
FROM (SELECT card_number, (REGEXP_MATCH(line, '(?<=: )[^|]*'))[1] AS winning_numbers
      FROM tmp_input) winning_number;

CREATE TEMPORARY TABLE IF NOT EXISTS tmp_drawn_number AS
SELECT card_number, (REGEXP_MATCHES(drawn_numbers, '\d+', 'gm'))[1]::numeric AS drawn_number
FROM (SELECT card_number, (REGEXP_MATCH(line, '(?<=\| )[^\n]*'))[1] AS drawn_numbers
      FROM tmp_input) drawn_number;

SELECT SUM(points) AS part1
FROM (SELECT card_number, won_numbers, pow(2, won_numbers - 1) AS points
      FROM (SELECT d.card_number, COUNT(d.drawn_number) AS won_numbers
            FROM tmp_drawn_number d,
                 tmp_winning_number w
            WHERE d.card_number = w.card_number
              AND d.drawn_number = w.winning_number
            GROUP BY d.card_number) grouped_winnings
      WHERE grouped_winnings.won_numbers >= 1) won_points;

-- Part 2
CREATE TEMPORARY TABLE tmp_won_number AS
SELECT d.card_number, COUNT(d.drawn_number) AS won_numbers
FROM tmp_drawn_number d,
     tmp_winning_number w
WHERE d.card_number = w.card_number
  AND d.drawn_number = w.winning_number
GROUP BY d.card_number;

CREATE TEMPORARY TABLE tmp_won_copy AS
SELECT card_number, NULL::numeric AS from_card
FROM tmp_winning_number
GROUP BY card_number;

-- Warning: this procedure is super slow
DO
$$
  DECLARE
    rec              record;
    amount_of_copies int;
  BEGIN
    FOR rec IN SELECT card_number, won_numbers FROM tmp_won_number ORDER BY card_number
      LOOP
        FOR won_copy_number IN 1..rec.won_numbers
          LOOP
            SELECT COUNT(*) INTO amount_of_copies FROM tmp_won_copy WHERE card_number = rec.card_number;

            INSERT INTO tmp_won_copy (card_number, from_card)
            SELECT won_copy_number + rec.card_number, rec.card_number
            FROM GENERATE_SERIES(1, amount_of_copies);
          END LOOP;
      END LOOP;
  END;
$$;

SELECT COUNT(*) AS part2
FROM tmp_won_copy;

DROP TABLE IF EXISTS tmp_input;
DROP TABLE IF EXISTS tmp_winning_number;
DROP TABLE IF EXISTS tmp_drawn_number;
DROP TABLE IF EXISTS tmp_won_copy;
DROP TABLE IF EXISTS tmp_won_number;