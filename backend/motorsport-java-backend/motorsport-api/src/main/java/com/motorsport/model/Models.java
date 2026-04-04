package com.motorsport.model;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;

// ── Team ────────────────────────────────────────────────────
@Entity
@Table(name = "team")
@Data
class Team {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer teamId;
    @Column(nullable = false)
    private String teamName;
    private Integer countryId;
    private String baseLocation;
    private Short foundedYear;
    private String principal;
    private String logoUrl;
}

// ── Championship ─────────────────────────────────────────────
@Entity
@Table(name = "championship")
@Data
class Championship {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer championshipId;
    @Column(nullable = false)
    private String champName;
    @Column(nullable = false)
    private String category;
    private String governingBody;
    private Short foundedYear;
    private String officialWebsite;
}

// ── Season ────────────────────────────────────────────────────
@Entity
@Table(name = "season")
@Data
class Season {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer seasonId;
    @Column(nullable = false)
    private Integer championshipId;
    @Column(nullable = false)
    private Short seasonYear;
    private java.sql.Date startDate;
    private java.sql.Date endDate;
    private Short totalRounds;
}

// ── Circuit ───────────────────────────────────────────────────
@Entity
@Table(name = "circuit")
@Data
class Circuit {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer circuitId;
    @Column(nullable = false)
    private String circuitName;
    private Integer countryId;
    private String city;
    private BigDecimal trackLengthKm;
    private String lapRecordTime;
    private Short lapRecordYear;
    private String circuitType;
    private Integer capacity;
}

// ── Race ──────────────────────────────────────────────────────
@Entity
@Table(name = "race")
@Data
class Race {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer raceId;
    @Column(nullable = false)
    private Integer seasonId;
    @Column(nullable = false)
    private Integer circuitId;
    @Column(nullable = false)
    private String raceName;
    private java.sql.Date raceDate;
    private Short roundNumber;
    private Short totalLaps;
    private BigDecimal distanceKm;
    private String status;
}

// ── RaceResult ────────────────────────────────────────────────
@Entity
@Table(name = "race_result")
@Data
class RaceResult {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer resultId;
    @Column(nullable = false)
    private Integer raceId;
    @Column(nullable = false)
    private Integer driverId;
    private Integer teamId;
    private Short finishingPosition;
    private Short gridPosition;
    private BigDecimal pointsEarned;
    private Short lapsCompleted;
    private String raceTime;
    private String gapToLeader;
    private String status;
    private Boolean fastestLap;
}

// ── DriverStanding ────────────────────────────────────────────
@Entity
@Table(name = "driver_standing")
@Data
class DriverStanding {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer dsId;
    private Integer seasonId;
    private Integer driverId;
    private Integer teamId;
    private BigDecimal totalPoints;
    private Short position;
    private Short wins;
    private Short podiums;
    private Short poles;
    private Short fastestLaps;
    private Short afterRound;
}
