-- ============================================================
--  MOTORSPORTS CHAMPIONSHIP MANAGEMENT & ANALYTICS SYSTEM
--  MySQL 8.0+ Schema — 35 Tables
--  Run: mysql -u root -p motorsport < motorsport_mysql.sql
-- ============================================================

CREATE DATABASE IF NOT EXISTS motorsport
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE motorsport;

SET FOREIGN_KEY_CHECKS = 0;

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS system_user;
DROP TABLE IF EXISTS user_role;
DROP TABLE IF EXISTS tire_strategy;
DROP TABLE IF EXISTS tire_compound;
DROP TABLE IF EXISTS weather;
DROP TABLE IF EXISTS race_award;
DROP TABLE IF EXISTS award_type;
DROP TABLE IF EXISTS team_sponsor;
DROP TABLE IF EXISTS sponsor;
DROP TABLE IF EXISTS constructor_standing;
DROP TABLE IF EXISTS driver_standing;
DROP TABLE IF EXISTS vehicle_spec;
DROP TABLE IF EXISTS engine_supplier;
DROP TABLE IF EXISTS team_staff;
DROP TABLE IF EXISTS staff;
DROP TABLE IF EXISTS staff_role;
DROP TABLE IF EXISTS penalty;
DROP TABLE IF EXISTS fastest_lap;
DROP TABLE IF EXISTS pit_stop;
DROP TABLE IF EXISTS lap_time;
DROP TABLE IF EXISTS qualifying_result;
DROP TABLE IF EXISTS qualifying_session;
DROP TABLE IF EXISTS points_system_detail;
DROP TABLE IF EXISTS points_system;
DROP TABLE IF EXISTS race_result;
DROP TABLE IF EXISTS race;
DROP TABLE IF EXISTS circuit;
DROP TABLE IF EXISTS team_driver;
DROP TABLE IF EXISTS driver;
DROP TABLE IF EXISTS championship_team;
DROP TABLE IF EXISTS team;
DROP TABLE IF EXISTS season;
DROP TABLE IF EXISTS championship;
DROP TABLE IF EXISTS country;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- SECTION 1 — CORE (10 tables)
-- ============================================================

