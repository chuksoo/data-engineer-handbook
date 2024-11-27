/* Building a Cumulative Table Design with Complex Data Types STRUCT and ARRAY 
showing historical record of all NBA players and the seasons they played! 
*/
-- SELECT * FROM player_seasons;

-- DROP TYPE season_stats CASCADE;
-- DROP TABLE players;

-- Create season_stats STRUCT datatype
-- CREATE TYPE season_stats AS (
-- 	 season Integer,
-- 	 gp INTEGER,
-- 	 pts REAL,
-- 	 reb REAL,
-- 	 ast REAL,
-- 	 weight INTEGER
-- );

-- CREATE TYPE scoring_class AS ENUM ('bad', 'average', 'good', 'star');

-- CREATE TABLE players (
-- 	player_name TEXT,
-- 	height TEXT,
-- 	college TEXT,
-- 	country TEXT,
-- 	draft_year TEXT,
-- 	draft_round TEXT,
-- 	draft_number TEXT,
-- 	seasons_stats season_stats[],
-- 	scoring_class scoring_class,
-- 	years_since_last_season INTEGER,
-- -- 	is_active BOOLEAN,
-- 	current_season INTEGER,
-- 	PRIMARY KEY (player_name, current_season)
--  );

INSERT INTO players
WITH last_season AS (
    -- Gets all players from previous season (1995)
    SELECT * FROM players
    WHERE current_season = 2000
)
, this_season AS (
    -- Gets current season (1996) stats
    SELECT * FROM player_seasons
    WHERE season = 2001
)
-- Main query combining historical and current data
SELECT 
    -- Basic player info uses COALESCE to prefer current season data
    COALESCE(t.player_name, l.player_name) AS player_name,
    COALESCE(t.height, l.height) AS height,
    COALESCE(t.college, l.college) AS college,
	COALESCE(t.country, l.country) AS country,
    COALESCE(t.draft_year, l.draft_year) AS draft_year,
    COALESCE(t.draft_round, l.draft_round) AS draft_round,
    COALESCE(t.draft_number, l.draft_number) AS draft_number,
    
    -- Season stats array handling using CASE
    CASE 
        -- New player (no previous history)
        WHEN l.seasons_stats IS NULL THEN 
            ARRAY[ROW(
                t.season, t.gp, t.pts, t.reb, t.ast, t.weight
            )::season_stats]
        
        -- Existing player with new season data
        WHEN t.season IS NOT NULL THEN 
            l.seasons_stats || ARRAY[ROW(
                t.season, t.gp, t.pts, t.reb, t.ast, t.weight
            )::season_stats]
        
        -- Player not active in current season
        ELSE l.seasons_stats
    END AS seasons_stats,
	CASE 
		WHEN t.season IS NOT NULL THEN 
			CASE 
				WHEN t.pts > 20 THEN 'star'
				WHEN t.pts > 15 THEN 'good'
				WHEN t.pts > 10 THEN 'average'
				ELSE 'bad'
			END::scoring_class
		ELSE l.scoring_class
	END AS scoring_class,
	
	CASE
		WHEN t.season IS NOT NULL THEN 0
		ELSE l.years_since_last_season + 1
	END AS years_since_last_season,
    
    -- Update current season
    COALESCE(t.season, l.current_season + 1) AS current_season
FROM this_season t 
FULL OUTER JOIN last_season l ON t.player_name = l.player_name

-- -- UNNESTing a record
-- WITH unnested AS (
-- 	SELECT player_name,
-- 		UNNEST(seasons_stats)::season_stats AS season_stats
-- 	FROM players 
-- 	WHERE current_season = 2001
-- 	-- AND player_name = 'Michael Jordan'
-- )

-- -- Go from UNNEST data back to season data
-- SELECT player_name, (season_stats::season_stats).*
-- FROM unnested

-- Performing analytics to see which player had the biggest improvement 
-- from their first season to the most recent season
SELECT 
	player_name,
	(seasons_stats[CARDINALITY(seasons_stats)]::season_stats).pts AS latest_season,
	(seasons_stats[1]::season_stats).pts AS first_season,
	(seasons_stats[CARDINALITY(seasons_stats)]::season_stats).pts / (
		CASE 
			WHEN (seasons_stats[1]::season_stats).pts = 0 THEN 1 
			ELSE (seasons_stats[1]::season_stats).pts 
		END) AS avg_pts
FROM players 
WHERE current_season = 2001
ORDER BY 4 DESC;

