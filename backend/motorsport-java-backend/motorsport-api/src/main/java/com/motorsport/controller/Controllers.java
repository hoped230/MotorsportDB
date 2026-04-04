package com.motorsport.controller;

import com.motorsport.repository.AnalyticsRepository;
import com.motorsport.repository.DriverRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

// ── DRIVER CONTROLLER ─────────────────────────────────────────────────────────
@RestController
@RequestMapping("/api/drivers")
class DriverController {

    @Autowired DriverRepository driverRepo;

    // GET /api/drivers — all drivers with career stats
    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getAllDrivers() {
        return ResponseEntity.ok(driverRepo.findAllWithCareerStats());
    }

    // GET /api/drivers/{id} — driver profile + results + stats
    @GetMapping("/{id}")
    public ResponseEntity<?> getDriver(
            @PathVariable Integer id,
            @Autowired JdbcTemplate jdbc) {
        String driverSql = """
            SELECT d.*, co.country_name AS nationality
            FROM driver d
            LEFT JOIN country co ON d.nationality_id = co.country_id
            WHERE d.driver_id = ?
            """;
        List<Map<String, Object>> rows = jdbc.queryForList(driverSql, id);
        if (rows.isEmpty()) return ResponseEntity.notFound().build();

        String statsSql = """
            SELECT COALESCE(SUM(rr.points_earned),0) AS total_points,
                   COUNT(DISTINCT rr.race_id)          AS races,
                   COUNT(CASE WHEN rr.finishing_position=1 THEN 1 END)  AS wins,
                   COUNT(CASE WHEN rr.finishing_position<=3 THEN 1 END) AS podiums,
                   MIN(rr.finishing_position)           AS best_finish
            FROM race_result rr WHERE rr.driver_id = ?
            """;
        String resultsSql = """
            SELECT race_name, season_year, champ_name, circuit_name,
                   finishing_position, grid_position, points_earned,
                   laps_completed, result_status, fastest_lap
            FROM v_race_results_full
            WHERE driver_id = ?
            ORDER BY race_date DESC
            """;

        Map<String, Object> driver = rows.get(0);
        driver.put("stats",   jdbc.queryForMap(statsSql, id));
        driver.put("results", jdbc.queryForList(resultsSql, id));
        return ResponseEntity.ok(driver);
    }

    // GET /api/drivers/search?name=ver
    @GetMapping("/search")
    public ResponseEntity<?> search(@RequestParam String name) {
        return ResponseEntity.ok(driverRepo.searchByName(name));
    }
}

// ── STANDINGS CONTROLLER ──────────────────────────────────────────────────────
@RestController
@RequestMapping("/api/standings")
class StandingsController {

    @Autowired JdbcTemplate jdbc;

    // GET /api/standings/drivers?season_id=1
    @GetMapping("/drivers")
    public ResponseEntity<List<Map<String, Object>>> driverStandings(
            @RequestParam(defaultValue = "1") int seasonId) {
        String sql = "SELECT * FROM v_driver_standings_latest WHERE season_id = ? ORDER BY position ASC";
        return ResponseEntity.ok(jdbc.queryForList(sql, seasonId));
    }

    // GET /api/standings/constructors?season_id=1
    @GetMapping("/constructors")
    public ResponseEntity<List<Map<String, Object>>> constructorStandings(
            @RequestParam(defaultValue = "1") int seasonId) {
        String sql = "SELECT * FROM v_constructor_standings_latest WHERE season_id = ? ORDER BY position ASC";
        return ResponseEntity.ok(jdbc.queryForList(sql, seasonId));
    }
}

// ── RACE CONTROLLER ───────────────────────────────────────────────────────────
@RestController
@RequestMapping("/api/races")
class RaceController {

    @Autowired JdbcTemplate jdbc;

    // GET /api/races?season_id=1
    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getRaces(
            @RequestParam(required = false) Integer seasonId) {
        String sql = """
            SELECT r.*, ci.circuit_name, ci.city, ci.track_length_km, ci.circuit_type,
                   co.country_name AS circuit_country,
                   s.season_year, ch.champ_name, ch.category,
                   COUNT(rr.result_id) AS result_count
            FROM race r
            JOIN circuit ci ON r.circuit_id = ci.circuit_id
            JOIN country co ON ci.country_id = co.country_id
            JOIN season s   ON r.season_id   = s.season_id
            JOIN championship ch ON s.championship_id = ch.championship_id
            LEFT JOIN race_result rr ON r.race_id = rr.race_id
            """ + (seasonId != null ? "WHERE r.season_id = " + seasonId + " " : "")
            + "GROUP BY r.race_id, ci.circuit_name, ci.city, ci.track_length_km, ci.circuit_type, co.country_name, s.season_year, ch.champ_name, ch.category ORDER BY r.race_date ASC";
        return ResponseEntity.ok(jdbc.queryForList(sql));
    }

