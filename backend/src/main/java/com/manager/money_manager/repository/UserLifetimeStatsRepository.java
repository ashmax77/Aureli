package com.manager.money_manager.repository;

import com.manager.money_manager.model.UserLifetimeStats;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserLifetimeStatsRepository extends JpaRepository<UserLifetimeStats, Long> {
    Optional<UserLifetimeStats> findByUserId(Long userId);
}