-- Table 1: country
CREATE TABLE country (
    country_id    INT          AUTO_INCREMENT PRIMARY KEY,
    country_name  VARCHAR(100) NOT NULL UNIQUE,
    country_code  CHAR(3)      NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Table 2: championship
CREATE TABLE championship (
    championship_id  INT          AUTO_INCREMENT PRIMARY KEY,
    champ_name       VARCHAR(100) NOT NULL,
    category         VARCHAR(50)  NOT NULL,
    governing_body   VARCHAR(100),
    founded_year     SMALLINT,
    official_website VARCHAR(200),
    CONSTRAINT chk_category CHECK (category IN ('Formula1','MotoGP','NASCAR','WEC','WSBK'))
) ENGINE=InnoDB;

-- Table 3: season
CREATE TABLE season (
    season_id       INT      AUTO_INCREMENT PRIMARY KEY,
    championship_id INT      NOT NULL,
    season_year     SMALLINT NOT NULL,
    start_date      DATE,
    end_date        DATE,
    total_rounds    SMALLINT,
    UNIQUE KEY uq_season (championship_id, season_year),
    CONSTRAINT fk_season_champ FOREIGN KEY (championship_id)
        REFERENCES championship(championship_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table 4: team
CREATE TABLE team (
    team_id       INT          AUTO_INCREMENT PRIMARY KEY,
    team_name     VARCHAR(100) NOT NULL,
    country_id    INT,
    base_location VARCHAR(150),
    founded_year  SMALLINT,
    principal     VARCHAR(100),
    logo_url      VARCHAR(255),
    CONSTRAINT fk_team_country FOREIGN KEY (country_id)
        REFERENCES country(country_id)
) ENGINE=InnoDB;

-- Table 5: championship_team  [Junction: season <-> team]
CREATE TABLE championship_team (
    ct_id        INT AUTO_INCREMENT PRIMARY KEY,
    season_id    INT NOT NULL,
    team_id      INT NOT NULL,
    entry_number SMALLINT,
    UNIQUE KEY uq_ct (season_id, team_id),
    CONSTRAINT fk_ct_season FOREIGN KEY (season_id)
        REFERENCES season(season_id) ON DELETE CASCADE,
    CONSTRAINT fk_ct_team FOREIGN KEY (team_id)
        REFERENCES team(team_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table 6: driver
CREATE TABLE driver (
    driver_id       INT          AUTO_INCREMENT PRIMARY KEY,
    first_name      VARCHAR(80)  NOT NULL,
    last_name       VARCHAR(80)  NOT NULL,
    nationality_id  INT,
    date_of_birth   DATE,
    driver_number   SMALLINT,
    abbreviation    CHAR(3),
    bio             TEXT,
    profile_img_url VARCHAR(255),
    CONSTRAINT fk_driver_country FOREIGN KEY (nationality_id)
        REFERENCES country(country_id)
) ENGINE=InnoDB;

-- Table 7: team_driver  [Junction: handles mid-season transfers]
CREATE TABLE team_driver (
    td_id      INT AUTO_INCREMENT PRIMARY KEY,
    team_id    INT NOT NULL,
    driver_id  INT NOT NULL,
    season_id  INT NOT NULL,
    start_date DATE,
    end_date   DATE,
    role       VARCHAR(50) DEFAULT 'Race Driver',
    CONSTRAINT fk_td_team   FOREIGN KEY (team_id)   REFERENCES team(team_id)     ON DELETE CASCADE,
    CONSTRAINT fk_td_driver FOREIGN KEY (driver_id) REFERENCES driver(driver_id) ON DELETE CASCADE,
    CONSTRAINT fk_td_season FOREIGN KEY (season_id) REFERENCES season(season_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table 8: circuit
CREATE TABLE circuit (
    circuit_id      INT          AUTO_INCREMENT PRIMARY KEY,
    circuit_name    VARCHAR(150) NOT NULL,
    country_id      INT,
    city            VARCHAR(100),
    track_length_km DECIMAL(7,3),
    lap_record_time VARCHAR(20),
    lap_record_year SMALLINT,
    circuit_type    VARCHAR(30),
    capacity        INT,
    map_url         VARCHAR(255),
    CONSTRAINT chk_circuit_type CHECK (circuit_type IN ('Street','Permanent','Oval','Mixed')),
    CONSTRAINT fk_circuit_country FOREIGN KEY (country_id)
        REFERENCES country(country_id)
) ENGINE=InnoDB;

-- Table 9: race
CREATE TABLE race (
    race_id      INT          AUTO_INCREMENT PRIMARY KEY,
    season_id    INT          NOT NULL,
    circuit_id   INT          NOT NULL,
    race_name    VARCHAR(150) NOT NULL,
    race_date    DATE,
    round_number SMALLINT,
    total_laps   SMALLINT,
    distance_km  DECIMAL(7,3),
    status       VARCHAR(30)  DEFAULT 'Scheduled',
    CONSTRAINT chk_race_status CHECK (status IN ('Scheduled','Completed','Cancelled','Postponed')),
    CONSTRAINT fk_race_season  FOREIGN KEY (season_id)  REFERENCES season(season_id)   ON DELETE CASCADE,
    CONSTRAINT fk_race_circuit FOREIGN KEY (circuit_id) REFERENCES circuit(circuit_id)
) ENGINE=InnoDB;

-- Table 10: race_result
CREATE TABLE race_result (
    result_id          INT          AUTO_INCREMENT PRIMARY KEY,
    race_id            INT          NOT NULL,
    driver_id          INT          NOT NULL,
    team_id            INT,
    finishing_position SMALLINT,
    grid_position      SMALLINT,
    points_earned      DECIMAL(5,2) DEFAULT 0,
    laps_completed     SMALLINT,
    race_time          VARCHAR(20),
    gap_to_leader      VARCHAR(20),
    status             VARCHAR(50)  DEFAULT 'Finished',
    fastest_lap        TINYINT(1)   DEFAULT 0,
    UNIQUE KEY uq_result (race_id, driver_id),
    CONSTRAINT fk_rr_race   FOREIGN KEY (race_id)   REFERENCES race(race_id)     ON DELETE CASCADE,
    CONSTRAINT fk_rr_driver FOREIGN KEY (driver_id) REFERENCES driver(driver_id),
    CONSTRAINT fk_rr_team   FOREIGN KEY (team_id)   REFERENCES team(team_id)
) ENGINE=InnoDB;

CREATE INDEX idx_rr_race   ON race_result(race_id);
CREATE INDEX idx_rr_driver ON race_result(driver_id);

-- ============================================================
-- SECTION 2 — EXTENDED RACING (8 tables)
-- ============================================================

-- Table 11: points_system
CREATE TABLE points_system (
    ps_id           INT          AUTO_INCREMENT PRIMARY KEY,
    championship_id INT          NOT NULL,
    system_name     VARCHAR(100),
    valid_from_year SMALLINT,
    valid_to_year   SMALLINT,
    bonus_points    TINYINT(1)   DEFAULT 0,
    CONSTRAINT fk_ps_champ FOREIGN KEY (championship_id)
        REFERENCES championship(championship_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table 12: points_system_detail
CREATE TABLE points_system_detail (
    psd_id         INT          AUTO_INCREMENT PRIMARY KEY,
    ps_id          INT          NOT NULL,
    finishing_pos  SMALLINT     NOT NULL,
    points_awarded DECIMAL(5,2) NOT NULL,
    UNIQUE KEY uq_psd (ps_id, finishing_pos),
    CONSTRAINT fk_psd_ps FOREIGN KEY (ps_id)
        REFERENCES points_system(ps_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table 13: qualifying_session
CREATE TABLE qualifying_session (
    qs_id        INT         AUTO_INCREMENT PRIMARY KEY,
    race_id      INT         NOT NULL,
    session_type VARCHAR(20) NOT NULL,
    session_date DATE,
    session_time TIME,
    CONSTRAINT chk_qs_type CHECK (session_type IN ('Q1','Q2','Q3','Superpole','Single-lap')),
    CONSTRAINT fk_qs_race FOREIGN KEY (race_id)
        REFERENCES race(race_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table 14: qualifying_result
CREATE TABLE qualifying_result (
    qr_id      INT        AUTO_INCREMENT PRIMARY KEY,
    qs_id      INT        NOT NULL,
    driver_id  INT        NOT NULL,
    team_id    INT,
    lap_time   VARCHAR(20),
    position   SMALLINT,
    eliminated TINYINT(1) DEFAULT 0,
    UNIQUE KEY uq_qr (qs_id, driver_id),
    CONSTRAINT fk_qr_qs     FOREIGN KEY (qs_id)     REFERENCES qualifying_session(qs_id) ON DELETE CASCADE,
    CONSTRAINT fk_qr_driver FOREIGN KEY (driver_id) REFERENCES driver(driver_id),
    CONSTRAINT fk_qr_team   FOREIGN KEY (team_id)   REFERENCES team(team_id)
) ENGINE=InnoDB;

-- Table 15: lap_time  [BIGINT — high volume]
CREATE TABLE lap_time (
    lt_id      BIGINT       AUTO_INCREMENT PRIMARY KEY,
    race_id    INT          NOT NULL,
    driver_id  INT          NOT NULL,
    lap_number SMALLINT     NOT NULL,
    lap_time   VARCHAR(20)  NOT NULL,
    position   SMALLINT,
    UNIQUE KEY uq_lt (race_id, driver_id, lap_number),
    CONSTRAINT fk_lt_race   FOREIGN KEY (race_id)   REFERENCES race(race_id)     ON DELETE CASCADE,
    CONSTRAINT fk_lt_driver FOREIGN KEY (driver_id) REFERENCES driver(driver_id)
) ENGINE=InnoDB;

CREATE INDEX idx_lt_race   ON lap_time(race_id);
CREATE INDEX idx_lt_driver ON lap_time(driver_id);

-- Table 16: pit_stop
CREATE TABLE pit_stop (
    ps_id           INT        AUTO_INCREMENT PRIMARY KEY,
    race_id         INT        NOT NULL,
    driver_id       INT        NOT NULL,
    stop_number     SMALLINT   NOT NULL,
    lap_number      SMALLINT   NOT NULL,
    pit_duration    VARCHAR(20),
    total_time_lost VARCHAR(20),
    CONSTRAINT fk_pit_race   FOREIGN KEY (race_id)   REFERENCES race(race_id)     ON DELETE CASCADE,
    CONSTRAINT fk_pit_driver FOREIGN KEY (driver_id) REFERENCES driver(driver_id)
) ENGINE=InnoDB;

CREATE INDEX idx_pit_race ON pit_stop(race_id);

-- Table 17: fastest_lap  [UNIQUE race_id — one per race]
CREATE TABLE fastest_lap (
    fl_id      INT         AUTO_INCREMENT PRIMARY KEY,
    race_id    INT         NOT NULL UNIQUE,
    driver_id  INT         NOT NULL,
    team_id    INT,
    lap_number SMALLINT,
    lap_time   VARCHAR(20) NOT NULL,
    CONSTRAINT fk_fl_race   FOREIGN KEY (race_id)   REFERENCES race(race_id)     ON DELETE CASCADE,
    CONSTRAINT fk_fl_driver FOREIGN KEY (driver_id) REFERENCES driver(driver_id),
    CONSTRAINT fk_fl_team   FOREIGN KEY (team_id)   REFERENCES team(team_id)
) ENGINE=InnoDB;

-- Table 18: penalty
CREATE TABLE penalty (
    penalty_id     INT         AUTO_INCREMENT PRIMARY KEY,
    race_id        INT         NOT NULL,
    driver_id      INT         NOT NULL,
    penalty_type   VARCHAR(80),
    time_penalty_s SMALLINT,
    reason         TEXT,
    lap_issued     SMALLINT,
    upheld         TINYINT(1)  DEFAULT 1,
    CONSTRAINT fk_pen_race   FOREIGN KEY (race_id)   REFERENCES race(race_id)     ON DELETE CASCADE,
    CONSTRAINT fk_pen_driver FOREIGN KEY (driver_id) REFERENCES driver(driver_id)
) ENGINE=InnoDB;

-- ============================================================
-- SECTION 3 — TEAM & PERSONNEL (5 tables)
-- ============================================================

-- Table 19: staff_role
CREATE TABLE staff_role (
    role_id       INT         AUTO_INCREMENT PRIMARY KEY,
    role_name     VARCHAR(80) NOT NULL UNIQUE,
    role_category VARCHAR(50)
) ENGINE=InnoDB;

-- Table 20: staff
CREATE TABLE staff (
    staff_id       INT         AUTO_INCREMENT PRIMARY KEY,
    first_name     VARCHAR(80) NOT NULL,
    last_name      VARCHAR(80) NOT NULL,
    nationality_id INT,
    date_of_birth  DATE,
    role_id        INT,
    bio            TEXT,
    CONSTRAINT fk_staff_country FOREIGN KEY (nationality_id) REFERENCES country(country_id),
    CONSTRAINT fk_staff_role   FOREIGN KEY (role_id)        REFERENCES staff_role(role_id)
) ENGINE=InnoDB;

-- Table 21: team_staff  [Junction: team <-> staff per season]
CREATE TABLE team_staff (
    ts_id      INT AUTO_INCREMENT PRIMARY KEY,
    team_id    INT NOT NULL,
    staff_id   INT NOT NULL,
    season_id  INT NOT NULL,
    start_date DATE,
    end_date   DATE,
    UNIQUE KEY uq_ts (team_id, staff_id, season_id),
    CONSTRAINT fk_ts_team   FOREIGN KEY (team_id)   REFERENCES team(team_id)     ON DELETE CASCADE,
    CONSTRAINT fk_ts_staff  FOREIGN KEY (staff_id)  REFERENCES staff(staff_id)   ON DELETE CASCADE,
    CONSTRAINT fk_ts_season FOREIGN KEY (season_id) REFERENCES season(season_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table 22: engine_supplier
CREATE TABLE engine_supplier (
    supplier_id   INT          AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    country_id    INT,
    founded_year  SMALLINT,
    CONSTRAINT fk_eng_country FOREIGN KEY (country_id) REFERENCES country(country_id)
) ENGINE=InnoDB;

-- Table 23: vehicle_spec
CREATE TABLE vehicle_spec (
    spec_id         INT          AUTO_INCREMENT PRIMARY KEY,
    team_id         INT          NOT NULL,
    season_id       INT          NOT NULL,
    supplier_id     INT,
    chassis_name    VARCHAR(100),
    engine_name     VARCHAR(100),
    power_unit_type VARCHAR(50),
    weight_kg       DECIMAL(6,2),
    UNIQUE KEY uq_vs (team_id, season_id),
    CONSTRAINT fk_vs_team     FOREIGN KEY (team_id)     REFERENCES team(team_id)             ON DELETE CASCADE,
    CONSTRAINT fk_vs_season   FOREIGN KEY (season_id)   REFERENCES season(season_id)         ON DELETE CASCADE,
    CONSTRAINT fk_vs_supplier FOREIGN KEY (supplier_id) REFERENCES engine_supplier(supplier_id)
) ENGINE=InnoDB;

-- ============================================================
-- SECTION 4 — STANDINGS (2 tables)
-- ============================================================

-- Table 24: driver_standing  [Snapshot per round — enables LAG() queries]
CREATE TABLE driver_standing (
    ds_id        INT          AUTO_INCREMENT PRIMARY KEY,
    season_id    INT          NOT NULL,
    driver_id    INT          NOT NULL,
    team_id      INT,
    total_points DECIMAL(7,2) DEFAULT 0,
    position     SMALLINT,
    wins         SMALLINT     DEFAULT 0,
    podiums      SMALLINT     DEFAULT 0,
    poles        SMALLINT     DEFAULT 0,
    fastest_laps SMALLINT     DEFAULT 0,
    after_round  SMALLINT,
    UNIQUE KEY uq_ds (season_id, driver_id, after_round),
    CONSTRAINT fk_ds_season FOREIGN KEY (season_id) REFERENCES season(season_id) ON DELETE CASCADE,
    CONSTRAINT fk_ds_driver FOREIGN KEY (driver_id) REFERENCES driver(driver_id),
    CONSTRAINT fk_ds_team   FOREIGN KEY (team_id)   REFERENCES team(team_id)
) ENGINE=InnoDB;

CREATE INDEX idx_ds_season ON driver_standing(season_id);

-- Table 25: constructor_standing
CREATE TABLE constructor_standing (
    cs_id        INT          AUTO_INCREMENT PRIMARY KEY,
    season_id    INT          NOT NULL,
    team_id      INT          NOT NULL,
    total_points DECIMAL(7,2) DEFAULT 0,
    position     SMALLINT,
    wins         SMALLINT     DEFAULT 0,
    after_round  SMALLINT,
    UNIQUE KEY uq_cs (season_id, team_id, after_round),
    CONSTRAINT fk_cs_season FOREIGN KEY (season_id) REFERENCES season(season_id) ON DELETE CASCADE,
    CONSTRAINT fk_cs_team   FOREIGN KEY (team_id)   REFERENCES team(team_id)
) ENGINE=InnoDB;

-- ============================================================
-- SECTION 5 — SPONSORS & AWARDS (4 tables)
-- ============================================================

-- Table 26: sponsor
CREATE TABLE sponsor (
    sponsor_id   INT          AUTO_INCREMENT PRIMARY KEY,
    sponsor_name VARCHAR(150) NOT NULL,
    industry     VARCHAR(80),
    country_id   INT,
    website      VARCHAR(200),
    CONSTRAINT fk_spon_country FOREIGN KEY (country_id) REFERENCES country(country_id)
) ENGINE=InnoDB;

-- Table 27: team_sponsor  [Junction: team <-> sponsor per season]
CREATE TABLE team_sponsor (
    tsp_id           INT           AUTO_INCREMENT PRIMARY KEY,
    team_id          INT           NOT NULL,
    sponsor_id       INT           NOT NULL,
    season_id        INT           NOT NULL,
    sponsorship_tier VARCHAR(30),
    contract_value   DECIMAL(15,2),
    UNIQUE KEY uq_tsp (team_id, sponsor_id, season_id),
    CONSTRAINT fk_tsp_team    FOREIGN KEY (team_id)    REFERENCES team(team_id)     ON DELETE CASCADE,
    CONSTRAINT fk_tsp_sponsor FOREIGN KEY (sponsor_id) REFERENCES sponsor(sponsor_id),
    CONSTRAINT fk_tsp_season  FOREIGN KEY (season_id)  REFERENCES season(season_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table 28: award_type
CREATE TABLE award_type (
    award_type_id INT          AUTO_INCREMENT PRIMARY KEY,
    award_name    VARCHAR(100) NOT NULL UNIQUE,
    description   TEXT,
    points_bonus  DECIMAL(4,2) DEFAULT 0
) ENGINE=InnoDB;

-- Table 29: race_award
CREATE TABLE race_award (
    ra_id         INT AUTO_INCREMENT PRIMARY KEY,
    race_id       INT NOT NULL,
    driver_id     INT NOT NULL,
    award_type_id INT NOT NULL,
    UNIQUE KEY uq_ra (race_id, award_type_id),
    CONSTRAINT fk_ra_race  FOREIGN KEY (race_id)       REFERENCES race(race_id)              ON DELETE CASCADE,
    CONSTRAINT fk_ra_driver FOREIGN KEY (driver_id)    REFERENCES driver(driver_id),
    CONSTRAINT fk_ra_award FOREIGN KEY (award_type_id) REFERENCES award_type(award_type_id)
) ENGINE=InnoDB;

-- ============================================================
-- SECTION 6 — CONDITIONS & TIRES (3 tables)
-- ============================================================

-- Table 30: weather
CREATE TABLE weather (
    weather_id     INT         AUTO_INCREMENT PRIMARY KEY,
    race_id        INT,
    session_type   VARCHAR(30),
    temperature_c  DECIMAL(4,1),
    track_temp_c   DECIMAL(4,1),
    humidity_pct   SMALLINT,
    wind_speed_kmh DECIMAL(5,1),
    condition_type VARCHAR(30),
    CONSTRAINT chk_weather CHECK (condition_type IN ('Sunny','Cloudy','Wet','Mixed','Foggy')),
    CONSTRAINT fk_weather_race FOREIGN KEY (race_id) REFERENCES race(race_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table 31: tire_compound
CREATE TABLE tire_compound (
    compound_id     INT         AUTO_INCREMENT PRIMARY KEY,
    championship_id INT         NOT NULL,
    compound_name   VARCHAR(50) NOT NULL,
    compound_color  VARCHAR(20),
    is_dry          TINYINT(1)  DEFAULT 1,
    CONSTRAINT fk_tc_champ FOREIGN KEY (championship_id)
        REFERENCES championship(championship_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table 32: tire_strategy
CREATE TABLE tire_strategy (
    ts_id        INT      AUTO_INCREMENT PRIMARY KEY,
    race_id      INT      NOT NULL,
    driver_id    INT      NOT NULL,
    compound_id  INT      NOT NULL,
    stint_number SMALLINT NOT NULL,
    start_lap    SMALLINT,
    end_lap      SMALLINT,
    laps_on_tire SMALLINT,
    CONSTRAINT fk_tstr_race     FOREIGN KEY (race_id)     REFERENCES race(race_id)             ON DELETE CASCADE,
    CONSTRAINT fk_tstr_driver   FOREIGN KEY (driver_id)   REFERENCES driver(driver_id),
    CONSTRAINT fk_tstr_compound FOREIGN KEY (compound_id) REFERENCES tire_compound(compound_id)
) ENGINE=InnoDB;

-- ============================================================
-- SECTION 7 — SYSTEM / ADMIN (3 tables)
-- ============================================================

-- Table 33: user_role
CREATE TABLE user_role (
    role_id    INT         AUTO_INCREMENT PRIMARY KEY,
    role_name  VARCHAR(50) NOT NULL UNIQUE,
    can_insert TINYINT(1)  DEFAULT 0,
    can_update TINYINT(1)  DEFAULT 0,
    can_delete TINYINT(1)  DEFAULT 0
) ENGINE=InnoDB;

-- Table 34: system_user
CREATE TABLE system_user (
    user_id       INT          AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(80)  NOT NULL UNIQUE,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role_id       INT          NOT NULL,
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    last_login    DATETIME,
    is_active     TINYINT(1)   DEFAULT 1,
    CONSTRAINT fk_su_role FOREIGN KEY (role_id) REFERENCES user_role(role_id)
) ENGINE=InnoDB;

-- Table 35: audit_log  [BIGINT — grows fast, JSON snapshots]
CREATE TABLE audit_log (
    log_id      BIGINT      AUTO_INCREMENT PRIMARY KEY,
    user_id     INT,
    action      VARCHAR(10) NOT NULL,
    table_name  VARCHAR(80),
    record_id   INT,
    old_values  JSON,
    new_values  JSON,
    action_time DATETIME    DEFAULT CURRENT_TIMESTAMP,
    ip_address  VARCHAR(45),
    CONSTRAINT chk_action CHECK (action IN ('INSERT','UPDATE','DELETE','LOGIN','LOGOUT')),
    CONSTRAINT fk_al_user FOREIGN KEY (user_id) REFERENCES system_user(user_id)
) ENGINE=InnoDB;

CREATE INDEX idx_audit_time ON audit_log(action_time);
CREATE INDEX idx_audit_user ON audit_log(user_id);

-- ============================================================
-- VIEWS
-- ============================================================

CREATE OR REPLACE VIEW v_driver_standings_latest AS
SELECT
    ds.season_id,
    s.season_year,
    c.champ_name,
    c.category,
    ds.position,
    CONCAT(d.first_name, ' ', d.last_name) AS driver_name,
    d.driver_number,
    d.abbreviation,
    co.country_name  AS nationality,
    t.team_name,
    ds.total_points,
    ds.wins,
    ds.podiums,
    ds.poles,
    ds.fastest_laps,
    ds.after_round
FROM driver_standing ds
JOIN season       s  ON ds.season_id      = s.season_id
JOIN championship c  ON s.championship_id = c.championship_id
JOIN driver       d  ON ds.driver_id      = d.driver_id
JOIN country      co ON d.nationality_id  = co.country_id
LEFT JOIN team    t  ON ds.team_id        = t.team_id
WHERE ds.after_round = (
    SELECT MAX(ds2.after_round)
    FROM driver_standing ds2
    WHERE ds2.season_id = ds.season_id
);

CREATE OR REPLACE VIEW v_constructor_standings_latest AS
SELECT
    cs.season_id,
    s.season_year,
    ch.champ_name,
    ch.category,
    cs.position,
    t.team_name,
    co.country_name AS team_country,
    cs.total_points,
    cs.wins,
    cs.after_round
FROM constructor_standing cs
JOIN season       s  ON cs.season_id       = s.season_id
JOIN championship ch ON s.championship_id  = ch.championship_id
JOIN team         t  ON cs.team_id         = t.team_id
LEFT JOIN country co ON t.country_id       = co.country_id
WHERE cs.after_round = (
    SELECT MAX(cs2.after_round)
    FROM constructor_standing cs2
    WHERE cs2.season_id = cs.season_id
);

CREATE OR REPLACE VIEW v_race_results_full AS
SELECT
    rr.result_id,
    r.race_id,
    r.race_name,
    r.race_date,
    r.round_number,
    r.total_laps,
    r.distance_km,
    s.season_id,
    s.season_year,
    ch.championship_id,
    ch.champ_name,
    ch.category,
    ci.circuit_name,
    ci.circuit_type,
    co2.country_name          AS circuit_country,
    rr.finishing_position,
    rr.grid_position,
    CONCAT(d.first_name,' ',d.last_name) AS driver_name,
    d.driver_id,
    d.driver_number,
    d.abbreviation,
    co.country_name           AS driver_nationality,
    t.team_name,
    rr.team_id,
    rr.points_earned,
    rr.laps_completed,
    rr.race_time,
    rr.gap_to_leader,
    rr.status                 AS result_status,
    rr.fastest_lap
FROM race_result  rr
JOIN race         r   ON rr.race_id    = r.race_id
JOIN season       s   ON r.season_id   = s.season_id
JOIN championship ch  ON s.championship_id = ch.championship_id
JOIN circuit      ci  ON r.circuit_id  = ci.circuit_id
JOIN country      co2 ON ci.country_id = co2.country_id
JOIN driver       d   ON rr.driver_id  = d.driver_id
JOIN country      co  ON d.nationality_id = co.country_id
LEFT JOIN team    t   ON rr.team_id    = t.team_id;

-- ============================================================
-- TRIGGERS
-- ============================================================

DELIMITER $$

-- Trigger 1: Auto-update driver_standing after race_result INSERT
CREATE TRIGGER trg_update_standings_insert
AFTER INSERT ON race_result
FOR EACH ROW
BEGIN
    DECLARE v_season_id  INT;
    DECLARE v_round      SMALLINT;
    DECLARE v_total_pts  DECIMAL(7,2);
    DECLARE v_wins       SMALLINT;
    DECLARE v_podiums    SMALLINT;

    SELECT season_id, round_number
    INTO v_season_id, v_round
    FROM race WHERE race_id = NEW.race_id;

    SELECT
        COALESCE(SUM(rr.points_earned), 0),
        COUNT(CASE WHEN rr.finishing_position = 1 THEN 1 END),
        COUNT(CASE WHEN rr.finishing_position <= 3 THEN 1 END)
    INTO v_total_pts, v_wins, v_podiums
    FROM race_result rr
    JOIN race r ON rr.race_id = r.race_id
    WHERE rr.driver_id = NEW.driver_id
      AND r.season_id  = v_season_id;

    INSERT INTO driver_standing
        (season_id, driver_id, team_id, total_points, wins, podiums, after_round)
    VALUES
        (v_season_id, NEW.driver_id, NEW.team_id, v_total_pts, v_wins, v_podiums, v_round)
    ON DUPLICATE KEY UPDATE
        total_points = VALUES(total_points),
        wins         = VALUES(wins),
        podiums      = VALUES(podiums),
        team_id      = VALUES(team_id);
END$$

-- Trigger 2: Audit log on race_result INSERT
CREATE TRIGGER trg_audit_rr_insert
AFTER INSERT ON race_result
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (action, table_name, record_id, new_values)
    VALUES (
        'INSERT',
        'race_result',
        NEW.result_id,
        JSON_OBJECT(
            'race_id',            NEW.race_id,
            'driver_id',          NEW.driver_id,
            'finishing_position', NEW.finishing_position,
            'points_earned',      NEW.points_earned,
            'status',             NEW.status
        )
    );
END$$

-- Trigger 3: Audit log on race_result UPDATE
CREATE TRIGGER trg_audit_rr_update
AFTER UPDATE ON race_result
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (action, table_name, record_id, old_values, new_values)
    VALUES (
        'UPDATE',
        'race_result',
        NEW.result_id,
        JSON_OBJECT(
            'finishing_position', OLD.finishing_position,
            'points_earned',      OLD.points_earned,
            'status',             OLD.status
        ),
        JSON_OBJECT(
            'finishing_position', NEW.finishing_position,
            'points_earned',      NEW.points_earned,
            'status',             NEW.status
        )
    );
END$$

-- Trigger 4: Audit log on race_result DELETE
CREATE TRIGGER trg_audit_rr_delete
BEFORE DELETE ON race_result
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (action, table_name, record_id, old_values)
    VALUES (
        'DELETE',
        'race_result',
        OLD.result_id,
        JSON_OBJECT(
            'race_id',            OLD.race_id,
            'driver_id',          OLD.driver_id,
            'finishing_position', OLD.finishing_position,
            'points_earned',      OLD.points_earned
        )
    );
END$$

DELIMITER ;

-- ============================================================
-- STORED PROCEDURES & FUNCTIONS
-- ============================================================

DELIMITER $$

-- Procedure: Assign final championship rankings (uses cursor)
CREATE PROCEDURE sp_assign_final_rankings(IN p_season_id INT)
BEGIN
    DECLARE v_driver_id  INT;
    DECLARE v_points     DECIMAL(7,2);
    DECLARE v_rank       INT DEFAULT 1;
    DECLARE v_max_round  SMALLINT;
    DECLARE done         INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT rr.driver_id, SUM(rr.points_earned) AS total
        FROM race_result rr
        JOIN race r ON rr.race_id = r.race_id
        WHERE r.season_id = p_season_id
        GROUP BY rr.driver_id
        ORDER BY total DESC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    SELECT MAX(round_number) INTO v_max_round
    FROM race WHERE season_id = p_season_id;

    OPEN cur;
    rank_loop: LOOP
        FETCH cur INTO v_driver_id, v_points;
        IF done THEN LEAVE rank_loop; END IF;

        UPDATE driver_standing
        SET position = v_rank
        WHERE season_id   = p_season_id
          AND driver_id   = v_driver_id
          AND after_round = v_max_round;

        SET v_rank = v_rank + 1;
    END LOOP;
    CLOSE cur;

    SELECT CONCAT('Rankings assigned for season ', p_season_id,
                  ' — ', v_rank - 1, ' drivers ranked.') AS result;
END$$

-- Function: Driver average points per race in a season
CREATE FUNCTION fn_driver_avg_points(
    p_driver_id INT,
    p_season_id INT
) RETURNS DECIMAL(6,3)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_avg DECIMAL(6,3);
    SELECT AVG(rr.points_earned) INTO v_avg
    FROM race_result rr
    JOIN race r ON rr.race_id = r.race_id
    WHERE rr.driver_id = p_driver_id
      AND r.season_id  = p_season_id;
    RETURN IFNULL(v_avg, 0);
END$$

-- Function: Get all-time fastest lap time at a circuit
CREATE FUNCTION fn_circuit_best_lap(p_circuit_id INT)
RETURNS VARCHAR(20)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_best VARCHAR(20);
    SELECT fl.lap_time INTO v_best
    FROM fastest_lap fl
    JOIN race r ON fl.race_id = r.race_id
    WHERE r.circuit_id = p_circuit_id
    ORDER BY fl.lap_time ASC
    LIMIT 1;
    RETURN IFNULL(v_best, 'No record');
END$$

DELIMITER ;

-- ============================================================
-- SAMPLE DATA
-- ============================================================

INSERT INTO country (country_name, country_code) VALUES
('United Kingdom', 'GBR'), ('Germany',      'DEU'), ('Netherlands', 'NLD'),
('Spain',          'ESP'), ('Monaco',        'MCO'), ('Italy',       'ITA'),
('France',         'FRA'), ('United States', 'USA'), ('Australia',   'AUS'),
('Brazil',         'BRA'), ('Mexico',        'MEX'), ('Japan',       'JPN'),
('Finland',        'FIN'), ('Austria',       'AUT'), ('Canada',      'CAN'),
('Bahrain',        'BHR'), ('Singapore',     'SGP'), ('UAE',         'ARE'),
('Saudi Arabia',   'SAU'), ('Hungary',       'HUN'), ('Malaysia',    'MYS'),
('Switzerland',    'CHE'), ('Denmark',       'DNK'), ('China',       'CHN');

INSERT INTO championship (champ_name, category, governing_body, founded_year, official_website) VALUES
('Formula One World Championship', 'Formula1', 'FIA',    1950, 'https://www.formula1.com'),
('MotoGP World Championship',      'MotoGP',   'FIM',    1949, 'https://www.motogp.com'),
('NASCAR Cup Series',              'NASCAR',   'NASCAR', 1949, 'https://www.nascar.com');

INSERT INTO season (championship_id, season_year, start_date, end_date, total_rounds) VALUES
(1, 2023, '2023-03-05', '2023-11-26', 22),
(1, 2024, '2024-03-02', '2024-12-08', 24),
(2, 2023, '2023-03-26', '2023-11-26', 20),
(3, 2023, '2023-02-05', '2023-11-05', 36);

-- F1 Teams
INSERT INTO team (team_name, country_id, base_location, founded_year, principal) VALUES
('Red Bull Racing',        1, 'Milton Keynes, UK',   1997, 'Christian Horner'),
('Mercedes-AMG Petronas',  2, 'Brackley, UK',        1954, 'Toto Wolff'),
('Scuderia Ferrari',       6, 'Maranello, Italy',    1929, 'Frederic Vasseur'),
('McLaren Racing',         1, 'Woking, UK',          1963, 'Andrea Stella'),
('Aston Martin Aramco',    1, 'Silverstone, UK',     2018, 'Mike Krack'),
('Alpine F1 Team',         7, 'Enstone, UK',         2021, 'Bruno Famin'),
('Williams Racing',        1, 'Grove, UK',           1977, 'James Vowles'),
('Visa Cash App RB',       6, 'Faenza, Italy',       1985, 'Laurent Mekies'),
('Stake F1 Kick',          9, 'Hinwil, Switzerland', 2019, 'Alessandro Alunni Bravi'),
('MoneyGram Haas F1',      8, 'Kannapolis, USA',     2016, 'Ayao Komatsu');

-- MotoGP Teams
INSERT INTO team (team_name, country_id, base_location, founded_year, principal) VALUES
('Repsol Honda',   12, 'Tokyo, Japan',   1982, 'Alberto Puig'),
('Monster Yamaha', 12, 'Gerno, Italy',   2004, 'Massimo Meregalli'),
('Ducati Lenovo',  6,  'Bologna, Italy', 2003, 'Davide Tardozzi'),
('Aprilia Racing', 6,  'Noale, Italy',   1960, 'Massimo Rivola');

-- NASCAR Teams
INSERT INTO team (team_name, country_id, base_location, founded_year, principal) VALUES
('Hendrick Motorsports', 8, 'Concord, NC',      1984, 'Rick Hendrick'),
('Joe Gibbs Racing',     8, 'Huntersville, NC', 1991, 'Joe Gibbs'),
('Team Penske',          8, 'Mooresville, NC',  1966, 'Roger Penske');

-- F1 2023 championship-team links
INSERT INTO championship_team (season_id, team_id) VALUES
(1,1),(1,2),(1,3),(1,4),(1,5),(1,6),(1,7),(1,8),(1,9),(1,10);

-- F1 Drivers
INSERT INTO driver (first_name, last_name, nationality_id, date_of_birth, driver_number, abbreviation) VALUES
('Max',       'Verstappen',  3, '1997-09-30', 1,  'VER'),
('Sergio',    'Perez',      11, '1990-01-26', 11, 'PER'),
('Lewis',     'Hamilton',    1, '1985-01-07', 44, 'HAM'),
('George',    'Russell',     1, '1998-02-15', 63, 'RUS'),
('Charles',   'Leclerc',     5, '1997-10-16', 16, 'LEC'),
('Carlos',    'Sainz',       4, '1994-09-01', 55, 'SAI'),
('Lando',     'Norris',      1, '1999-11-13', 4,  'NOR'),
('Oscar',     'Piastri',     9, '2001-04-06', 81, 'PIA'),
('Fernando',  'Alonso',      4, '1981-07-29', 14, 'ALO'),
('Lance',     'Stroll',     15, '1998-10-29', 18, 'STR'),
('Esteban',   'Ocon',        7, '1996-09-17', 31, 'OCO'),
('Pierre',    'Gasly',       7, '1996-02-07', 10, 'GAS'),
('Alexander', 'Albon',       1, '1996-03-23', 23, 'ALB'),
('Logan',     'Sargeant',    8, '2000-12-31', 2,  'SAR'),
('Yuki',      'Tsunoda',    12, '2000-05-11', 22, 'TSU'),
('Daniel',    'Ricciardo',   9, '1989-07-01', 3,  'RIC'),
('Valtteri',  'Bottas',     13, '1989-08-28', 77, 'BOT'),
('Zhou',      'Guanyu',     24, '1999-05-30', 24, 'ZHO'),
('Kevin',     'Magnussen',  23, '1992-10-05', 20, 'MAG'),
('Nico',      'Hulkenberg',  2, '1987-08-19', 27, 'HUL');

-- MotoGP Riders
INSERT INTO driver (first_name, last_name, nationality_id, date_of_birth, driver_number, abbreviation) VALUES
('Francesco', 'Bagnaia',    6, '1997-01-14', 1,  'BAG'),
('Jorge',     'Martin',     4, '1988-01-29', 89, 'MAR'),
('Marc',      'Marquez',    4, '1993-02-17', 93, 'MMQ'),
('Fabio',     'Quartararo', 7, '1999-04-20', 20, 'QUA');

-- NASCAR Drivers
INSERT INTO driver (first_name, last_name, nationality_id, date_of_birth, driver_number, abbreviation) VALUES
('Kyle',  'Larson',  8, '1992-07-31', 5,  'LAR'),
('Denny', 'Hamlin',  8, '1980-11-18', 11, 'DHA'),
('Ryan',  'Blaney',  8, '1993-12-31', 12, 'BLA');

-- F1 2023 team-driver links
INSERT INTO team_driver (team_id, driver_id, season_id) VALUES
(1,1,1),(1,2,1),(2,3,1),(2,4,1),(3,5,1),(3,6,1),
(4,7,1),(4,8,1),(5,9,1),(5,10,1);

-- Circuits
INSERT INTO circuit (circuit_name, country_id, city, track_length_km, circuit_type, capacity) VALUES
('Bahrain International Circuit',     16, 'Sakhir',       5.412, 'Permanent', 70000),
('Jeddah Corniche Circuit',           19, 'Jeddah',       6.174, 'Street',    27500),
('Albert Park Circuit',                9, 'Melbourne',    5.278, 'Street',    125000),
('Circuit de Monaco',                  5, 'Monte Carlo',  3.337, 'Street',    37000),
('Circuit de Barcelona-Catalunya',     4, 'Barcelona',    4.657, 'Permanent', 140000),
('Silverstone Circuit',                1, 'Silverstone',  5.891, 'Permanent', 150000),
('Monza Circuit',                      6, 'Monza',        5.793, 'Permanent', 113000),
('Suzuka International Racing Course',12, 'Suzuka',       5.807, 'Permanent', 155000),
('Yas Marina Circuit',                18, 'Abu Dhabi',    5.281, 'Permanent', 65000),
('Hungaroring',                       20, 'Budapest',     4.381, 'Permanent', 120000),
('Daytona International Speedway',     8, 'Daytona',      4.023, 'Oval',      168000),
('Autodromo del Mugello',              6, 'Mugello',      5.245, 'Permanent', 80000);

-- Races — F1 2023 (5 rounds)
INSERT INTO race (season_id, circuit_id, race_name, race_date, round_number, total_laps, distance_km, status) VALUES
(1,1,'Bahrain Grand Prix',       '2023-03-05',1,57,308.238,'Completed'),
(1,2,'Saudi Arabian Grand Prix', '2023-03-19',2,50,308.450,'Completed'),
(1,3,'Australian Grand Prix',    '2023-03-30',3,58,307.574,'Completed'),
(1,4,'Monaco Grand Prix',        '2023-05-28',6,78,260.286,'Completed'),
(1,5,'Spanish Grand Prix',       '2023-06-04',7,66,307.236,'Completed');

-- Race results — Bahrain GP 2023
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(1,1,1,  1,1,25,57,'Finished'),
(1,2,1,  2,2,18,57,'Finished'),
(1,3,2,  3,5,15,57,'Finished'),
(1,9,5,  4,6,12,57,'Finished'),
(1,5,3,  5,3,10,57,'Finished'),
(1,6,3,  6,4, 8,57,'Finished'),
(1,7,4,  7,8, 6,57,'Finished'),
(1,4,2,  8,9, 4,57,'Finished'),
(1,16,8, 9,18, 2,57,'Finished'),
(1,19,10,10,16,1,57,'Finished');

-- Race results — Saudi GP 2023
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(2,1,1,  1,1,26,50,'Finished'),
(2,2,1,  2,2,18,50,'Finished'),
(2,9,5,  3,4,15,50,'Finished'),
(2,5,3,  4,5,12,50,'Finished'),
(2,3,2,  5,3,10,50,'Finished'),
(2,7,4,  6,7, 8,50,'Finished'),
(2,6,3,  7,6, 6,50,'Finished'),
(2,4,2,  8,8, 4,50,'Finished'),
(2,10,5, 9,9, 2,50,'Finished'),
(2,11,6,10,10,1,50,'Finished');

-- Fastest laps
INSERT INTO fastest_lap (race_id, driver_id, team_id, lap_number, lap_time) VALUES
(1,1,1,44,'1:33.996'),
(2,1,1,32,'1:31.906');

-- Points systems
INSERT INTO points_system (championship_id, system_name, valid_from_year, bonus_points) VALUES
(1,'F1 2010+ Points System', 2010, 1),
(2,'MotoGP Points System',   2013, 0);

INSERT INTO points_system_detail (ps_id, finishing_pos, points_awarded) VALUES
(1,1,25),(1,2,18),(1,3,15),(1,4,12),(1,5,10),(1,6,8),(1,7,6),(1,8,4),(1,9,2),(1,10,1),
(2,1,25),(2,2,20),(2,3,16),(2,4,13),(2,5,11),(2,6,10),(2,7,9),(2,8,8),(2,9,7),(2,10,6);

-- Award types
INSERT INTO award_type (award_name, description, points_bonus) VALUES
('Driver of the Day', 'Fan-voted best driver performance', 0),
('Pole Position',     'Fastest qualifying lap',            0),
('Fastest Lap',       'Fastest lap during race (top 10)',  1),
('Hat-Trick',         'Pole, win, and fastest lap',        0);

-- Race awards — Bahrain 2023
INSERT INTO race_award (race_id, driver_id, award_type_id) VALUES
(1,1,1),(1,1,2),(1,1,3);

-- Qualifying sessions & results — Bahrain 2023
INSERT INTO qualifying_session (race_id, session_type, session_date, session_time) VALUES
(1,'Q1','2023-03-04','15:00:00'),
(1,'Q2','2023-03-04','15:18:00'),
(1,'Q3','2023-03-04','15:38:00');

INSERT INTO qualifying_result (qs_id, driver_id, team_id, lap_time, position) VALUES
(3,1,1,'1:29.708',1),(3,5,3,'1:29.985',2),
(3,6,3,'1:30.154',3),(3,3,2,'1:30.259',4),(3,2,1,'1:30.265',5);

-- Weather
INSERT INTO weather (race_id, session_type, temperature_c, track_temp_c, humidity_pct, wind_speed_kmh, condition_type) VALUES
(1,'Race',28.0,35.5,47,12.5,'Sunny'),
(2,'Race',26.5,38.0,52,15.0,'Sunny');

-- Tire compounds
INSERT INTO tire_compound (championship_id, compound_name, compound_color, is_dry) VALUES
(1,'Soft','Red',1),(1,'Medium','Yellow',1),(1,'Hard','White',1),
(1,'Intermediate','Green',0),(1,'Wet','Blue',0),
(2,'Soft','Red',1),(2,'Medium','Yellow',1),(2,'Hard','White',1);

-- Tire strategy — Bahrain 2023
INSERT INTO tire_strategy (race_id, driver_id, compound_id, stint_number, start_lap, end_lap, laps_on_tire) VALUES
(1,1,1,1,1,27,27),(1,1,2,2,28,57,30),
(1,2,1,1,1,24,24),(1,2,2,2,25,57,33),
(1,3,1,1,1,20,20),(1,3,2,2,21,42,22),(1,3,3,3,43,57,15);

-- Pit stops — Bahrain 2023
INSERT INTO pit_stop (race_id, driver_id, stop_number, lap_number, pit_duration) VALUES
(1,1,1,27,'0:02.500'),(1,2,1,24,'0:02.800'),
(1,3,1,20,'0:03.100'),(1,3,2,42,'0:02.900');

-- Penalties
INSERT INTO penalty (race_id, driver_id, penalty_type, time_penalty_s, reason, lap_issued) VALUES
(2,3,'Time Penalty',5,'Unsafe release from pit lane',22),
(1,19,'Drive-Through',NULL,'Exceeding track limits 3+ times',45);

-- Lap times — Bahrain 2023 sample
INSERT INTO lap_time (race_id, driver_id, lap_number, lap_time, position) VALUES
(1,1,1,'1:37.529',1),(1,1,2,'1:34.789',1),(1,1,3,'1:34.123',1),(1,1,44,'1:33.996',1),
(1,2,1,'1:38.012',2),(1,2,2,'1:35.100',2);

-- Engine suppliers
INSERT INTO engine_supplier (supplier_name, country_id, founded_year) VALUES
('Mercedes-AMG HPP',   2, 1994),
('Ferrari Power Unit', 6, 1947),
('Honda Racing',      12, 1964),
('Renault E-Tech',     7, 1977),
('Ford Performance',   8, 2023);

-- Vehicle specs — F1 2023
INSERT INTO vehicle_spec (team_id, season_id, supplier_id, chassis_name, engine_name, power_unit_type, weight_kg) VALUES
(1,1,3,'RB19',   'Honda RA621H', 'Hybrid V6',798),
(2,1,1,'W14',    'Mercedes M14','Hybrid V6',798),
(3,1,2,'SF-23',  'Ferrari 066', 'Hybrid V6',798);

-- Sponsors
INSERT INTO sponsor (sponsor_name, industry, country_id, website) VALUES
('Oracle',    'Technology', 8, 'https://oracle.com'),
('Petronas',  'Energy',    21, 'https://petronas.com'),
('Shell',     'Energy',     1, 'https://shell.com'),
('Santander', 'Finance',    4, 'https://santander.com'),
('Heineken',  'Beverage',   3, 'https://heineken.com'),
('AWS',       'Technology', 8, 'https://aws.amazon.com');

INSERT INTO team_sponsor (team_id, sponsor_id, season_id, sponsorship_tier, contract_value) VALUES
(1,1,1,'Title',85000000),(2,2,1,'Title',70000000),
(3,3,1,'Title',45000000),(3,4,1,'Major',20000000),(4,6,1,'Major',15000000);

-- Staff
INSERT INTO staff_role (role_name, role_category) VALUES
('Team Principal','Management'),('Technical Director','Technical'),
('Race Engineer','Technical'),('Chief Strategist','Technical'),
('Head Mechanic','Operations');

INSERT INTO staff (first_name, last_name, nationality_id, role_id) VALUES
('Christian','Horner', 1,1),('Adrian','Newey',    1,2),
('Toto',     'Wolff',  14,1),('James', 'Vowles',   1,4);

INSERT INTO team_staff (team_id, staff_id, season_id) VALUES
(1,1,1),(1,2,1),(2,3,1),(2,4,1);

-- User roles & system user
INSERT INTO user_role (role_name, can_insert, can_update, can_delete) VALUES
('Admin',  1,1,1),('Analyst',1,1,0),('Viewer',0,0,0);

-- ============================================================
-- COMPLEX QUERIES (commented — run individually as needed)
-- ============================================================

-- Q1: Running cumulative points per driver (Window function: SUM OVER)
-- SELECT driver_id, driver_name, round_number,
--        SUM(points_earned) OVER (PARTITION BY driver_id ORDER BY round_number
--                                  ROWS UNBOUNDED PRECEDING) AS cumulative_points
-- FROM (
--     SELECT rr.driver_id, CONCAT(d.first_name,' ',d.last_name) AS driver_name,
--            r.round_number, rr.points_earned
--     FROM race_result rr
--     JOIN race r   ON rr.race_id = r.race_id
--     JOIN driver d ON rr.driver_id = d.driver_id
--     WHERE r.season_id = 1
-- ) pts
-- ORDER BY round_number, cumulative_points DESC;

-- Q2: Position change per round (Window function: LAG)
-- SELECT driver_id, after_round, position, total_points,
--        LAG(position) OVER (PARTITION BY driver_id ORDER BY after_round) AS prev_position,
--        position - LAG(position) OVER (PARTITION BY driver_id ORDER BY after_round) AS pos_change
-- FROM driver_standing WHERE season_id = 1
-- ORDER BY after_round, position;

-- Q3: Championship rankings using DENSE_RANK
-- SELECT DENSE_RANK() OVER (PARTITION BY ds.season_id ORDER BY ds.total_points DESC) AS champ_rank,
--        CONCAT(d.first_name,' ',d.last_name) AS driver, t.team_name, ds.total_points
-- FROM driver_standing ds
-- JOIN driver d ON ds.driver_id = d.driver_id
-- LEFT JOIN team t ON ds.team_id = t.team_id
-- WHERE ds.season_id = 1
--   AND ds.after_round = (SELECT MAX(after_round) FROM driver_standing WHERE season_id = 1);

-- Q4: Teammate head-to-head (self join)
-- SELECT CONCAT(d1.first_name,' ',d1.last_name) AS driver1,
--        CONCAT(d2.first_name,' ',d2.last_name) AS driver2,
--        t.team_name,
--        COUNT(CASE WHEN rr1.finishing_position < rr2.finishing_position THEN 1 END) AS d1_ahead,
--        COUNT(CASE WHEN rr2.finishing_position < rr1.finishing_position THEN 1 END) AS d2_ahead
-- FROM team_driver td1
-- JOIN team_driver td2 ON td1.team_id=td2.team_id AND td1.season_id=td2.season_id AND td1.driver_id < td2.driver_id
-- JOIN driver d1 ON td1.driver_id=d1.driver_id
-- JOIN driver d2 ON td2.driver_id=d2.driver_id
-- JOIN team t ON td1.team_id=t.team_id
-- JOIN race_result rr1 ON rr1.driver_id=td1.driver_id
-- JOIN race_result rr2 ON rr2.driver_id=td2.driver_id AND rr1.race_id=rr2.race_id
-- WHERE td1.season_id=1
-- GROUP BY d1.driver_id, d2.driver_id, t.team_name;

-- Q5: Pit stop impact on finishing position
-- SELECT ps.stop_count, ROUND(AVG(rr.finishing_position),2) AS avg_finish, COUNT(*) AS sample_size
-- FROM (SELECT race_id, driver_id, MAX(stop_number) AS stop_count FROM pit_stop GROUP BY race_id, driver_id) ps
-- JOIN race_result rr ON rr.race_id=ps.race_id AND rr.driver_id=ps.driver_id
-- GROUP BY ps.stop_count HAVING COUNT(*) >= 1 ORDER BY ps.stop_count;

-- Q6: Call the avg points function
-- SELECT fn_driver_avg_points(1, 1) AS verstappen_avg_pts;

-- Q7: Call the circuit lap record function
-- SELECT fn_circuit_best_lap(1) AS bahrain_best_lap;

-- ============================================================
-- VERIFICATION
-- ============================================================
SELECT
    (SELECT COUNT(*) FROM information_schema.tables
     WHERE table_schema='motorsport' AND table_type='BASE TABLE') AS total_tables,
    (SELECT COUNT(*) FROM driver)      AS total_drivers,
    (SELECT COUNT(*) FROM race_result) AS total_results,
    (SELECT COUNT(*) FROM audit_log)   AS audit_entries;

-- ============================================================
-- EXTENDED DATA — MotoGP & NASCAR 2023
-- ============================================================

-- ── New countries ─────────────────────────────────────────────
INSERT IGNORE INTO country (country_name, country_code) VALUES
('Portugal',     'PRT'),
('South Africa', 'ZAF'),
('Thailand',     'THA');

-- ── MotoGP additional teams ───────────────────────────────────
INSERT INTO team (team_name, country_id, base_location, founded_year, principal) VALUES
('Prima Pramac Ducati',  6, 'Gatteo, Italy',        2002, 'Paolo Campinoti'),
('Mooney VR46 Racing',   6, 'Tavullia, Italy',       2021, 'Valentino Rossi'),
('Red Bull KTM Factory', 14,'Mattighofen, Austria',  2017, 'Pit Beirer'),
('Gresini Racing',       6, 'Faenza, Italy',         2021, 'Nadia Padovani');

-- ── NASCAR additional teams ───────────────────────────────────
INSERT INTO team (team_name, country_id, base_location, founded_year, principal) VALUES
('Spire Motorsports',        8, 'Mooresville, NC', 2018, 'Jeff Dickerson'),
('Richard Childress Racing', 8, 'Welcome, NC',     1969, 'Richard Childress'),
('Trackhouse Racing',        8, 'Concord, NC',     2021, 'Justin Marks'),
('Kaulig Racing',            8, 'Concord, NC',     2016, 'Matt Kaulig');

-- ── Championship-team links ───────────────────────────────────
-- MotoGP 2023 (season_id = 3)
INSERT IGNORE INTO championship_team (season_id, team_id)
SELECT 3, team_id FROM team WHERE team_name IN (
    'Repsol Honda', 'Monster Yamaha', 'Ducati Lenovo', 'Aprilia Racing',
    'Prima Pramac Ducati', 'Mooney VR46 Racing', 'Red Bull KTM Factory', 'Gresini Racing'
);

-- NASCAR 2023 (season_id = 4)
INSERT IGNORE INTO championship_team (season_id, team_id)
SELECT 4, team_id FROM team WHERE team_name IN (
    'Hendrick Motorsports', 'Joe Gibbs Racing', 'Team Penske',
    'Spire Motorsports', 'Richard Childress Racing', 'Trackhouse Racing', 'Kaulig Racing'
);

-- ── MotoGP additional drivers ─────────────────────────────────
INSERT INTO driver (first_name, last_name, nationality_id, date_of_birth, driver_number, abbreviation) VALUES
('Marco',       'Bezzecchi',  6,  '1998-11-12', 72, 'BEZ'),
('Brad',        'Binder',    (SELECT country_id FROM country WHERE country_code='ZAF'), '1995-08-27', 33, 'BIN'),
('Johann',      'Zarco',      7,  '1990-07-16',  5, 'ZAR'),
('Jack',        'Miller',     9,  '1995-01-18', 43, 'MIL'),
('Aleix',       'Espargaro',  4,  '1989-07-30', 41, 'AES'),
('Luca',        'Marini',     6,  '1997-08-10', 10, 'LMA'),
('Alex',        'Rins',       4,  '1995-09-08', 42, 'RIN'),
('Enea',        'Bastianini', 6,  '1997-12-30', 23, 'BAS');

-- ── NASCAR additional drivers ─────────────────────────────────
INSERT INTO driver (first_name, last_name, nationality_id, date_of_birth, driver_number, abbreviation) VALUES
('William',     'Byron',        8, '1997-11-29', 24, 'BYR'),
('Martin',      'Truex Jr',     8, '1980-06-29', 19, 'TRX'),
('Chase',       'Elliott',      8, '1995-11-28',  9, 'ELL'),
('Christopher', 'Bell',         8, '1994-12-20', 20, 'BEL'),
('Ricky',       'Stenhouse Jr', 8, '1987-10-02', 47, 'STE'),
('Kyle',        'Busch',        8, '1985-05-02',  8, 'KBU'),
('Ross',        'Chastain',     8, '1992-12-04',  1, 'CHA'),
('Joey',        'Logano',       8, '1990-05-24', 22, 'LOG');

-- ── team_driver links — MotoGP 2023 (season_id=3) ────────────
SET @ducati   = (SELECT team_id FROM team WHERE team_name='Ducati Lenovo');
SET @pramac   = (SELECT team_id FROM team WHERE team_name='Prima Pramac Ducati');
SET @vr46     = (SELECT team_id FROM team WHERE team_name='Mooney VR46 Racing');
SET @ktm      = (SELECT team_id FROM team WHERE team_name='Red Bull KTM Factory');
SET @aprilia  = (SELECT team_id FROM team WHERE team_name='Aprilia Racing');
SET @yamaha   = (SELECT team_id FROM team WHERE team_name='Monster Yamaha');
SET @honda    = (SELECT team_id FROM team WHERE team_name='Repsol Honda');
SET @gresini  = (SELECT team_id FROM team WHERE team_name='Gresini Racing');

SET @bagnaia  = (SELECT driver_id FROM driver WHERE last_name='Bagnaia');
SET @martin   = (SELECT driver_id FROM driver WHERE first_name='Jorge' AND last_name='Martin');
SET @marquez  = (SELECT driver_id FROM driver WHERE last_name='Marquez' AND first_name='Marc');
SET @quart    = (SELECT driver_id FROM driver WHERE last_name='Quartararo');
SET @bezz     = (SELECT driver_id FROM driver WHERE last_name='Bezzecchi');
SET @binder   = (SELECT driver_id FROM driver WHERE last_name='Binder');
SET @zarco    = (SELECT driver_id FROM driver WHERE last_name='Zarco');
SET @miller   = (SELECT driver_id FROM driver WHERE last_name='Miller');
SET @aleix    = (SELECT driver_id FROM driver WHERE last_name='Espargaro');
SET @marini   = (SELECT driver_id FROM driver WHERE last_name='Marini' AND first_name='Luca');
SET @rins     = (SELECT driver_id FROM driver WHERE last_name='Rins');
SET @basti    = (SELECT driver_id FROM driver WHERE last_name='Bastianini');

INSERT IGNORE INTO team_driver (team_id, driver_id, season_id, role) VALUES
(@ducati, @bagnaia, 3, 'Race Rider'), (@ducati, @basti,  3, 'Race Rider'),
(@pramac, @martin,  3, 'Race Rider'), (@pramac, @zarco,  3, 'Race Rider'),
(@vr46,   @bezz,    3, 'Race Rider'), (@vr46,   @marini, 3, 'Race Rider'),
(@ktm,    @binder,  3, 'Race Rider'), (@ktm,    @miller, 3, 'Race Rider'),
(@aprilia,@aleix,   3, 'Race Rider'), (@aprilia,@rins,   3, 'Race Rider'),
(@yamaha, @quart,   3, 'Race Rider'),
(@honda,  @marquez, 3, 'Race Rider');

-- ── team_driver links — NASCAR 2023 (season_id=4) ─────────────
SET @hend   = (SELECT team_id FROM team WHERE team_name='Hendrick Motorsports');
SET @jgr    = (SELECT team_id FROM team WHERE team_name='Joe Gibbs Racing');
SET @penske = (SELECT team_id FROM team WHERE team_name='Team Penske');
SET @spire  = (SELECT team_id FROM team WHERE team_name='Spire Motorsports');
SET @rcr    = (SELECT team_id FROM team WHERE team_name='Richard Childress Racing');
SET @track  = (SELECT team_id FROM team WHERE team_name='Trackhouse Racing');

SET @larson  = (SELECT driver_id FROM driver WHERE last_name='Larson');
SET @hamlin  = (SELECT driver_id FROM driver WHERE last_name='Hamlin');
SET @blaney  = (SELECT driver_id FROM driver WHERE last_name='Blaney');
SET @byron   = (SELECT driver_id FROM driver WHERE last_name='Byron');
SET @truex   = (SELECT driver_id FROM driver WHERE last_name='Truex Jr');
SET @elliott = (SELECT driver_id FROM driver WHERE last_name='Elliott');
SET @bell    = (SELECT driver_id FROM driver WHERE last_name='Bell');
SET @stenhse = (SELECT driver_id FROM driver WHERE last_name='Stenhouse Jr');
SET @kbusch  = (SELECT driver_id FROM driver WHERE last_name='Busch' AND first_name='Kyle');
SET @chast   = (SELECT driver_id FROM driver WHERE last_name='Chastain');
SET @logano  = (SELECT driver_id FROM driver WHERE last_name='Logano');

INSERT IGNORE INTO team_driver (team_id, driver_id, season_id, role) VALUES
(@hend,   @larson,  4, 'Race Driver'), (@hend,   @byron,   4, 'Race Driver'),
(@hend,   @elliott, 4, 'Race Driver'),
(@jgr,    @hamlin,  4, 'Race Driver'), (@jgr,    @truex,   4, 'Race Driver'),
(@jgr,    @bell,    4, 'Race Driver'),
(@penske, @blaney,  4, 'Race Driver'), (@penske, @logano,  4, 'Race Driver'),
(@spire,  @stenhse, 4, 'Race Driver'),
(@rcr,    @kbusch,  4, 'Race Driver'),
(@track,  @chast,   4, 'Race Driver');

-- ── MotoGP circuits ───────────────────────────────────────────
INSERT INTO circuit (circuit_name, country_id, city, track_length_km, circuit_type, capacity) VALUES
('Algarve International Circuit',  (SELECT country_id FROM country WHERE country_code='PRT'), 'Portimao',    4.592, 'Permanent', 69000),
('Angel Nieto Circuit',            4,  'Jerez de la Frontera', 4.423, 'Permanent', 65000),
('Le Mans Circuit',                7,  'Le Mans',              4.185, 'Permanent', 100000),
('TT Circuit Assen',               3,  'Assen',                4.542, 'Permanent', 105000),
('Red Bull Ring',                  14, 'Spielberg',            4.318, 'Permanent', 72000);

-- ── NASCAR circuits ───────────────────────────────────────────
INSERT INTO circuit (circuit_name, country_id, city, track_length_km, circuit_type, capacity) VALUES
('Atlanta Motor Speedway',         8, 'Hampton',     2.736, 'Oval', 75000),
('Las Vegas Motor Speedway',       8, 'Las Vegas',   2.414, 'Oval', 80000),
('Charlotte Motor Speedway',       8, 'Concord',     2.428, 'Oval', 90000),
('Talladega Superspeedway',        8, 'Talladega',   4.281, 'Oval', 143000),
('Phoenix Raceway',                8, 'Avondale',    1.609, 'Oval', 51000);

-- ── MotoGP 2023 Races ─────────────────────────────────────────
SET @portimao = (SELECT circuit_id FROM circuit WHERE circuit_name='Algarve International Circuit');
SET @jerez    = (SELECT circuit_id FROM circuit WHERE circuit_name='Angel Nieto Circuit');
SET @cota     = (SELECT circuit_id FROM circuit WHERE circuit_name='Circuit of the Americas');
SET @lemans   = (SELECT circuit_id FROM circuit WHERE circuit_name='Le Mans Circuit');
SET @mugello  = (SELECT circuit_id FROM circuit WHERE circuit_name='Autodromo del Mugello');
SET @assen    = (SELECT circuit_id FROM circuit WHERE circuit_name='TT Circuit Assen');
SET @redbull  = (SELECT circuit_id FROM circuit WHERE circuit_name='Red Bull Ring');
SET @motogp23 = 3; -- season_id for MotoGP 2023

-- Handle COTA being null (if not in DB from before)
INSERT IGNORE INTO circuit (circuit_name, country_id, city, track_length_km, circuit_type, capacity)
VALUES ('Circuit of the Americas', 8, 'Austin', 5.513, 'Permanent', 120000);
SET @cota = (SELECT circuit_id FROM circuit WHERE circuit_name='Circuit of the Americas');

INSERT INTO race (season_id, circuit_id, race_name, race_date, round_number, total_laps, distance_km, status) VALUES
(@motogp23, @portimao, 'Portuguese Grand Prix',  '2023-03-26', 1,  25, 114.800, 'Completed'),
(@motogp23, @jerez,    'Spanish Grand Prix',     '2023-04-30', 4,  25, 110.575, 'Completed'),
(@motogp23, @lemans,   'French Grand Prix',      '2023-05-14', 5,  27, 113.000, 'Completed'),
(@motogp23, @mugello,  'Italian Grand Prix',     '2023-06-11', 6,  23, 120.635, 'Completed'),
(@motogp23, @assen,    'Dutch TT',               '2023-06-25', 7,  26, 118.092, 'Completed'),
(@motogp23, @redbull,  'Austrian Grand Prix',    '2023-08-20', 11, 28, 120.904, 'Completed');

-- ── MotoGP race results ───────────────────────────────────────
-- Race IDs: existing races are 1-10 (5 F1 + we added 2 Saudi results)
-- Let's get the actual race_ids for our new MotoGP races
SET @por_r = (SELECT race_id FROM race WHERE race_name='Portuguese Grand Prix' AND season_id=3);
SET @esp_r = (SELECT race_id FROM race WHERE race_name='Spanish Grand Prix' AND season_id=3);
SET @fra_r = (SELECT race_id FROM race WHERE race_name='French Grand Prix' AND season_id=3);
SET @ita_r = (SELECT race_id FROM race WHERE race_name='Italian Grand Prix' AND season_id=3);
SET @ned_r = (SELECT race_id FROM race WHERE race_name='Dutch TT' AND season_id=3);
SET @aut_r = (SELECT race_id FROM race WHERE race_name='Austrian Grand Prix' AND season_id=3);

-- Portuguese GP results
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@por_r, @bagnaia, @ducati, 1, 1, 25, 25, 'Finished'),
(@por_r, @bezz,    @vr46,   2, 3, 20, 25, 'Finished'),
(@por_r, @binder,  @ktm,    3, 4, 16, 25, 'Finished'),
(@por_r, @martin,  @pramac, 4, 2, 13, 25, 'Finished'),
(@por_r, @zarco,   @pramac, 5, 7, 11, 25, 'Finished'),
(@por_r, @aleix,   @aprilia,6, 5, 10, 25, 'Finished'),
(@por_r, @marini,  @vr46,   7, 8,  9, 25, 'Finished'),
(@por_r, @quart,   @yamaha, 8,11,  8, 25, 'Finished'),
(@por_r, @marquez, @honda,  9, 6,  7, 25, 'Finished'),
(@por_r, @miller,  @ktm,   10, 9,  6, 25, 'Finished');

-- Spanish GP results
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@esp_r, @bagnaia, @ducati,  1, 1, 25, 25, 'Finished'),
(@esp_r, @martin,  @pramac,  2, 2, 20, 25, 'Finished'),
(@esp_r, @binder,  @ktm,     3, 5, 16, 25, 'Finished'),
(@esp_r, @bezz,    @vr46,    4, 3, 13, 25, 'Finished'),
(@esp_r, @aleix,   @aprilia, 5, 4, 11, 25, 'Finished'),
(@esp_r, @zarco,   @pramac,  6, 8, 10, 25, 'Finished'),
(@esp_r, @marini,  @vr46,    7, 9,  9, 25, 'Finished'),
(@esp_r, @quart,   @yamaha,  8,10,  8, 25, 'Finished'),
(@esp_r, @basti,   @ducati,  9, 6,  7, 25, 'Finished'),
(@esp_r, @miller,  @ktm,    10, 7,  6, 25, 'Finished');

-- French GP results
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@fra_r, @martin,  @pramac,  1, 2, 25, 27, 'Finished'),
(@fra_r, @bagnaia, @ducati,  2, 1, 20, 27, 'Finished'),
(@fra_r, @zarco,   @pramac,  3, 4, 16, 27, 'Finished'),
(@fra_r, @bezz,    @vr46,    4, 3, 13, 27, 'Finished'),
(@fra_r, @aleix,   @aprilia, 5, 5, 11, 27, 'Finished'),
(@fra_r, @binder,  @ktm,     6, 7, 10, 27, 'Finished'),
(@fra_r, @miller,  @ktm,     7, 9,  9, 27, 'Finished'),
(@fra_r, @quart,   @yamaha,  8, 8,  8, 27, 'Finished'),
(@fra_r, @marini,  @vr46,    9, 6,  7, 27, 'Finished'),
(@fra_r, @marquez, @honda,  10,10,  6, 27, 'Finished');

-- Italian GP results
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@ita_r, @bagnaia, @ducati,  1, 1, 25, 23, 'Finished'),
(@ita_r, @martin,  @pramac,  2, 3, 20, 23, 'Finished'),
(@ita_r, @aleix,   @aprilia, 3, 2, 16, 23, 'Finished'),
(@ita_r, @bezz,    @vr46,    4, 4, 13, 23, 'Finished'),
(@ita_r, @zarco,   @pramac,  5, 6, 11, 23, 'Finished'),
(@ita_r, @binder,  @ktm,     6, 7, 10, 23, 'Finished'),
(@ita_r, @basti,   @ducati,  7, 5,  9, 23, 'Finished'),
(@ita_r, @marini,  @vr46,    8, 9,  8, 23, 'Finished'),
(@ita_r, @miller,  @ktm,     9, 8,  7, 23, 'Finished'),
(@ita_r, @quart,   @yamaha, 10,11,  6, 23, 'Finished');

-- Dutch TT results
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@ned_r, @bezz,    @vr46,    1, 2, 25, 26, 'Finished'),
(@ned_r, @bagnaia, @ducati,  2, 1, 20, 26, 'Finished'),
(@ned_r, @martin,  @pramac,  3, 4, 16, 26, 'Finished'),
(@ned_r, @aleix,   @aprilia, 4, 3, 13, 26, 'Finished'),
(@ned_r, @zarco,   @pramac,  5, 5, 11, 26, 'Finished'),
(@ned_r, @binder,  @ktm,     6, 6, 10, 26, 'Finished'),
(@ned_r, @marini,  @vr46,    7, 8,  9, 26, 'Finished'),
(@ned_r, @basti,   @ducati,  8, 7,  8, 26, 'Finished'),
(@ned_r, @quart,   @yamaha,  9,10,  7, 26, 'Finished'),
(@ned_r, @miller,  @ktm,    10, 9,  6, 26, 'Finished');

-- Austrian GP results
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@aut_r, @bagnaia, @ducati,  1, 1, 25, 28, 'Finished'),
(@aut_r, @bezz,    @vr46,    2, 3, 20, 28, 'Finished'),
(@aut_r, @binder,  @ktm,     3, 2, 16, 28, 'Finished'),
(@aut_r, @martin,  @pramac,  4, 5, 13, 28, 'Finished'),
(@aut_r, @miller,  @ktm,     5, 4, 11, 28, 'Finished'),
(@aut_r, @zarco,   @pramac,  6, 7, 10, 28, 'Finished'),
(@aut_r, @aleix,   @aprilia, 7, 6,  9, 28, 'Finished'),
(@aut_r, @basti,   @ducati,  8, 8,  8, 28, 'Finished'),
(@aut_r, @marini,  @vr46,    9, 9,  7, 28, 'Finished'),
(@aut_r, @quart,   @yamaha, 10,10,  6, 28, 'Finished');

-- MotoGP fastest laps
INSERT IGNORE INTO fastest_lap (race_id, driver_id, team_id, lap_number, lap_time) VALUES
(@por_r, @bagnaia, @ducati, 22, '1:40.522'),
(@esp_r, @bagnaia, @ducati, 20, '1:37.951'),
(@fra_r, @martin,  @pramac, 25, '1:32.126'),
(@ita_r, @bagnaia, @ducati, 18, '1:46.392'),
(@ned_r, @bezz,    @vr46,   22, '1:33.618'),
(@aut_r, @binder,  @ktm,    24, '1:30.421');

-- ── NASCAR 2023 Races ─────────────────────────────────────────
SET @daytona  = (SELECT circuit_id FROM circuit WHERE circuit_name='Daytona International Speedway');
SET @atlanta  = (SELECT circuit_id FROM circuit WHERE circuit_name='Atlanta Motor Speedway');
SET @lasvegas = (SELECT circuit_id FROM circuit WHERE circuit_name='Las Vegas Motor Speedway');
SET @char1    = (SELECT circuit_id FROM circuit WHERE circuit_name='Charlotte Motor Speedway');
SET @phx      = (SELECT circuit_id FROM circuit WHERE circuit_name='Phoenix Raceway');
SET @tala     = (SELECT circuit_id FROM circuit WHERE circuit_name='Talladega Superspeedway');
SET @nascar23 = 4; -- season_id for NASCAR 2023

INSERT INTO race (season_id, circuit_id, race_name, race_date, round_number, total_laps, distance_km, status) VALUES
(@nascar23, @daytona,  'Daytona 500',              '2023-02-19',  1, 200, 804.672, 'Completed'),
(@nascar23, @atlanta,  'Ambetter Health 400',       '2023-02-26',  2, 260, 712.378, 'Completed'),
(@nascar23, @lasvegas, 'Pennzoil 400',              '2023-03-05',  3, 267, 644.796, 'Completed'),
(@nascar23, @char1,    'Coca-Cola 600',             '2023-05-28', 13, 400, 971.072, 'Completed'),
(@nascar23, @tala,     'GEICO 500',                 '2023-04-23',  9, 188, 805.178, 'Completed'),
(@nascar23, @phx,      'Championship Race Phoenix', '2023-11-05', 36, 312, 502.085, 'Completed');

-- ── NASCAR race results ───────────────────────────────────────
SET @day_r  = (SELECT race_id FROM race WHERE race_name='Daytona 500' AND season_id=4);
SET @atl_r  = (SELECT race_id FROM race WHERE race_name='Ambetter Health 400' AND season_id=4);
SET @lv_r   = (SELECT race_id FROM race WHERE race_name='Pennzoil 400' AND season_id=4);
SET @clt_r  = (SELECT race_id FROM race WHERE race_name='Coca-Cola 600' AND season_id=4);
SET @tal_r  = (SELECT race_id FROM race WHERE race_name='GEICO 500' AND season_id=4);
SET @phx_r  = (SELECT race_id FROM race WHERE race_name='Championship Race Phoenix' AND season_id=4);

-- NASCAR points: 40,35,34,33,32,31,30,29,28,27 for top 10

-- Daytona 500 — Winner: Ricky Stenhouse Jr
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@day_r, @stenhse, @spire,  1,  5, 40, 200, 'Finished'),
(@day_r, @logano,  @penske, 2,  8, 35, 200, 'Finished'),
(@day_r, @larson,  @hend,   3,  1, 34, 200, 'Finished'),
(@day_r, @byron,   @hend,   4,  4, 33, 200, 'Finished'),
(@day_r, @chast,   @track,  5,  3, 32, 200, 'Finished'),
(@day_r, @hamlin,  @jgr,    6, 10, 31, 200, 'Finished'),
(@day_r, @blaney,  @penske, 7,  2, 30, 200, 'Finished'),
(@day_r, @bell,    @jgr,    8,  7, 29, 200, 'Finished'),
(@day_r, @truex,   @jgr,    9, 11, 28, 200, 'Finished'),
(@day_r, @elliott, @hend,  10,  6, 27, 200, 'Finished');

-- Atlanta 400 — Winner: William Byron
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@atl_r, @byron,   @hend,   1,  3, 40, 260, 'Finished'),
(@atl_r, @blaney,  @penske, 2,  1, 35, 260, 'Finished'),
(@atl_r, @larson,  @hend,   3,  2, 34, 260, 'Finished'),
(@atl_r, @chast,   @track,  4,  6, 33, 260, 'Finished'),
(@atl_r, @hamlin,  @jgr,    5,  4, 32, 260, 'Finished'),
(@atl_r, @logano,  @penske, 6,  5, 31, 260, 'Finished'),
(@atl_r, @bell,    @jgr,    7,  9, 30, 260, 'Finished'),
(@atl_r, @truex,   @jgr,    8,  7, 29, 260, 'Finished'),
(@atl_r, @kbusch,  @rcr,    9,  8, 28, 260, 'Finished'),
(@atl_r, @stenhse, @spire, 10, 12, 27, 260, 'Finished');

-- Las Vegas 400 — Winner: Kyle Larson
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@lv_r, @larson,  @hend,   1,  1, 40, 267, 'Finished'),
(@lv_r, @blaney,  @penske, 2,  2, 35, 267, 'Finished'),
(@lv_r, @hamlin,  @jgr,    3,  5, 34, 267, 'Finished'),
(@lv_r, @bell,    @jgr,    4,  3, 33, 267, 'Finished'),
(@lv_r, @truex,   @jgr,    5,  4, 32, 267, 'Finished'),
(@lv_r, @byron,   @hend,   6,  6, 31, 267, 'Finished'),
(@lv_r, @elliott, @hend,   7,  8, 30, 267, 'Finished'),
(@lv_r, @logano,  @penske, 8,  7, 29, 267, 'Finished'),
(@lv_r, @kbusch,  @rcr,    9,  9, 28, 267, 'Finished'),
(@lv_r, @chast,   @track, 10, 10, 27, 267, 'Finished');

-- Coca-Cola 600 — Winner: Ryan Blaney
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@clt_r, @blaney,  @penske, 1,  2, 40, 400, 'Finished'),
(@clt_r, @larson,  @hend,   2,  1, 35, 400, 'Finished'),
(@clt_r, @hamlin,  @jgr,    3,  4, 34, 400, 'Finished'),
(@clt_r, @truex,   @jgr,    4,  3, 33, 400, 'Finished'),
(@clt_r, @byron,   @hend,   5,  5, 32, 400, 'Finished'),
(@clt_r, @bell,    @jgr,    6,  6, 31, 400, 'Finished'),
(@clt_r, @chast,   @track,  7,  8, 30, 400, 'Finished'),
(@clt_r, @logano,  @penske, 8,  7, 29, 400, 'Finished'),
(@clt_r, @kbusch,  @rcr,    9,  9, 28, 400, 'Finished'),
(@clt_r, @stenhse, @spire, 10, 11, 27, 400, 'Finished');

-- Talladega — Winner: Ross Chastain
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@tal_r, @chast,   @track,  1,  4, 40, 188, 'Finished'),
(@tal_r, @stenhse, @spire,  2,  7, 35, 188, 'Finished'),
(@tal_r, @logano,  @penske, 3,  2, 34, 188, 'Finished'),
(@tal_r, @blaney,  @penske, 4,  1, 33, 188, 'Finished'),
(@tal_r, @larson,  @hend,   5,  3, 32, 188, 'Finished'),
(@tal_r, @hamlin,  @jgr,    6,  5, 31, 188, 'Finished'),
(@tal_r, @bell,    @jgr,    7,  8, 30, 188, 'Finished'),
(@tal_r, @truex,   @jgr,    8,  6, 29, 188, 'Finished'),
(@tal_r, @kbusch,  @rcr,    9, 10, 28, 188, 'Finished'),
(@tal_r, @byron,   @hend,  10,  9, 27, 188, 'Finished');

-- Phoenix Championship — Winner: Ryan Blaney (Champion)
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, laps_completed, status) VALUES
(@phx_r, @blaney,  @penske, 1,  3, 40, 312, 'Finished'),
(@phx_r, @larson,  @hend,   2,  1, 35, 312, 'Finished'),
(@phx_r, @hamlin,  @jgr,    3,  2, 34, 312, 'Finished'),
(@phx_r, @bell,    @jgr,    4,  5, 33, 312, 'Finished'),
(@phx_r, @truex,   @jgr,    5,  4, 32, 312, 'Finished'),
(@phx_r, @byron,   @hend,   6,  6, 31, 312, 'Finished'),
(@phx_r, @chast,   @track,  7,  7, 30, 312, 'Finished'),
(@phx_r, @logano,  @penske, 8,  8, 29, 312, 'Finished'),
(@phx_r, @kbusch,  @rcr,    9,  9, 28, 312, 'Finished'),
(@phx_r, @stenhse, @spire, 10, 11, 27, 312, 'Finished');

-- NASCAR fastest laps
INSERT IGNORE INTO fastest_lap (race_id, driver_id, team_id, lap_number, lap_time) VALUES
(@day_r, @larson,  @hend,   180, '0:45.123'),
(@atl_r, @blaney,  @penske, 245, '0:27.891'),
(@lv_r,  @larson,  @hend,   252, '0:28.334'),
(@clt_r, @blaney,  @penske, 380, '0:29.447'),
(@tal_r, @chast,   @track,  170, '0:43.782'),
(@phx_r, @blaney,  @penske, 298, '0:23.156');

-- ── Trigger stored procedure calls to auto-populate standings ──
CALL sp_assign_final_rankings(3); -- MotoGP 2023
CALL sp_assign_final_rankings(4); -- NASCAR 2023

-- ── Verification ──────────────────────────────────────────────
SELECT
  (SELECT COUNT(*) FROM race WHERE season_id=3)          AS motogp_races,
  (SELECT COUNT(*) FROM race_result rr JOIN race r ON rr.race_id=r.race_id WHERE r.season_id=3) AS motogp_results,
  (SELECT COUNT(*) FROM race WHERE season_id=4)          AS nascar_races,
  (SELECT COUNT(*) FROM race_result rr JOIN race r ON rr.race_id=r.race_id WHERE r.season_id=4) AS nascar_results;

-- ============================================================
-- WRC — World Rally Championship 2023
-- ============================================================


-- ── WRC Championship ──────────────────────────────────────────
INSERT INTO championship (champ_name, category, governing_body, founded_year, official_website)
VALUES ('FIA World Rally Championship', 'WEC', 'FIA', 1973, 'https://www.wrc.com');

SET @wrc_id = LAST_INSERT_ID();

-- ── WRC 2023 Season ───────────────────────────────────────────
INSERT INTO season (championship_id, season_year, start_date, end_date, total_rounds)
VALUES (@wrc_id, 2023, '2023-01-19', '2023-11-16', 13);

SET @wrc23 = LAST_INSERT_ID();

-- ── WRC Countries ─────────────────────────────────────────────
INSERT IGNORE INTO country (country_name, country_code) VALUES
('Estonia',   'EST'), ('Croatia',  'HRV'), ('Greece',    'GRC'),
('Chile',     'CHL'), ('Kenya',    'KEN'), ('Belgium',   'BEL'),
('Indonesia', 'IDN'), ('Ecuador',  'ECU');

-- ── WRC Teams ─────────────────────────────────────────────────
INSERT INTO team (team_name, country_id, base_location, founded_year, principal) VALUES
('Toyota Gazoo Racing WRT',       (SELECT country_id FROM country WHERE country_code='FIN'), 'Jyvaskyla, Finland', 2017, 'Jari-Matti Latvala'),
('Hyundai Shell Mobis WRT',       (SELECT country_id FROM country WHERE country_code='DEU'), 'Alzenau, Germany',   2014, 'Cyril Abiteboul'),
('M-Sport Ford WRT',              (SELECT country_id FROM country WHERE country_code='GBR'), 'Cockermouth, UK',    1979, 'Richard Millener'),
('Toyota Gazoo Racing WRT NG',    (SELECT country_id FROM country WHERE country_code='FIN'), 'Jyvaskyla, Finland', 2022, 'Jari-Matti Latvala');

SET @toyota  = (SELECT team_id FROM team WHERE team_name='Toyota Gazoo Racing WRT');
SET @hyundai = (SELECT team_id FROM team WHERE team_name='Hyundai Shell Mobis WRT');
SET @msport  = (SELECT team_id FROM team WHERE team_name='M-Sport Ford WRT');
SET @toyota2 = (SELECT team_id FROM team WHERE team_name='Toyota Gazoo Racing WRT NG');

-- WRC 2023 championship-team links
INSERT IGNORE INTO championship_team (season_id, team_id) VALUES
(@wrc23, @toyota), (@wrc23, @hyundai), (@wrc23, @msport), (@wrc23, @toyota2);

-- ── WRC Drivers ───────────────────────────────────────────────
INSERT INTO driver (first_name, last_name, nationality_id, date_of_birth, driver_number, abbreviation) VALUES
('Kalle',     'Rovanpera',   (SELECT country_id FROM country WHERE country_code='FIN'), '2000-10-01',  69, 'ROV'),
('Elfyn',     'Evans',       (SELECT country_id FROM country WHERE country_code='GBR'), '1988-10-28',  33, 'EVA'),
('Thierry',   'Neuville',    (SELECT country_id FROM country WHERE country_code='BEL'), '1988-06-16',  11, 'NEU'),
('Esapekka',  'Lappi',       (SELECT country_id FROM country WHERE country_code='FIN'), '1991-09-13',  4,  'LAP'),
('Ott',       'Tanak',       (SELECT country_id FROM country WHERE country_code='EST'), '1987-11-15',  8,  'TAN'),
('Pierre-Louis','Loubet',    (SELECT country_id FROM country WHERE country_code='FRA'), '1996-08-22',  6,  'LOU'),
('Adrien',    'Fourmaux',    (SELECT country_id FROM country WHERE country_code='FRA'), '1996-08-25',  16, 'FOU'),
('Gregoire',  'Munster',     (SELECT country_id FROM country WHERE country_code='BEL'), '1999-09-22',  5,  'MUN'),
('Sebastien', 'Ogier',       (SELECT country_id FROM country WHERE country_code='FRA'), '1983-12-17',  1,  'OGI'),
('Takamoto',  'Katsuta',     (SELECT country_id FROM country WHERE country_code='JPN'), '1993-12-28',  18, 'KAT');

SET @rov = (SELECT driver_id FROM driver WHERE last_name='Rovanpera');
SET @eva = (SELECT driver_id FROM driver WHERE last_name='Evans');
SET @neu = (SELECT driver_id FROM driver WHERE last_name='Neuville');
SET @lap = (SELECT driver_id FROM driver WHERE last_name='Lappi');
SET @tan = (SELECT driver_id FROM driver WHERE last_name='Tanak');
SET @lou = (SELECT driver_id FROM driver WHERE last_name='Loubet');
SET @fou = (SELECT driver_id FROM driver WHERE last_name='Fourmaux');
SET @mun = (SELECT driver_id FROM driver WHERE last_name='Munster');
SET @ogi = (SELECT driver_id FROM driver WHERE last_name='Ogier');
SET @kat = (SELECT driver_id FROM driver WHERE last_name='Katsuta');

-- Team-driver links WRC 2023
INSERT IGNORE INTO team_driver (team_id, driver_id, season_id, role) VALUES
(@toyota,  @rov, @wrc23, 'Rally Driver'), (@toyota,  @eva, @wrc23, 'Rally Driver'),
(@toyota,  @ogi, @wrc23, 'Rally Driver'), (@toyota,  @kat, @wrc23, 'Rally Driver'),
(@hyundai, @neu, @wrc23, 'Rally Driver'), (@hyundai, @tan, @wrc23, 'Rally Driver'),
(@hyundai, @lap, @wrc23, 'Rally Driver'),
(@msport,  @lou, @wrc23, 'Rally Driver'), (@msport,  @fou, @wrc23, 'Rally Driver'),
(@toyota2, @mun, @wrc23, 'Rally Driver');

-- ── WRC Circuits (Rally stages are listed as circuits) ────────
INSERT INTO circuit (circuit_name, country_id, city, track_length_km, circuit_type) VALUES
('Rally Monte Carlo',        (SELECT country_id FROM country WHERE country_code='MCO'), 'Monte Carlo',   334.97, 'Mixed'),
('Rally Sweden',             (SELECT country_id FROM country WHERE country_code='SWE'), 'Umea',          281.18, 'Mixed'),
('Safari Rally Kenya',       (SELECT country_id FROM country WHERE country_code='KEN'), 'Naivasha',      388.74, 'Mixed'),
('Rally Croatia',            (SELECT country_id FROM country WHERE country_code='HRV'), 'Zagreb',        298.53, 'Mixed'),
('Rally Portugal',           (SELECT country_id FROM country WHERE country_code='PRT'), 'Matosinhos',    339.42, 'Mixed'),
('Rally Italia Sardegna',    (SELECT country_id FROM country WHERE country_code='ITA'), 'Alghero',       307.58, 'Mixed'),
('Acropolis Rally Greece',   (SELECT country_id FROM country WHERE country_code='GRC'), 'Lamia',         318.58, 'Mixed'),
('Rally Estonia',            (SELECT country_id FROM country WHERE country_code='EST'), 'Tartu',         317.99, 'Mixed'),
('Rally Finland',            (SELECT country_id FROM country WHERE country_code='FIN'), 'Jyvaskyla',     302.10, 'Mixed'),
('Rally Chile Bio Bio',      (SELECT country_id FROM country WHERE country_code='CHL'), 'Concepcion',    318.57, 'Mixed'),
('Marmaris Rally Turkiye',   (SELECT country_id FROM country WHERE country_code='TUR'), 'Marmaris',      328.80, 'Mixed'),
('Rally Central Europe',     (SELECT country_id FROM country WHERE country_code='AUT'), 'Passau',        326.82, 'Mixed'),
('Rally Japan',              (SELECT country_id FROM country WHERE country_code='JPN'), 'Nagoya',        311.21, 'Mixed');

-- ── WRC 2023 Races ────────────────────────────────────────────
INSERT INTO race (season_id, circuit_id, race_name, race_date, round_number, total_laps, distance_km, status) VALUES
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Rally Monte Carlo'),      'Rally Monte Carlo 2023',    '2023-01-19', 1,  NULL, 334.97, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Rally Sweden'),           'Rally Sweden 2023',         '2023-02-09', 2,  NULL, 281.18, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Safari Rally Kenya'),     'Safari Rally Kenya 2023',   '2023-03-23', 3,  NULL, 388.74, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Rally Croatia'),          'Rally Croatia 2023',        '2023-04-20', 4,  NULL, 298.53, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Rally Portugal'),         'Rally Portugal 2023',       '2023-05-11', 5,  NULL, 339.42, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Rally Italia Sardegna'),  'Rally Italia Sardegna 2023','2023-06-01', 6,  NULL, 307.58, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Acropolis Rally Greece'), 'Acropolis Rally Greece 2023','2023-09-07', 7, NULL, 318.58, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Rally Estonia'),          'Rally Estonia 2023',        '2023-07-20', 8,  NULL, 317.99, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Rally Finland'),          'Rally Finland 2023',        '2023-08-03', 9,  NULL, 302.10, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Rally Chile Bio Bio'),    'Rally Chile Bio Bio 2023',  '2023-09-28', 10, NULL, 318.57, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Marmaris Rally Turkiye'),'Marmaris Rally Turkiye 2023','2023-10-26', 11, NULL, 328.80, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Rally Central Europe'),   'Rally Central Europe 2023', '2023-10-26', 12, NULL, 326.82, 'Completed'),
(@wrc23, (SELECT circuit_id FROM circuit WHERE circuit_name='Rally Japan'),            'Rally Japan 2023',          '2023-11-16', 13, NULL, 311.21, 'Completed');

-- ── WRC Race Results ──────────────────────────────────────────
-- WRC points: 25,18,15,12,10,8,6,4,2,1 same as F1

SET @mc  = (SELECT race_id FROM race WHERE race_name='Rally Monte Carlo 2023');
SET @swe = (SELECT race_id FROM race WHERE race_name='Rally Sweden 2023');
SET @ken = (SELECT race_id FROM race WHERE race_name='Safari Rally Kenya 2023');
SET @cro = (SELECT race_id FROM race WHERE race_name='Rally Croatia 2023');
SET @por = (SELECT race_id FROM race WHERE race_name='Rally Portugal 2023');
SET @sar = (SELECT race_id FROM race WHERE race_name='Rally Italia Sardegna 2023');
SET @grc = (SELECT race_id FROM race WHERE race_name='Acropolis Rally Greece 2023');
SET @est = (SELECT race_id FROM race WHERE race_name='Rally Estonia 2023');
SET @fin = (SELECT race_id FROM race WHERE race_name='Rally Finland 2023');
SET @chi = (SELECT race_id FROM race WHERE race_name='Rally Chile Bio Bio 2023');
SET @tur = (SELECT race_id FROM race WHERE race_name='Marmaris Rally Turkiye 2023');
SET @ceu = (SELECT race_id FROM race WHERE race_name='Rally Central Europe 2023');
SET @jpn = (SELECT race_id FROM race WHERE race_name='Rally Japan 2023');

-- Monte Carlo — Winner: Ogier
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@mc, @ogi, @toyota,  1,1,25,'Finished'),(@mc, @neu, @hyundai, 2,3,18,'Finished'),
(@mc, @rov, @toyota,  3,2,15,'Finished'),(@mc, @eva, @toyota,  4,4,12,'Finished'),
(@mc, @tan, @hyundai, 5,5,10,'Finished'),(@mc, @lap, @hyundai, 6,6, 8,'Finished'),
(@mc, @lou, @msport,  7,7, 6,'Finished'),(@mc, @fou, @msport,  8,8, 4,'Finished'),
(@mc, @mun, @toyota2, 9,9, 2,'Finished'),(@mc, @kat, @toyota, 10,10,1,'Finished');

-- Sweden — Winner: Rovanpera
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@swe, @rov, @toyota,  1,1,25,'Finished'),(@swe, @eva, @toyota,  2,3,18,'Finished'),
(@swe, @neu, @hyundai, 3,2,15,'Finished'),(@swe, @ogi, @toyota,  4,4,12,'Finished'),
(@swe, @tan, @hyundai, 5,5,10,'Finished'),(@swe, @lap, @hyundai, 6,7, 8,'Finished'),
(@swe, @mun, @toyota2, 7,6, 6,'Finished'),(@swe, @kat, @toyota,  8,8, 4,'Finished'),
(@swe, @fou, @msport,  9,9, 2,'Finished'),(@swe, @lou, @msport, 10,10,1,'Finished');

