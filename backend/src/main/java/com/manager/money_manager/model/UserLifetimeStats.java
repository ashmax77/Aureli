package com.manager.money_manager.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "user_lifetime_stats")
@Data
@NoArgsConstructor
public class UserLifetimeStats {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    private Double totalEarned = 0.0;
    private Double totalSpent = 0.0;
    private Double totalSaved = 0.0;

    @Column(columnDefinition = "TEXT")
    private String achievementsUnlocked; // JSON string array of IDs

    private LocalDateTime lastAggregatedAt;
}
