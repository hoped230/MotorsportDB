package com.motorsport.model;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "driver")
@Data
public class Driver {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer driverId;

    @Column(nullable = false)
    private String firstName;

    @Column(nullable = false)
    private String lastName;

    private Integer nationalityId;
    private java.sql.Date dateOfBirth;
    private Short driverNumber;
    private String abbreviation;

    @Column(columnDefinition = "TEXT")
    private String bio;

    private String profileImgUrl;
}
