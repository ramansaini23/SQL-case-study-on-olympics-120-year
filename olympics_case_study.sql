CREATE TABLE IF NOT EXISTS OLYMPICS_HISTORY
(
    id          INT,
    name        VARCHAR,
    sex         VARCHAR,
    age         VARCHAR,
    height      VARCHAR,
    weight      VARCHAR,
    team        VARCHAR,
    noc         VARCHAR,
    games       VARCHAR,
    year        INT,
    season      VARCHAR,
    city        VARCHAR,
    sport       VARCHAR,
    event       VARCHAR,
    medal       VARCHAR
);

CREATE TABLE IF NOT EXISTS OLYMPICS_HISTORY_NOC_REGIONS
(
    noc         VARCHAR,
    region      VARCHAR,
    notes       VARCHAR
);

select count(*) from olympics_history;
select count(*) from olympics_history_noc_regions;

-- 1. How many olympics games have been held?
select count(distinct(games)) as total_olympics_played
from olympics_history;

-- 2. List down all Olympics games held so far.
select distinct(year), season,city 
from olympics_history
order by year;

-- 3. Mention the total no of nations who participated in each olympics game?
select games, count(distinct region) as total_country
from olympics_history oh 
join olympics_history_noc_regions ohn on ohn.noc = oh.noc
group by games order by games;

-- 4. Which year saw the highest and lowest no of countries participating in olympics
(select 'highest - '|| games as games,count(distinct region) as total_participant
from olympics_history oh 
join olympics_history_noc_regions ohn on ohn.noc = oh.noc
group by games order by total_participant desc
limit 1)
union all
(select 'lowest - '|| games as games,count(distinct region) as total_participant
from olympics_history oh 
join olympics_history_noc_regions ohn on ohn.noc = oh.noc
group by games order by total_participant asc
limit 1);

-- 5. Which nation has participated in all of the olympic games
with cte as (select region, count(distinct(games)) as total_olympics_played 
from olympics_history oh
join olympics_history_noc_regions onc on onc.noc = oh.noc 
group by region
order by total_olympics_played
)
select * from cte
where total_olympics_played = (select max(total_olympics_played) from cte);

-- 5 using window function
WITH OlympicCounts AS (
  SELECT region, COUNT(DISTINCT games) AS total_olympics_played,
         RANK() OVER (ORDER BY COUNT(DISTINCT games) DESC) AS r
  FROM olympics_history oh
  JOIN olympics_history_noc_regions onc ON onc.noc = oh.noc
  GROUP BY region
)

SELECT region, total_olympics_played
FROM OlympicCounts
WHERE r = 1;

-- 6. Identify the sport which was played in all summer olympics.

SELECT sport, COUNT(distinct games) AS no_of_games
FROM (
  SELECT DISTINCT games, sport
  FROM olympics_history
  WHERE season = 'Summer'
) AS t2
GROUP BY sport
HAVING COUNT(distinct games) = (
  SELECT COUNT(DISTINCT games)
  FROM olympics_history
  WHERE season = 'Summer'
)


-- 7. Which Sports were just played only in one olympics season.
with cte as (select sport, count(distinct games) as no_of_season_played
from olympics_history
group by sport
order by sport,no_of_season_played
)
select * from cte where no_of_season_played =1;

-- using window function 
select sport,no_of_season_played 
from(select sport, count(distinct games) no_of_season_played,
rank() over(order by count(distinct games)) as r
from olympics_history
group by sport)
where r = 1
order by sport;

-- 8. Fetch the total no of sports played in each olympic games.
select games,count(distinct sport) as total_games_played
from olympics_history 
group by games
order by games;

-- 9. Fetch oldest athletes to win a gold medal
with cte as (select *,case when age = 'NA' then NULL else age end as new_age
from olympics_history where medal = 'Gold'),
cte2 as(select *,dense_rank() over(order by new_age desc) as rnk from cte
)
select name,age,team,games,event,medal
from cte2 where rnk = 2;

-- 10. Find the Ratio of male and female athletes participated in all olympic games.
SELECT (select concat('1:',(SELECT COUNT(sex)::NUMERIC FROM olympics_history WHERE sex = 'M') / 
(SELECT COUNT(sex) FROM olympics_history WHERE sex = 'F')))
;