-- Kenya Safari — Winner: Tanak
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@ken, @tan, @hyundai, 1,2,25,'Finished'),(@ken, @ogi, @toyota,  2,1,18,'Finished'),
(@ken, @rov, @toyota,  3,3,15,'Finished'),(@ken, @neu, @hyundai, 4,4,12,'Finished'),
(@ken, @eva, @toyota,  5,5,10,'Finished'),(@ken, @lap, @hyundai, 6,6, 8,'Finished'),
(@ken, @kat, @toyota,  7,7, 6,'Finished'),(@ken, @mun, @toyota2, 8,8, 4,'Finished'),
(@ken, @lou, @msport,  9,9, 2,'Finished'),(@ken, @fou, @msport, 10,10,1,'Finished');

-- Croatia — Winner: Neuville
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@cro, @neu, @hyundai, 1,2,25,'Finished'),(@cro, @rov, @toyota,  2,1,18,'Finished'),
(@cro, @ogi, @toyota,  3,3,15,'Finished'),(@cro, @eva, @toyota,  4,4,12,'Finished'),
(@cro, @tan, @hyundai, 5,5,10,'Finished'),(@cro, @lap, @hyundai, 6,6, 8,'Finished'),
(@cro, @kat, @toyota,  7,7, 6,'Finished'),(@cro, @mun, @toyota2, 8,8, 4,'Finished'),
(@cro, @lou, @msport,  9,9, 2,'Finished'),(@cro, @fou, @msport, 10,10,1,'Finished');

