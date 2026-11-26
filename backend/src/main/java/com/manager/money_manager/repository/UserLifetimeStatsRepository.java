package com.manager.money_manager.repository;

import com.manager.money_manager.model.UserLifetimeStats;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserLifetimeStatsRepository extends JpaRepository<UserLifetimeStats, Long> {
    Optional<UserLifetimeStats> findByUserId(Long userId);

    /**
     * Creates the user's stats row if it does not exist yet. Atomic: two concurrent first
     * requests for the same user cannot both insert, so neither fails on the unique key.
     */
    @Modifying
    @Query(value = "INSERT INTO user_lifetime_stats (user_id, total_earned, total_spent, total_saved) " +
            "VALUES (:userId, 0, 0, 0) ON CONFLICT (user_id) DO NOTHING", nativeQuery = true)
    int insertIfAbsent(@Param("userId") Long userId);
}