    // POST /api/races — add new race
    @PostMapping
    public ResponseEntity<Map<String, Object>> addRace(@RequestBody Map<String, Object> body) {
        String sql = """
            INSERT INTO race (season_id, circuit_id, race_name, race_date, round_number, total_laps, distance_km, status)
            VALUES (?,?,?,?,?,?,?,'Scheduled')
            """;
        jdbc.update(sql,
            body.get("season_id"), body.get("circuit_id"), body.get("race_name"),
            body.get("race_date"),  body.get("round_number"),
            body.get("total_laps"), body.get("distance_km"));
        return ResponseEntity.ok(Map.of("success", true));
    }
}

// ── RESULTS CONTROLLER ────────────────────────────────────────────────────────
@RestController
@RequestMapping("/api/results")
class ResultsController {

    @Autowired JdbcTemplate jdbc;

    // GET /api/results?season_id=1&race_id=1
    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getResults(
            @RequestParam(required = false) Integer seasonId,
            @RequestParam(required = false) Integer raceId) {
        String sql = "SELECT * FROM v_race_results_full WHERE 1=1"
            + (raceId   != null ? " AND race_id = "   + raceId   : "")
            + (seasonId != null ? " AND season_id = " + seasonId : "")
            + " ORDER BY race_date DESC, finishing_position ASC";
        return ResponseEntity.ok(jdbc.queryForList(sql));
    }

    // POST /api/results — insert result (triggers fire automatically)
    @PostMapping
    public ResponseEntity<Map<String, Object>> addResult(@RequestBody Map<String, Object> body) {
        String sql = """
            INSERT INTO race_result
                (race_id, driver_id, team_id, finishing_position, grid_position,
                 points_earned, laps_completed, status, fastest_lap)
            VALUES (?,?,?,?,?,?,?,?,?)
            ON DUPLICATE KEY UPDATE
                finishing_position = VALUES(finishing_position),
                grid_position      = VALUES(grid_position),
                points_earned      = VALUES(points_earned),
                laps_completed     = VALUES(laps_completed),
                status             = VALUES(status),
                fastest_lap        = VALUES(fastest_lap)
            """;
        jdbc.update(sql,
            body.get("race_id"),           body.get("driver_id"),
            body.get("team_id"),           body.get("finishing_position"),
            body.get("grid_position"),     body.get("points_earned"),
            body.get("laps_completed"),    body.getOrDefault("status", "Finished"),
            body.getOrDefault("fastest_lap", false));
        return ResponseEntity.ok(Map.of(
            "success", true,
            "message", "Result saved — standings trigger fired automatically"));
    }
}

// ── TEAMS CONTROLLER ──────────────────────────────────────────────────────────
@RestController
@RequestMapping("/api/teams")
class TeamsController {

    @Autowired JdbcTemplate jdbc;

    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getTeams() {
        String sql = """
            SELECT t.*, co.country_name,
                   COALESCE(SUM(rr.points_earned),0) AS total_points,
                   COUNT(CASE WHEN rr.finishing_position=1 THEN 1 END) AS wins
            FROM team t
            LEFT JOIN country co     ON t.country_id = co.country_id
            LEFT JOIN race_result rr ON t.team_id    = rr.team_id
            GROUP BY t.team_id, co.country_name
            ORDER BY total_points DESC
            """;
        return ResponseEntity.ok(jdbc.queryForList(sql));
    }
}

// ── CIRCUITS CONTROLLER ───────────────────────────────────────────────────────
@RestController
@RequestMapping("/api/circuits")
class CircuitsController {

    @Autowired JdbcTemplate jdbc;

    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getCircuits() {
        String sql = """
            SELECT ci.*, co.country_name,
                   COUNT(DISTINCT r.race_id) AS times_hosted
            FROM circuit ci
            LEFT JOIN country co ON ci.country_id = co.country_id
            LEFT JOIN race r     ON ci.circuit_id = r.circuit_id
            GROUP BY ci.circuit_id, co.country_name
            ORDER BY times_hosted DESC
            """;
        return ResponseEntity.ok(jdbc.queryForList(sql));
    }
}

// ── SEASONS CONTROLLER ────────────────────────────────────────────────────────
@RestController
@RequestMapping("/api/seasons")
class SeasonsController {

