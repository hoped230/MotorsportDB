package com.motorsport.repository;

import com.motorsport.model.Driver;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

@Repository
public interface DriverRepository extends JpaRepository<Driver, Integer> {

    // Basic query — find by nationality
    @Query(value = "SELECT * FROM driver WHERE nationality_id = :countryId", nativeQuery = true)
    List<Driver> findByNationality(@Param("countryId") Integer countryId);

    // Basic query — search by last name
    @Query(value = "SELECT * FROM driver WHERE last_name LIKE %:name%", nativeQuery = true)
    List<Driver> searchByName(@Param("name") String name);

    // Complex query — driver with career stats (aggregation + join)
    @Query(value = """
        SELECT d.driver_id, CONCAT(d.first_name,' ',d.last_name) AS driver_name,
               co.country_name AS nationality,
               COUNT(DISTINCT rr.race_id) AS races_entered,
               COALESCE(SUM(rr.points_earned), 0) AS career_points,
               COUNT(CASE WHEN rr.finishing_position = 1 THEN 1 END) AS wins,
               COUNT(CASE WHEN rr.finishing_position <= 3 THEN 1 END) AS podiums
        FROM driver d
        LEFT JOIN country co     ON d.nationality_id = co.country_id
        LEFT JOIN race_result rr ON d.driver_id = rr.driver_id
        GROUP BY d.driver_id, d.first_name, d.last_name, co.country_name
        ORDER BY career_points DESC
        """, nativeQuery = true)
    List<Map<String, Object>> findAllWithCareerStats();
}
