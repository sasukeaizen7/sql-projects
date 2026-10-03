# Formula 1, 1950–2026: winners, eras, reliability and the value of pole

Every Formula 1 World Championship race since 1950 (**1,164 races, 27,621 race results**) from the open F1DB database, analyzed with SQL across a relational model of drivers, constructors, races, results and championships.

![Dominant seasons](images/dominant_seasons.png)

## Questions
1. Who has won the most, and who converts starts into wins best?
2. How much does the starting grid decide the race?
3. How has reliability changed over the decades?
4. What were the most dominant seasons and the dominant teams of each era?
5. Which countries produce the champions?
6. What are the longest winning streaks? (gaps and islands)
7. Who dominated their team-mates the most? (self-join on race + constructor)
8. Which title fights were the closest? (`lead()` over the final standings)
9. What was each multiple champion's best season? (`LATERAL` top-1)

## Key findings
- **Two traps handled:**
  - The calendar contains **8 future 2026 races** with no results, so only races with results count, and season rankings use complete seasons (1950–2025).
  - There are **1,167 wins for 1,164 races**, because in the 1950s team-mates sometimes shared a car and both were credited.
- **Lewis Hamilton has the most wins (106 in 395 starts),** but among drivers with 50+ starts **Fangio has the best win rate: 41.4%** (24 wins in 58 starts), ahead of Jim Clark (33.8%).
- **Pole position wins 43.6% of all races, and the front row 67%.** Starting P10 or lower produced only 3.5% of all wins.
- **Pole matters more than ever:** 56% of 2020s races were won from pole, against 28% in the 1980s.
- **Reliability transformed the sport:** in the 1980s only **41% of starters finished**; in the 2020s, **87%** do.
- **Verstappen's 2023 is the most dominant season ever: 19 wins in 22 races (86%),** ahead of Ascari 1952 (75%) and Schumacher 2004 (72%).
- **One team per era:** Lotus (1960s), McLaren (1980s), Williams (1990s), Ferrari (2000s, 49% of wins), Mercedes (2010s, 47%), Red Bull (2020s, 47%).
- **The United Kingdom has 21 drivers' titles from 11 champions,** far ahead of Germany (12 titles, 3 champions).
- **Longest winning streak: Verstappen, 10 races in a row** (Miami to Monza, 2023). He also has a separate run of 9 (Japan 2023 to Saudi Arabia 2024), level with Ascari (1952–53) and Vettel (2013).
- **Team-mate dominance:** Verstappen finished ahead of Pérez in **69 of 76 races** where both were classified (91%), and Alonso beat Massa 58–7. Hamilton beat Bottas 66–24 over 90 races.
- **Closest title fight: 1984, Lauda beat Prost by half a point** (72 to 71.5). Eight more titles were decided by a single point, including 2007 (Räikkönen–Hamilton) and 2008 (Hamilton–Massa).
- **Best seasons of multiple champions:** Verstappen 2023 (19/22), Ascari 1952 (6/8), Schumacher 2004 (13/18), Jim Clark 1963 (7/10).

| Win share by grid position | Finishing rate by decade |
|---|---|
| ![Grid](images/grid_to_win.png) | ![Reliability](images/reliability.png) |

![Team-mate battles](images/teammate_battles.png)

## SQL techniques
- An **8-table relational model with enforced keys** (countries, drivers, constructors, races, results, season standings, champions): primary keys, `UNIQUE (year, round)`, foreign keys from results to races, drivers and constructors, and `CHECK`s. `(race, driver)` is not unique because of shared cars in the 1950s, so results are keyed on `(race_id, position_order)`.
- `EXISTS` to separate run races from scheduled ones, **correlated subqueries** for per-season race counts
- **Top-1 per group** with `QUALIFY row_number() OVER (PARTITION BY decade ...)`, window shares with `sum(count(*)) OVER (PARTITION BY ...)`
- `count(*) FILTER`, decade bucketing, `HAVING` on minimum starts
- **Gaps and islands** for winning streaks (start number minus win number is constant within a streak)
- **Self-join** on race + constructor for team-mate head-to-heads; **`lead()`** over a named `WINDOW` for title margins; **`LATERAL`** top-1 per driver
- Deterministic ordering: every `ORDER BY ... LIMIT` has a tiebreaker (four countries tie on 4 titles)

## Dataset
| | |
|---|---|
| Source | [F1DB](https://github.com/f1db/f1db), latest release (`f1db-csv.zip`) |
| Size | 1,172 races (1,164 with results), 27,621 results, 917 drivers, 187 constructors |
| License | CC BY 4.0 |

> F1DB is updated after each Grand Prix, so a fresh `run.py` may include more 2026 races than this README.

## Run it
```bash
pip install -r ../../requirements.txt
python run.py
```
