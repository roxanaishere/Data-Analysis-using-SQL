/* This is the casee study project I worked on during the SQL for Business Analyst track. */
/* In this project, I served as a data scientist for a sports marketing company. The company has recently been asked to market perhaps the largest global sports event in the world: the Olympics. 
I will explore the dataset to offer insights for the executive team to move forward.*/
/* I will focus on building the base report for each element in the final dashboard.*/

-- ------------------
-- Data Preparation -
-- ------------------
DROP TABLE IF EXISTS "athletes";
	CREATE TABLE athletes(
	 	"id" int,
		name VARCHAR(255),
		gender VARCHAR(8),
		age int,
		height int,
		weight int);

DROP TABLE IF EXISTS "summer_games";
	CREATE TABLE summer_games(
	 	sport VARCHAR(255),
		event VARCHAR(255),
		year date,
		athlete_id int,
		country_id int,
		bronze float,
		silver float,
		gold float);

DROP TABLE IF EXISTS "winter_games";
	CREATE TABLE winter_games(
	 	sport VARCHAR(255),
		event VARCHAR(255),
		year date,
		athlete_id int,
		country_id int,
		bronze float,
		silver float,
		gold float);

DROP TABLE IF EXISTS "countries";
	CREATE TABLE countries(
	 	"id" int,
		country VARCHAR(255),
		region varchar(50));

DROP TABLE IF EXISTS "country_stats";
	CREATE TABLE country_stats(
	 	"year" VARCHAR(255),
		country_id int,
		gdp float,
		pop_in_millions VARCHAR(255),
		nobel_prize_winners int);

COPY athletes
	FROM PROGRAM 'curl "http://assets.datacamp.com/production/repositories/3815/datasets/a5c114363d3f60f514a30683969b1b48b7bc0fe8/athletes_updated.csv"' (DELIMITER ',', FORMAT CSV, HEADER);

COPY summer_games
	FROM PROGRAM 'curl "http://assets.datacamp.com/production/repositories/3815/datasets/174bc4db929ab36891538612c6b1e2cdce11a73b/summer_games_updated.csv"' (DELIMITER ',', FORMAT CSV, HEADER);

COPY winter_games
	FROM PROGRAM 'curl "http://assets.datacamp.com/production/repositories/3815/datasets/1aec560f1e9d22956288a19b1f46f2a21dee0a74/winter_games_updated.csv"' (DELIMITER ',', FORMAT CSV, HEADER);

COPY countries
	FROM PROGRAM 'curl "https://assets.datacamp.com/production/repositories/3815/datasets/3ef4cdfd931e29bc3b1e612d518cf825d56a0362/countries_messy.csv"' (DELIMITER ',', FORMAT CSV, HEADER);

COPY country_stats
	FROM PROGRAM 'curl "http://assets.datacamp.com/production/repositories/3815/datasets/b08d09328a1ab49397e671ee196e957f350bc672/country_stats_updated.csv"' (DELIMITER ',', FORMAT CSV, HEADER);

	
-- ------------------------------------------
-- Report 1: Most Decorated Summer Athletes--
-- ------------------------------------------
SELECT 
	a.name AS athlete_name, 
    count(s.gold) AS gold_medals
FROM summer_games AS s
JOIN athletes AS a
ON s.athlete_id = a.id
GROUP BY athlete_name
having count(s.gold) >= 3
ORDER BY gold_medals desc;


-- ---------------------------------------------------------------
-- Report 2: Athletes Representing Nobel-Prize Winning Countries--
-- ---------------------------------------------------------------
SELECT 
    event,
    CASE WHEN event LIKE '%Women%' THEN 'female'
    ELSE 'male' END AS gender,
    COUNT(DISTINCT athlete_id) AS athletes
FROM summer_games
WHERE country_id IN 
	(SELECT country_id 
    FROM country_stats 
    WHERE nobel_prize_winners > 0)
GROUP BY event
UNION
SELECT 
    event,
    CASE WHEN event LIKE '%Women%' THEN 'female' 
    ELSE 'male' END AS gender,
    COUNT(DISTINCT athlete_id) AS athletes
FROM summer_games
WHERE country_id IN 
	(SELECT country_id 
    FROM country_stats 
    WHERE nobel_prize_winners > 0)
GROUP BY event
ORDER BY athletes desc
LIMIT 10;


-- -------------------------------------
-- Report 3: Medals vs Population Rate--
-- -------------------------------------
SELECT 
	-- Clean the country field
    left(replace(trim(upper(c.country)),'.',''),3) as country_code,
    -- Pull in pop_in_millions and medals_per_million 
	pop_in_millions,
    -- Add the three medal fields
	SUM(COALESCE(bronze,0) + COALESCE(silver,0) + COALESCE(gold,0)) AS medals,
	SUM(COALESCE(bronze,0) + COALESCE(silver,0) + COALESCE(gold,0)) / CAST(cs.pop_in_millions AS float) AS medals_per_million
FROM summer_games AS s
JOIN countries AS c 
ON s.country_id = c.id
-- Update the newest join statement to remove duplication
JOIN country_stats AS cs 
ON s.country_id = cs.country_id AND s.year = CAST(cs.year AS date)
-- Filter out null populations
WHERE pop_in_millions is not null
GROUP BY c.country, pop_in_millions
ORDER BY medals_per_million desc
LIMIT 25;


-- ------------------------------------------------
-- Report 4: Tallest Athletes and % GDP by Region--
-- ------------------------------------------------
SELECT
	-- Pull in region and calculate avg tallest height
    region,
    AVG(height) AS avg_tallest,
    -- Calculate region's percent of world gdp
    sum(gdp)/sum(sum(gdp)) over () AS perc_world_gdp    
FROM countries AS c
JOIN
    (SELECT 
     	-- Pull in country_id and height
        country_id, 
        height, 
        -- Number the height of each country's athletes
        ROW_NUMBER() OVER (PARTITION BY country_id ORDER BY height DESC) AS row_num
    FROM winter_games AS w 
    JOIN athletes AS a ON w.athlete_id = a.id
    GROUP BY country_id, height
    ORDER BY country_id, height DESC) AS subquery
ON c.id = subquery.country_id
-- Join to country_stats
JOIN country_stats AS cs
ON cs.country_id = c.id
-- Only include the tallest height for each country
WHERE row_num = 1
GROUP BY region;