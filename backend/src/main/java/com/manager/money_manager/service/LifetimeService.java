package com.manager.money_manager.service;

import com.manager.money_manager.dto.AchievementDTO;
import com.manager.money_manager.dto.LifetimeStatsDTO;
import com.manager.money_manager.model.TransactionType;
import com.manager.money_manager.model.User;
import com.manager.money_manager.model.UserLifetimeStats;
import com.manager.money_manager.repository.TransactionRepository;
import com.manager.money_manager.repository.UserLifetimeStatsRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
public class LifetimeService {

    private final UserLifetimeStatsRepository statsRepository;
    private final TransactionRepository transactionRepository;

    public LifetimeService(UserLifetimeStatsRepository statsRepository, TransactionRepository transactionRepository) {
        this.statsRepository = statsRepository;
        this.transactionRepository = transactionRepository;
    }

    @Transactional
    public LifetimeStatsDTO getStats(User user, Integer year) {
        if (year == null) {
            // All-Time logic
            UserLifetimeStats stats = aggregateAllTime(user);
            return mapToDTO(stats);
        } else {
            // Specific year logic
            return aggregateForYear(user, year);
        }
    }

    @Transactional
    public List<AchievementDTO> getAchievements(User user) {
        UserLifetimeStats stats = aggregateAllTime(user);

        List<AchievementDTO> achievements = new ArrayList<>();
        // Define some baseline achievements
        achievements.add(AchievementDTO.builder()
                .id("first_blood")
                .title("First Blood")
                .description("Logged your first expense.")
                .iconKey("add_circle")
                .isUnlocked(stats.getTotalSpent() > 0)
                .build());

        achievements.add(AchievementDTO.builder()
                .id("savant")
                .title("Savant")
                .description("Saved over LKR 1,000,000.")
                .iconKey("star")
                .isUnlocked(stats.getTotalSaved() > 1000000)
                .build());

        // We can add more based on requirements. For now this returns the list to the user.
        return achievements;
    }

    private UserLifetimeStats aggregateAllTime(User user) {
        LocalDate today = LocalDate.now();
        List<Object[]> sums = transactionRepository.sumAmountByUserIdAndDateBetweenGroupByType(
                user.getId(), LocalDate.of(1970, 1, 1), today);

        Double earned = 0.0;
        Double spent = 0.0;

        for (Object[] row : sums) {
            TransactionType type = (TransactionType) row[0];
            Double sum = ((Number) row[1]).doubleValue();
            if (type == TransactionType.INCOME) {
                earned = sum;
            } else if (type == TransactionType.EXPENSE) {
                spent = sum;
            }
        }

        UserLifetimeStats stats = statsRepository.findByUserId(user.getId()).orElse(new UserLifetimeStats());
        stats.setUser(user);
        stats.setTotalEarned(earned);
        stats.setTotalSpent(spent);
        java.math.BigDecimal reservedSavings = transactionRepository.sumSavingsAmountByUserIdUpToDate(
                user.getId(), today);
        stats.setTotalSaved(reservedSavings != null ? reservedSavings.doubleValue() : 0.0);
        stats.setLastAggregatedAt(LocalDateTime.now());
        return statsRepository.save(stats);
    }

    private LifetimeStatsDTO aggregateForYear(User user, int year) {
        LocalDate start = LocalDate.of(year, 1, 1);
        LocalDate end = LocalDate.of(year, 12, 31);
        List<Object[]> sums = transactionRepository.sumAmountByUserIdAndDateBetweenGroupByType(
                user.getId(), start, end);

        Double earned = 0.0;
        Double spent = 0.0;

        for (Object[] row : sums) {
            TransactionType type = (TransactionType) row[0];
            Double sum = ((Number) row[1]).doubleValue();
            if (type == TransactionType.INCOME) {
                earned = sum;
            } else if (type == TransactionType.EXPENSE) {
                spent = sum;
            }
        }

        java.math.BigDecimal reservedSavings = transactionRepository.sumSavingsAmountByUserIdAndDateBetween(
                user.getId(), start, end);

        return LifetimeStatsDTO.builder()
                .totalEarned(earned)
                .totalSpent(spent)
                .totalSaved(reservedSavings != null ? reservedSavings.doubleValue() : 0.0)
                .netWorth(earned - spent) // simplified
                .activeMonths(12) // simplified
                .build();
    }

    private LifetimeStatsDTO mapToDTO(UserLifetimeStats stats) {
        return LifetimeStatsDTO.builder()
                .totalEarned(stats.getTotalEarned())
                .totalSpent(stats.getTotalSpent())
                .totalSaved(stats.getTotalSaved())
                .netWorth(stats.getTotalEarned() - stats.getTotalSpent())
                .activeMonths(12)
                .build();
    }
}
