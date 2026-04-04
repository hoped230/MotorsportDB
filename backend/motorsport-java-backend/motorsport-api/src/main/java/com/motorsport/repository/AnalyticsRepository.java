package com.motorsport.repository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

/**
 * AnalyticsRepository
 * Demonstrates:
 *   - Window functions: SUM OVER, LAG, DENSE_RANK, ROW_NUMBER
 *   - CTEs (MySQL 8 WITH clause)
 *   - Self joins
 *   - Stored procedure calls via JDBC
 *   - Function calls via JDBC
 */
@Repository
public class AnalyticsRepository {

    @Autowired
    private JdbcTemplate jdbc;

    // ── WINDOW FUNCTION: SUM OVER — Cumulative points progression ──
    public List<Map<String, Object>> getCumulativePoints(int seasonId) {
        String sql = """
            SELECT driver_id, driver_name, team_name, round_number,
                   SUM(points_earned) OVER (
                       PARTITION BY driver_id
                       ORDER BY round_number
                       ROWS UNBOUNDED PRECEDING
                   ) AS cumulative_points
            FROM (
                SELECT rr.driver_id,
                       CONCAT(d.first_name,' ',d.last_name) AS driver_name,
                       t.team_name,
                       r.round_number,
                       rr.points_earned
                FROM race_result rr
                JOIN race r   ON rr.race_id   = r.race_id
                JOIN driver d ON rr.driver_id  = d.driver_id
                LEFT JOIN team t ON rr.team_id = t.team_id
                WHERE r.season_id = ?
            ) pts
            ORDER BY round_number, cumulative_points DESC
            """;
        return jdbc.queryForList(sql, seasonId);
    }

    // ── WINDOW FUNCTION: LAG — Position change per round ──────────
    public List<Map<String, Object>> getPositionChanges(int seasonId) {
        String sql = """
            SELECT ds.driver_id,
                   CONCAT(d.first_name,' ',d.last_name) AS driver_name,
                   t.team_name,
                   ds.after_round,
                   ds.position,
                   ds.total_points,
                   LAG(ds.position) OVER (
                       PARTITION BY ds.driver_id ORDER BY ds.after_round
                   ) AS prev_position,
                   ds.position - LAG(ds.position) OVER (
                       PARTITION BY ds.driver_id ORDER BY ds.after_round
                   ) AS position_change
            FROM driver_standing ds
            JOIN driver d    ON ds.driver_id = d.driver_id
            LEFT JOIN team t ON ds.team_id   = t.team_id
            WHERE ds.season_id = ?
            ORDER BY ds.after_round, ds.position
            """;
        return jdbc.queryForList(sql, seasonId);
    }

    // ── WINDOW FUNCTION: DENSE_RANK — Championship rankings ───────
    public List<Map<String, Object>> getChampionshipRankings(int seasonId) {
        String sql = """
            SELECT
                DENSE_RANK() OVER (PARTITION BY ds.season_id ORDER BY ds.total_points DESC) AS champ_rank,
                CONCAT(d.first_name,' ',d.last_name) AS driver_name,
                d.abbreviation,
                t.team_name,
                ds.total_points,
                ds.wins,
                ds.podiums
            FROM driver_standing ds
            JOIN driver d    ON ds.driver_id = d.driver_id
            LEFT JOIN team t ON ds.team_id   = t.team_id
            WHERE ds.season_id = ?
              AND ds.after_round = (
                  SELECT MAX(after_round) FROM driver_standing WHERE season_id = ?
              )
            ORDER BY champ_rank
            """;
        return jdbc.queryForList(sql, seasonId, seasonId);
    }

    // ── WINDOW FUNCTION: ROW_NUMBER per team ──────────────────────
    public List<Map<String, Object>> getDriverRankWithinTeam(int seasonId) {
        String sql = """
            SELECT team_name, driver_name, total_points,
                   ROW_NUMBER() OVER (PARTITION BY team_name ORDER BY total_points DESC) AS team_rank
            FROM (
                SELECT t.team_name,
                       CONCAT(d.first_name,' ',d.last_name) AS driver_name,
                       ds.total_points
                FROM driver_standing ds
                JOIN driver d    ON ds.driver_id = d.driver_id
                LEFT JOIN team t ON ds.team_id   = t.team_id
                WHERE ds.season_id = ?
                  AND ds.after_round = (
                      SELECT MAX(after_round) FROM driver_standing WHERE season_id = ?
                  )
            ) ranked
            ORDER BY team_name, team_rank
            """;
        return jdbc.queryForList(sql, seasonId, seasonId);
    }