-- 11. Fetch the top 5 athletes who have won the most gold medals.
with cte as (select name,team,
count(medal),dense_rank() over(order by count(medal) desc) as rnk 
from olympics_history
where medal = 'Gold'
group by name,team)
select * from cte where rnk<6;

--12. Fetch the top 5 athletes who have won the most medals (gold/silver/bronze).

with cte as (select name,team,
count(medal),dense_rank() over(order by count(medal) desc) as rnk 
from olympics_history
where medal in(select medal from olympics_history where medal not like 'NA')
group by name,team)
select * from cte where rnk<6;

-- 13. Fetch the top 5 most successful countries in olympics. Success is defined by no of medals won.
with cte as (select region,
count(medal),dense_rank() over(order by count(medal) desc) as rnk 
from olympics_history oh
JOIN olympics_history_noc_regions onc ON onc.noc = oh.noc
where medal in(select medal from olympics_history where medal not like 'NA')
group by region)
select * from cte where rnk<6;

-- 14. List down total gold, silver and bronze medals won by each country.
select region,
count(case when medal = 'Gold' then 1 end) as gold,
count(case when medal = 'Silver' then 1 end) as silver,
count(case when medal = 'Bronze' then 1 end) as bronze
from olympics_history oh
JOIN olympics_history_noc_regions onc ON onc.noc = oh.noc
group by region
order by gold desc,silver desc,bronze desc;

-- 15. List down total gold, silver and bronze medals won by each country corresponding to each olympic games.
with cte as(
select oh.games,onc.region,oh.medal,count(*) as medal_count,
dense_rank() over (partition by games, medal order by count(*) desc) as rank
from olympics_history oh
join olympics_history_noc_regions onc on oh.noc = onc.noc
where oh.medal IN ('Gold', 'Silver', 'Bronze')
group by oh.games, onc.region, oh.medal)
select games,
max(case when medal = 'Gold' and rank = 1 then region || ' ' || cast(medal_count AS varchar) end) as max_gold,
max(case when medal = 'Silver' and rank = 1 then region || ' ' || cast(medal_count AS varchar) end) as max_silver,
max(case when medal = 'Bronze' and rank = 1 then region || ' ' || cast(medal_count AS varchar) end) as max_bronze
from cte
group by games
order by games;

-- 17. Identify which country won the most gold, most silver, most bronze medals and the most medals in each olympic games.
with cte as(
select oh.games,onc.region,oh.medal,count(*) as medal_count,
dense_rank() over (partition by games, medal order by count(*) desc) as rank
from olympics_history oh
join olympics_history_noc_regions onc on oh.noc = onc.noc
where oh.medal IN ('Gold', 'Silver', 'Bronze')
group by oh.games, onc.region, oh.medal)
select games,
max(case when medal = 'Gold' and rank = 1 then region || ' ' || cast(medal_count AS varchar) end) as max_gold,
max(case when medal = 'Silver' and rank = 1 then region || ' ' || cast(medal_count AS varchar) end) as max_silver,
max(case when medal = 'Bronze' and rank = 1 then region || ' ' || cast(medal_count AS varchar) end) as max_bronze,
(select region || ' '|| cast(sum(medal_count) as varchar) from cte c where c.games = cte.games group by games,region
order by games,sum(medal_count) desc
limit 1) as season_max_medal
from cte 
group by games
order by games;


-- 18. Which countries have never won gold medal but have won silver/bronze medals?
with cte as(
select region,
count(case when medal = 'Gold' then 1 end) as gold,
count(case when medal = 'Silver' then 1 end) as silver,
count(case when medal = 'Bronze' then 1 end) as bronze
from olympics_history oh
JOIN olympics_history_noc_regions onc ON onc.noc = oh.noc
group by region
)
select * from cte where gold = 0 and (silver>0 or bronze >0);

-- 19. In which Sport/event, India has won highest medals.
with ind_max_medal_sport as(
select sport,
count(medal) as medal_won,
dense_rank() over(order by count(medal) desc) as rnk
from olympics_history oh
join olympics_history_noc_regions onc ON onc.noc = oh.noc
where team = 'India' and medal<>'NA'
group by sport
)
select sport,medal_won
from ind_max_medal_sport 
where rnk = 1;

-- 20. Break down all olympic games where India won medal for Hockey and how many medals in each olympic games
select team,games,count(medal) as hockey_medal
from olympics_history
where sport = 'Hockey' and team = 'India' and medal<>'NA'
group by team,games
order by games;
