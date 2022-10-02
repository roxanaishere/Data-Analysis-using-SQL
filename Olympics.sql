/* This is the casee study project I worked on during the <code>SQL for Business Analyst</code> track. */
/* In this project, I served as a data scientist for a sports marketing company. The company has recently been asked to market perhaps the largest global sports event in the world: the Olympics. 
I will explore the dataset to offer insights for the executive team to move forward.*/
/* I will focus on building the base report for each element in the final dashboard.*/

---------------------------------------------
-- Report 1: Most Decorated Summer Athletes--
---------------------------------------------
SELECT 
    a.name AS athlete_name, 
    count(s.gold) AS gold_medals
FROM summer_games AS s
JOIN athletes AS a
ON s.athlete_id = a.id
GROUP BY athlete_name
having count(s.gold) >= 3
ORDER BY gold_medals desc;

------------------------------------------------------------------
-- Report 2: Athletes Representing Nobel-Prize Winning Countries--
------------------------------------------------------------------
SELECT 
    event,
    -- Add the gender field
    CASE WHEN event LIKE '%Women%' THEN 'female' 
    ELSE 'male' END AS gender,
    COUNT(DISTINCT athlete_id) AS athletes
FROM summer_games
-- Only include countries that won a nobel prize
WHERE country_id IN 
	(SELECT country_id 
    FROM country_stats 
    WHERE nobel_prize_winners > 0)
GROUP BY event
-- Add the second query
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

----------------------------------------
-- Report 3: medals vs population rate--
----------------------------------------
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

---------------------------------------------------
-- Report 4: Tallest athletes and % GDP by region--
---------------------------------------------------
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
