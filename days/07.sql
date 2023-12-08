CREATE TEMPORARY TABLE strength_map
(
  card varchar NOT NULL PRIMARY KEY,
  sort int     NOT NULL
);

INSERT INTO strength_map
VALUES ('A', 14),
       ('K', 13),
       ('Q', 12),
       ('J', 11),
       ('T', 10),
       ('9', 9),
       ('8', 8),
       ('7', 7),
       ('6', 6),
       ('5', 5),
       ('4', 4),
       ('3', 3),
       ('2', 2);

CREATE OR REPLACE FUNCTION find_strength(card_to_find varchar)
  RETURNS int
AS
$$
SELECT strength_map.sort
FROM strength_map
WHERE strength_map.card = card_to_find;
$$ LANGUAGE sql;

CREATE TEMPORARY TABLE splitted_hand
(
  card   varchar,
  occurs int
);

CREATE OR REPLACE FUNCTION find_hand_strength(hand_to_map varchar)
  RETURNS int
AS
$$
DECLARE
  hand_type int;
BEGIN
  DELETE FROM splitted_hand;

  INSERT INTO splitted_hand
  SELECT card, COUNT(*) AS occurrs
  FROM (SELECT UNNEST(REGEXP_SPLIT_TO_ARRAY(hand_to_map, '')) AS card) cards
  GROUP BY card
  ORDER BY COUNT(*) DESC;

  IF (SELECT COUNT(*) FROM splitted_hand) = 5 THEN
    hand_type = 1; -- high cards
  ELSEIF (SELECT COUNT(*) FROM splitted_hand) = 4 THEN
    hand_type = 2; -- one pair
  ELSEIF ((SELECT COUNT(*) FROM splitted_hand) = 3 AND
          (SELECT splitted_hand.occurs FROM splitted_hand ORDER BY occurs DESC LIMIT 1) = 2) THEN
    hand_type = 3; -- two pair
  ELSEIF ((SELECT COUNT(*) FROM splitted_hand) = 3 AND
          (SELECT splitted_hand.occurs FROM splitted_hand ORDER BY occurs DESC LIMIT 1) = 3) THEN
    hand_type = 4; -- three of a kind
  ELSEIF ((SELECT COUNT(*) FROM splitted_hand) = 2 AND
          (SELECT splitted_hand.occurs FROM splitted_hand ORDER BY occurs DESC LIMIT 1) = 3) THEN
    hand_type = 5; -- full house
  ELSEIF ((SELECT COUNT(*) FROM splitted_hand) = 2 AND
          (SELECT splitted_hand.occurs FROM splitted_hand ORDER BY occurs DESC LIMIT 1) = 4) THEN
    hand_type = 6; -- four of a kind
  ELSEIF (SELECT COUNT(*) FROM splitted_hand) = 1 THEN
    hand_type = 7; -- five of a kind
  END IF;
  RETURN hand_type;
END;
$$ LANGUAGE plpgsql;

CREATE TEMP TABLE hand AS
SELECT (REGEXP_MATCH(line, '^[^ ]+'))[1] AS hand, (REGEXP_MATCH(line, '\d+$'))[1]::numeric AS bid
FROM input;

CREATE TEMPORARY TABLE sorted_hands AS
SELECT *
FROM (SELECT *,
             find_hand_strength(hand)          AS hand_strength,
             find_strength(SUBSTR(hand, 1, 1)) AS strength1,
             find_strength(SUBSTR(hand, 2, 1)) AS strength2,
             find_strength(SUBSTR(hand, 3, 1)) AS strength3,
             find_strength(SUBSTR(hand, 4, 1)) AS strength4,
             find_strength(SUBSTR(hand, 5, 1)) AS strength5
      FROM hand) hands_with_strength
ORDER BY hand_strength DESC, strength1 DESC, strength2 DESC, strength3 DESC, strength4 DESC, strength5 DESC;

SELECT SUM(rank * bid) AS part1
FROM (SELECT (SELECT COUNT(*) FROM sorted_hands) - ROW_NUMBER() OVER () + 1 AS rank, *
      FROM sorted_hands) sorted_ranked_hand;

DROP TABLE sorted_hands;
DROP TABLE splitted_hand;
DROP TABLE hand;
DROP FUNCTION find_hand_strength(hand_to_map varchar);
DROP FUNCTION find_strength(card_to_find varchar);
DROP TABLE strength_map;

-- Part 2

CREATE TEMPORARY TABLE strength_map
(
  card varchar NOT NULL PRIMARY KEY,
  sort int     NOT NULL
);

INSERT INTO strength_map
VALUES ('A', 14),
       ('K', 13),
       ('Q', 12),
       ('J', 1), -- Joker
       ('T', 10),
       ('9', 9),
       ('8', 8),
       ('7', 7),
       ('6', 6),
       ('5', 5),
       ('4', 4),
       ('3', 3),
       ('2', 2);