-- Portugal — Winner: Rovanpera
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@por, @rov, @toyota,  1,1,25,'Finished'),(@por, @eva, @toyota,  2,2,18,'Finished'),
(@por, @ogi, @toyota,  3,3,15,'Finished'),(@por, @neu, @hyundai, 4,4,12,'Finished'),
(@por, @tan, @hyundai, 5,5,10,'Finished'),(@por, @lap, @hyundai, 6,6, 8,'Finished'),
(@por, @kat, @toyota,  7,7, 6,'Finished'),(@por, @mun, @toyota2, 8,8, 4,'Finished'),
(@por, @lou, @msport,  9,9, 2,'Finished'),(@por, @fou, @msport, 10,10,1,'Finished');

-- Sardegna — Winner: Evans
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@sar, @eva, @toyota,  1,2,25,'Finished'),(@sar, @rov, @toyota,  2,1,18,'Finished'),
(@sar, @neu, @hyundai, 3,4,15,'Finished'),(@sar, @ogi, @toyota,  4,3,12,'Finished'),
(@sar, @tan, @hyundai, 5,5,10,'Finished'),(@sar, @lap, @hyundai, 6,6, 8,'Finished'),
(@sar, @kat, @toyota,  7,7, 6,'Finished'),(@sar, @mun, @toyota2, 8,8, 4,'Finished'),
(@sar, @fou, @msport,  9,9, 2,'Finished'),(@sar, @lou, @msport, 10,10,1,'Finished');

