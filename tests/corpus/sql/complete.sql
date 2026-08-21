-- Native SQL highlighting fixture.
WITH active AS (
  SELECT u.id, u."display_name", count(*) AS total
  FROM users AS u
  WHERE u.enabled = true AND u.name LIKE '%<&>%'
  GROUP BY u.id, u."display_name"
)
SELECT * FROM active WHERE total > :minimum AND id <> $1 LIMIT 10;

INSERT INTO audit(message, payload) VALUES ('it''s complete', $$line <&>$$);