    // ── SELF JOIN — Teammate head-to-head comparison ───────────────
    public List<Map<String, Object>> getTeammateH2H(int seasonId) {
        String sql = """
            SELECT
                CONCAT(d1.first_name,' ',d1.last_name) AS driver1,
                CONCAT(d2.first_name,' ',d2.last_name) AS driver2,
                t.team_name,
                COUNT(CASE WHEN rr1.finishing_position < rr2.finishing_position THEN 1 END) AS d1_ahead,
                COUNT(CASE WHEN rr2.finishing_position < rr1.finishing_position THEN 1 END) AS d2_ahead,
                COUNT(rr1.result_id) AS races_together
            FROM team_driver td1
            JOIN team_driver td2
                ON td1.team_id   = td2.team_id
               AND td1.season_id = td2.season_id
               AND td1.driver_id < td2.driver_id
            JOIN driver d1   ON td1.driver_id = d1.driver_id
            JOIN driver d2   ON td2.driver_id = d2.driver_id
            JOIN team t      ON td1.team_id   = t.team_id
            JOIN race_result rr1 ON rr1.driver_id = td1.driver_id
            JOIN race_result rr2
                ON rr2.driver_id = td2.driver_id
               AND rr1.race_id   = rr2.race_id
            WHERE td1.season_id = ?
            GROUP BY d1.driver_id, d2.driver_id, t.team_name
            """;
        return jdbc.queryForList(sql, seasonId);
    }

    // ── CTE — Pit stop strategy impact ────────────────────────────
    public List<Map<String, Object>> getPitStopImpact() {
        String sql = """
            WITH stop_counts AS (
                SELECT race_id, driver_id, MAX(stop_number) AS stop_count
                FROM pit_stop
                GROUP BY race_id, driver_id
            )
            SELECT sc.stop_count,
                   ROUND(AVG(rr.finishing_position), 2) AS avg_finish_position,
                   COUNT(*)                             AS sample_size
            FROM stop_counts sc
            JOIN race_result rr
                ON rr.race_id   = sc.race_id
               AND rr.driver_id = sc.driver_id
            GROUP BY sc.stop_count
            HAVING COUNT(*) >= 1
            ORDER BY sc.stop_count
            """;
        return jdbc.queryForList(sql);
    }

    // ── CTE — Top performer per circuit ───────────────────────────
    public List<Map<String, Object>> getCircuitWinners() {
        String sql = """
            WITH circuit_wins AS (
                SELECT r.circuit_id,
                       rr.driver_id,
                       COUNT(*) AS wins
                FROM race_result rr
                JOIN race r ON rr.race_id = r.race_id
                WHERE rr.finishing_position = 1
                GROUP BY r.circuit_id, rr.driver_id
            ),
            ranked_wins AS (
                SELECT cw.*,
                       RANK() OVER (PARTITION BY circuit_id ORDER BY wins DESC) AS win_rank
                FROM circuit_wins cw
            )
            SELECT ci.circuit_name,
                   CONCAT(d.first_name,' ',d.last_name) AS driver_name,
                   rw.wins
            FROM ranked_wins rw
            JOIN circuit ci ON rw.circuit_id = ci.circuit_id
            JOIN driver d   ON rw.driver_id  = d.driver_id
            WHERE rw.win_rank = 1
            ORDER BY rw.wins DESC
            """;
        return jdbc.queryForList(sql);
    }

    // ── STORED PROCEDURE CALL — Assign final rankings ─────────────
    public String callAssignRankings(int seasonId) {
        String sql = "CALL sp_assign_final_rankings(?)";
        List<Map<String, Object>> result = jdbc.queryForList(sql, seasonId);
        if (!result.isEmpty()) {
            return result.get(0).get("result").toString();
        }
        return "Procedure executed for season " + seasonId;
    }

    // ── FUNCTION CALL — Driver average points ─────────────────────
    public Double callDriverAvgPoints(int driverId, int seasonId) {
        String sql = "SELECT fn_driver_avg_points(?, ?) AS avg_pts";
        Map<String, Object> row = jdbc.queryForMap(sql, driverId, seasonId);
        Object val = row.get("avg_pts");
        return val != null ? Double.parseDouble(val.toString()) : 0.0;
    }

    // ── FUNCTION CALL — Circuit best lap ─────────────────────────
    public String callCircuitBestLap(int circuitId) {
        String sql = "SELECT fn_circuit_best_lap(?) AS best_lap";
        Map<String, Object> row = jdbc.queryForMap(sql, circuitId);
        Object val = row.get("best_lap");
        return val != null ? val.toString() : "No record";
    }

    // ── AUDIT LOG query ───────────────────────────────────────────
    public List<Map<String, Object>> getAuditLog() {
        String sql = """
            SELECT log_id, action, table_name, record_id,
                   action_time, ip_address, old_values, new_values
            FROM audit_log
            ORDER BY action_time DESC
            LIMIT 50
            """;
        return jdbc.queryForList(sql);
    }

    // ── Summary stats for dashboard ───────────────────────────────
    public Map<String, Object> getDashboardSummary() {
        String sql = """
            SELECT
                (SELECT COUNT(*) FROM driver)                           AS total_drivers,
                (SELECT COUNT(*) FROM team)                             AS total_teams,
                (SELECT COUNT(*) FROM race WHERE status = 'Completed')  AS completed_races,
                (SELECT COUNT(*) FROM race_result)                      AS total_results,
                (SELECT COUNT(*) FROM championship)                     AS total_championships
            """;
        return jdbc.queryForMap(sql);
    }
}