-- Acropolis — Winner: Rovanpera
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@grc, @rov, @toyota,  1,1,25,'Finished'),(@grc, @neu, @hyundai, 2,2,18,'Finished'),
(@grc, @eva, @toyota,  3,3,15,'Finished'),(@grc, @tan, @hyundai, 4,4,12,'Finished'),
(@grc, @ogi, @toyota,  5,5,10,'Finished'),(@grc, @lap, @hyundai, 6,6, 8,'Finished'),
(@grc, @kat, @toyota,  7,7, 6,'Finished'),(@grc, @mun, @toyota2, 8,8, 4,'Finished'),
(@grc, @lou, @msport,  9,9, 2,'Finished'),(@grc, @fou, @msport, 10,10,1,'Finished');

-- Estonia — Winner: Katsuta
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@est, @kat, @toyota,  1,3,25,'Finished'),(@est, @rov, @toyota,  2,1,18,'Finished'),
(@est, @eva, @toyota,  3,2,15,'Finished'),(@est, @neu, @hyundai, 4,4,12,'Finished'),
(@est, @tan, @hyundai, 5,5,10,'Finished'),(@est, @ogi, @toyota,  6,6, 8,'Finished'),
(@est, @lap, @hyundai, 7,7, 6,'Finished'),(@est, @mun, @toyota2, 8,8, 4,'Finished'),
(@est, @lou, @msport,  9,9, 2,'Finished'),(@est, @fou, @msport, 10,10,1,'Finished');