CREATE OR REPLACE FUNCTION find_strength(card_to_find varchar)
  RETURNS int
AS
$$
SELECT strength_map.sort
FROM strength_map
WHERE strength_map.card = card_to_find;
$$ LANGUAGE sql;

CREATE TEMPORARY TABLE splitted_hand
(
  card   varchar,
  occurs int
);

CREATE OR REPLACE FUNCTION find_hand_strength(hand_to_map varchar)
  RETURNS int
AS
$$
DECLARE
  hand_type      int;
  strongest_card varchar;
  joker_amount   int;
BEGIN
  DELETE FROM splitted_hand;

  INSERT INTO splitted_hand
  SELECT card, COUNT(*) AS occurrs
  FROM (SELECT UNNEST(REGEXP_SPLIT_TO_ARRAY(hand_to_map, '')) AS card) cards
  GROUP BY card
  ORDER BY COUNT(*) DESC;

  -- deal with joker; remove joker and add amount of joker cards to next best card
  IF EXISTS(SELECT 1 FROM splitted_hand WHERE card = 'J') THEN
    SELECT card INTO strongest_card FROM splitted_hand WHERE card != 'J' ORDER BY occurs DESC, find_strength(card) DESC LIMIT 1;
    SELECT occurs INTO joker_amount FROM splitted_hand WHERE card = 'J';
    UPDATE splitted_hand SET occurs = occurs + joker_amount WHERE card = strongest_card;
    DELETE FROM splitted_hand WHERE card = 'J';
  END IF;

  IF (SELECT COUNT(*) FROM splitted_hand) = 5 THEN
    hand_type = 1; -- high cards
  ELSEIF (SELECT COUNT(*) FROM splitted_hand) = 4 THEN
    hand_type = 2; -- one pair
  ELSEIF ((SELECT COUNT(*) FROM splitted_hand) = 3 AND
          (SELECT splitted_hand.occurs FROM splitted_hand ORDER BY occurs DESC LIMIT 1) = 2) THEN
    hand_type = 3; -- two pair
  ELSEIF ((SELECT COUNT(*) FROM splitted_hand) = 3 AND
          (SELECT splitted_hand.occurs FROM splitted_hand ORDER BY occurs DESC LIMIT 1) = 3) THEN
    hand_type = 4; -- three of a kind
  ELSEIF ((SELECT COUNT(*) FROM splitted_hand) = 2 AND
          (SELECT splitted_hand.occurs FROM splitted_hand ORDER BY occurs DESC LIMIT 1) = 3) THEN
    hand_type = 5; -- full house
  ELSEIF ((SELECT COUNT(*) FROM splitted_hand) = 2 AND
          (SELECT splitted_hand.occurs FROM splitted_hand ORDER BY occurs DESC LIMIT 1) = 4) THEN
    hand_type = 6; -- four of a kind
  ELSEIF (SELECT COUNT(*) FROM splitted_hand) IN (0 /* joker */, 1 /* any other than joker */) THEN
    hand_type = 7; -- five of a kind
  END IF;

  RETURN hand_type;
END;
$$ LANGUAGE plpgsql;

CREATE TEMP TABLE hand AS
SELECT (REGEXP_MATCH(line, '^[^ ]+'))[1] AS hand, (REGEXP_MATCH(line, '\d+$'))[1]::numeric AS bid
FROM input;

CREATE TEMPORARY TABLE sorted_hands AS
SELECT *
FROM (SELECT *,
             find_hand_strength(hand)          AS hand_strength,
             find_strength(SUBSTR(hand, 1, 1)) AS strength1,
             find_strength(SUBSTR(hand, 2, 1)) AS strength2,
             find_strength(SUBSTR(hand, 3, 1)) AS strength3,
             find_strength(SUBSTR(hand, 4, 1)) AS strength4,
             find_strength(SUBSTR(hand, 5, 1)) AS strength5
      FROM hand) hands_with_strength
ORDER BY hand_strength DESC, strength1 DESC, strength2 DESC, strength3 DESC, strength4 DESC, strength5 DESC;

SELECT SUM(rank * bid) AS part2
FROM (SELECT (SELECT COUNT(*) FROM sorted_hands) - ROW_NUMBER() OVER () + 1 AS rank, *
      FROM sorted_hands) sorted_ranked_hand;

DROP TABLE sorted_hands;
DROP TABLE splitted_hand;
DROP TABLE hand;
DROP FUNCTION find_hand_strength(hand_to_map varchar);
DROP FUNCTION find_strength(card_to_find varchar);
DROP TABLE strength_map;