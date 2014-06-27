SELECT * 
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id) 
  WHERE "Street name" = 'WEST 140 STREET';

SELECT SUM("Parking spots"), SUM("Weighted parking spots") 
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id) 
  WHERE "Street name" = 'WEST 140 STREET';

SELECT "Hours free parking", SUM("Parking spots"), SUM("Weighted parking spots") 
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id) 
  WHERE "Street name" = 'WEST 140 STREET'
  GROUP BY "Hours free parking";

SELECT "Borough", SUM("Parking spots") AS spots, SUM("Weighted parking spots") AS weighted 
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id) 
  GROUP BY "Borough"
  ORDER BY "Borough";

SELECT "Borough", SUM("Parking spots") 
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id) 
  GROUP BY "Borough"
  ORDER BY "Borough";

SELECT SUM("Parking spots")
  FROM parking_fact;

SELECT "Side", SUM("Weighted parking spots") 
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id) 
  GROUP BY "Side";

SELECT "Hours street cleaning", SUM("Parking spots") 
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id) 
  GROUP BY "Hours street cleaning" 
  ORDER BY "Hours street cleaning";

SELECT "Special interest", SUM("Parking spots"), round(AVG("Hours no parking" + "Hours no standing")) 
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id) 
  WHERE "Hours no parking" > 0 OR "Hours no standing" > 0 
  GROUP BY "Special interest" 
  ORDER BY SUM("Parking spots") DESC;

SELECT "Angle parking", SUM("Length") 
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id) 
  GROUP BY "Angle parking";

SELECT "Borough", "Street name", "From street", "To street", "Side",
       round(CAST (sum("Weighted parking spots") AS numeric), 1) 
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id) 
  WHERE "Street name" = 'WEST 140 STREET'
  GROUP BY "Borough", "Street name", "From street", "To street", "Side"
  ORDER BY "Borough", "Street name", "From street", "To street", "Side";

SELECT "Borough", "Street name",
       round(CAST (sum("Weighted parking spots") AS numeric), 1) AS spots
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id) 
  GROUP BY "Borough", "Street name"
  ORDER BY spots DESC
  LIMIT 20;

SELECT "Borough", "Street name",
       sum("Parking spots") spots
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id)
  WHERE "Hours free parking" > 150
  GROUP BY "Borough", "Street name"
  ORDER BY spots DESC
  LIMIT 20;

SELECT "Borough", "Street name",
       sum("Parking spots") AS spots
  FROM parking_fact
  INNER JOIN block_dimension USING (block_id)
  INNER JOIN regulation_dimension USING (regulation_id)
  WHERE "Borough" = 'Manhattan'
    AND "Street name" LIKE '% AVENUE'
  GROUP BY "Borough", "Street name"
  ORDER BY "Street name";

SELECT "Borough", "Street name",
       sum("Parking spots") AS spots,
       round(CAST (sum("Hours metered parking" * "Parking spots") /
			       sum("Parking spots") AS numeric), 1) AS metered
  FROM parking_fact
  INNER JOIN block_dimension USING (block_id)
  INNER JOIN regulation_dimension USING (regulation_id)
  WHERE "Parking spots" != 0
  GROUP BY "Borough", "Street name"
  ORDER BY metered DESC
  LIMIT 100;




SELECT "Street name", "From street", "To street", "Side",
       "Day of week", "Half hour",
       sum("Parking spots" * "Free parking") AS free,
       sum("Parking spots" * "Street cleaning") AS cleaning
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id)
  INNER JOIN regulation_time_dimension USING (regulation_id) 
  WHERE "Street name" = 'WEST 140 STREET'
    AND "From street" = 'CONVENT AVENUE'
    AND "Side" = 'N'
  GROUP BY "Street name", "From street", "To street", "Side",
           "Day of week", "Half hour"
  ORDER BY "Street name", "From street", "To street", "Side",
           "Day of week", "Half hour";

SELECT "Street name", "Day of week", "Half hour",
       sum("Parking spots" * "Free parking") AS free,
       sum("Parking spots" * "Metered parking") AS metered,
       sum("Parking spots" * "Street cleaning") AS cleaning,
       sum("Parking spots" * "No parking") AS no_parking
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id)
  INNER JOIN regulation_time_dimension USING (regulation_id) 
  WHERE "Street name" = 'WEST 140 STREET'
  GROUP BY "Street name", "Day of week", "Half hour"
  ORDER BY "Street name", "Day of week", "Half hour";

SELECT "Day of week", "Half hour",
       sum("Parking spots" * "Free parking") AS free,
       sum("Parking spots" * "Metered parking") AS metered,
       sum("Parking spots" * "Street cleaning") AS cleaning,
       sum("Parking spots" * "No parking") AS no_parking
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id)
  INNER JOIN regulation_time_dimension USING (regulation_id)
  WHERE "Borough" = 'Manhattan'
  GROUP BY "Day of week", "Half hour"
  ORDER BY "Day of week", "Half hour";

SELECT *
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id)
  INNER JOIN regulation_time_dimension USING (regulation_id)
  WHERE "Day of week" = 0
    AND "Street cleaning" = 1;

SELECT "Day of week",
       sum("Parking spots") AS cleaning
  FROM parking_fact 
  INNER JOIN block_dimension USING (block_id) 
  INNER JOIN regulation_dimension USING (regulation_id)
  INNER JOIN regulation_time_dimension USING (regulation_id)
  WHERE "Borough" = 'Manhattan'
    AND "Street cleaning" = 1
  GROUP BY "Day of week"
  ORDER BY "Day of week";

SELECT "Day of week", "Borough", sum("Parking spots") AS spots
FROM (
  SELECT DISTINCT "Borough", "Street name", "From street", "To street", "Side",
         "Day of week", "Start position",
         "Parking spots"
    FROM parking_fact 
    INNER JOIN block_dimension USING (block_id) 
    INNER JOIN regulation_dimension USING (regulation_id)
    INNER JOIN regulation_time_dimension USING (regulation_id) 
    WHERE "Street cleaning" = 1
)
AS cleaning
GROUP BY "Day of week", "Borough"
ORDER BY "Day of week", "Borough";




SELECT regulation_id, sum("Parking spots") AS spots
FROM parking_fact
GROUP BY regulation_id
ORDER BY sum("Parking spots") DESC
LIMIT 100;

SELECT regulation_id,
       "Half hour" AS time,
       sum("Parking spots") AS spots,
       1 * max("Free parking") +
       2 * max("Metered parking") +
       3 * max("Street cleaning") +
       4 * max("No parking") AS status
FROM parking_fact
INNER JOIN regulation_time_dimension USING (regulation_id)
WHERE "Day of week" = 1
  AND regulation_id IN (
	SELECT regulation_id
	FROM parking_fact
	GROUP BY regulation_id
	ORDER BY sum("Parking spots") DESC
	LIMIT 100
	)
GROUP BY regulation_id, time
ORDER BY regulation_id, time;