-- Finland — Winner: Rovanpera
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@fin, @rov, @toyota,  1,1,25,'Finished'),(@fin, @eva, @toyota,  2,2,18,'Finished'),
(@fin, @neu, @hyundai, 3,3,15,'Finished'),(@fin, @tan, @hyundai, 4,4,12,'Finished'),
(@fin, @kat, @toyota,  5,5,10,'Finished'),(@fin, @ogi, @toyota,  6,6, 8,'Finished'),
(@fin, @lap, @hyundai, 7,7, 6,'Finished'),(@fin, @mun, @toyota2, 8,8, 4,'Finished'),
(@fin, @lou, @msport,  9,9, 2,'Finished'),(@fin, @fou, @msport, 10,10,1,'Finished');

-- Chile — Winner: Neuville
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@chi, @neu, @hyundai, 1,2,25,'Finished'),(@chi, @rov, @toyota,  2,1,18,'Finished'),
(@chi, @tan, @hyundai, 3,3,15,'Finished'),(@chi, @eva, @toyota,  4,4,12,'Finished'),
(@chi, @ogi, @toyota,  5,5,10,'Finished'),(@chi, @lap, @hyundai, 6,6, 8,'Finished'),
(@chi, @kat, @toyota,  7,7, 6,'Finished'),(@chi, @mun, @toyota2, 8,8, 4,'Finished'),
(@chi, @lou, @msport,  9,9, 2,'Finished'),(@chi, @fou, @msport, 10,10,1,'Finished');