    @Autowired JdbcTemplate jdbc;

    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getSeasons(
            @RequestParam(required = false) Integer championshipId) {
        String sql = """
            SELECT s.*, c.champ_name, c.category,
                   COUNT(DISTINCT r.race_id) AS race_count
            FROM season s
            JOIN championship c ON s.championship_id = c.championship_id
            LEFT JOIN race r    ON s.season_id       = r.season_id
            """ + (championshipId != null ? "WHERE s.championship_id = " + championshipId + " " : "")
            + "GROUP BY s.season_id, c.champ_name, c.category ORDER BY s.season_year DESC";
        return ResponseEntity.ok(jdbc.queryForList(sql));
    }
}

// ── ANALYTICS CONTROLLER ──────────────────────────────────────────────────────
@RestController
@RequestMapping("/api/analytics")
class AnalyticsController {

    @Autowired AnalyticsRepository analyticsRepo;

    @GetMapping("/summary")
    public ResponseEntity<Map<String, Object>> summary() {
        return ResponseEntity.ok(analyticsRepo.getDashboardSummary());
    }

    @GetMapping("/cumulative-points")
    public ResponseEntity<List<Map<String, Object>>> cumulativePoints(
            @RequestParam(defaultValue = "1") int seasonId) {
        return ResponseEntity.ok(analyticsRepo.getCumulativePoints(seasonId));
    }

    @GetMapping("/position-changes")
    public ResponseEntity<List<Map<String, Object>>> positionChanges(
            @RequestParam(defaultValue = "1") int seasonId) {
        return ResponseEntity.ok(analyticsRepo.getPositionChanges(seasonId));
    }

    @GetMapping("/rankings")
    public ResponseEntity<List<Map<String, Object>>> rankings(
            @RequestParam(defaultValue = "1") int seasonId) {
        return ResponseEntity.ok(analyticsRepo.getChampionshipRankings(seasonId));
    }

    @GetMapping("/team-rank")
    public ResponseEntity<List<Map<String, Object>>> teamRank(
            @RequestParam(defaultValue = "1") int seasonId) {
        return ResponseEntity.ok(analyticsRepo.getDriverRankWithinTeam(seasonId));
    }

    @GetMapping("/teammate-h2h")
    public ResponseEntity<List<Map<String, Object>>> h2h(
            @RequestParam(defaultValue = "1") int seasonId) {
        return ResponseEntity.ok(analyticsRepo.getTeammateH2H(seasonId));
    }

    @GetMapping("/pit-stops")
    public ResponseEntity<List<Map<String, Object>>> pitStops() {
        return ResponseEntity.ok(analyticsRepo.getPitStopImpact());
    }

    @GetMapping("/circuit-winners")
    public ResponseEntity<List<Map<String, Object>>> circuitWinners() {
        return ResponseEntity.ok(analyticsRepo.getCircuitWinners());
    }

    @GetMapping("/audit-log")
    public ResponseEntity<List<Map<String, Object>>> auditLog() {
        return ResponseEntity.ok(analyticsRepo.getAuditLog());
    }
}

// ── ADMIN CONTROLLER ──────────────────────────────────────────────────────────
@RestController
@RequestMapping("/api/admin")
class AdminController {

    @Autowired AnalyticsRepository analyticsRepo;

    // POST /api/admin/assign-rankings — calls stored procedure
    @PostMapping("/assign-rankings")
    public ResponseEntity<Map<String, Object>> assignRankings(@RequestBody Map<String, Object> body) {
        int seasonId = Integer.parseInt(body.get("season_id").toString());
        String result = analyticsRepo.callAssignRankings(seasonId);
        return ResponseEntity.ok(Map.of("success", true, "message", result));
    }

    // GET /api/admin/driver-avg?driver_id=1&season_id=1 — calls function
    @GetMapping("/driver-avg")
    public ResponseEntity<Map<String, Object>> driverAvg(
            @RequestParam int driverId,
            @RequestParam int seasonId) {
        double avg = analyticsRepo.callDriverAvgPoints(driverId, seasonId);
        return ResponseEntity.ok(Map.of("driver_id", driverId, "season_id", seasonId, "avg_points", avg));
    }

    // GET /api/admin/circuit-best?circuit_id=1 — calls function
    @GetMapping("/circuit-best")
    public ResponseEntity<Map<String, Object>> circuitBest(@RequestParam int circuitId) {
        String lap = analyticsRepo.callCircuitBestLap(circuitId);
        return ResponseEntity.ok(Map.of("circuit_id", circuitId, "best_lap_time", lap));
    }
}