-- Turkey — Winner: Evans
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@tur, @eva, @toyota,  1,2,25,'Finished'),(@tur, @rov, @toyota,  2,1,18,'Finished'),
(@tur, @neu, @hyundai, 3,3,15,'Finished'),(@tur, @tan, @hyundai, 4,4,12,'Finished'),
(@tur, @ogi, @toyota,  5,5,10,'Finished'),(@tur, @lap, @hyundai, 6,6, 8,'Finished'),
(@tur, @kat, @toyota,  7,7, 6,'Finished'),(@tur, @mun, @toyota2, 8,8, 4,'Finished'),
(@tur, @lou, @msport,  9,9, 2,'Finished'),(@tur, @fou, @msport, 10,10,1,'Finished');

-- Central Europe — Winner: Rovanpera
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@ceu, @rov, @toyota,  1,1,25,'Finished'),(@ceu, @neu, @hyundai, 2,2,18,'Finished'),
(@ceu, @eva, @toyota,  3,3,15,'Finished'),(@ceu, @tan, @hyundai, 4,4,12,'Finished'),
(@ceu, @ogi, @toyota,  5,5,10,'Finished'),(@ceu, @lap, @hyundai, 6,6, 8,'Finished'),
(@ceu, @kat, @toyota,  7,7, 6,'Finished'),(@ceu, @mun, @toyota2, 8,8, 4,'Finished'),
(@ceu, @lou, @msport,  9,9, 2,'Finished'),(@ceu, @fou, @msport, 10,10,1,'Finished');

-- Japan — Winner: Evans (Rovanpera wins title)
INSERT INTO race_result (race_id, driver_id, team_id, finishing_position, grid_position, points_earned, status) VALUES
(@jpn, @eva, @toyota,  1,2,25,'Finished'),(@jpn, @rov, @toyota,  2,1,18,'Finished'),
(@jpn, @neu, @hyundai, 3,3,15,'Finished'),(@jpn, @tan, @hyundai, 4,4,12,'Finished'),
(@jpn, @ogi, @toyota,  5,5,10,'Finished'),(@jpn, @lap, @hyundai, 6,6, 8,'Finished'),
(@jpn, @kat, @toyota,  7,7, 6,'Finished'),(@jpn, @mun, @toyota2, 8,8, 4,'Finished'),
(@jpn, @lou, @msport,  9,9, 2,'Finished'),(@jpn, @fou, @msport, 10,10,1,'Finished');

-- ── WRC Points System ─────────────────────────────────────────
INSERT INTO points_system (championship_id, system_name, valid_from_year, bonus_points)
VALUES (@wrc_id, 'WRC Points System 2023', 2023, 1);

SET @wrc_ps = LAST_INSERT_ID();

INSERT INTO points_system_detail (ps_id, finishing_pos, points_awarded) VALUES
(@wrc_ps,1,25),(@wrc_ps,2,18),(@wrc_ps,3,15),(@wrc_ps,4,12),(@wrc_ps,5,10),
(@wrc_ps,6,8),(@wrc_ps,7,6),(@wrc_ps,8,4),(@wrc_ps,9,2),(@wrc_ps,10,1);

-- ── Assign WRC 2023 Rankings ──────────────────────────────────
CALL sp_assign_final_rankings(@wrc23);

-- ── Verification ──────────────────────────────────────────────
SELECT
  (SELECT COUNT(*) FROM race   WHERE season_id=@wrc23) AS wrc_races,
  (SELECT COUNT(*) FROM race_result rr JOIN race r ON rr.race_id=r.race_id WHERE r.season_id=@wrc23) AS wrc_results,
  (SELECT COUNT(*) FROM driver_standing WHERE season_id=@wrc23) AS wrc_standings;
