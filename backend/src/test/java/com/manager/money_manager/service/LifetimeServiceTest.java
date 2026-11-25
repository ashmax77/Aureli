package com.manager.money_manager.service;

import com.manager.money_manager.dto.AchievementDTO;
import com.manager.money_manager.dto.LifetimeStatsDTO;
import com.manager.money_manager.model.TransactionType;
import com.manager.money_manager.model.User;
import com.manager.money_manager.model.UserLifetimeStats;
import com.manager.money_manager.repository.TransactionRepository;
import com.manager.money_manager.repository.UserLifetimeStatsRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class LifetimeServiceTest {

    @Mock
    private UserLifetimeStatsRepository statsRepository;

    @Mock
    private TransactionRepository transactionRepository;

    @InjectMocks
    private LifetimeService lifetimeService;

    private User user;
    private final AtomicReference<UserLifetimeStats> stored = new AtomicReference<>();

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        when(statsRepository.findByUserId(1L)).thenAnswer(i -> Optional.ofNullable(stored.get()));
        when(statsRepository.save(any(UserLifetimeStats.class))).thenAnswer(i -> {
            stored.set(i.getArgument(0));
            return i.getArgument(0);
        });
        when(transactionRepository.sumSavingsAmountByUserIdUpToDate(eq(1L), any()))
                .thenReturn(new BigDecimal("2000.00"));
    }

    private void stubTotals(String income, String expense) {
        List<Object[]> rows = new ArrayList<>();
        if (income != null) rows.add(new Object[]{TransactionType.INCOME, new BigDecimal(income)});
        if (expense != null) rows.add(new Object[]{TransactionType.EXPENSE, new BigDecimal(expense)});
        when(transactionRepository.sumAmountByUserIdAndDateBetweenGroupByType(eq(1L), any(), any())).thenReturn(rows);
    }

    @Test
    void getStats_reflectsTransactionsAddedAfterFirstAggregation() {
        stubTotals("10000.00", null);
        lifetimeService.getStats(user, null);

        stubTotals("10000.00", "3000.00");
        LifetimeStatsDTO after = lifetimeService.getStats(user, null);

        assertEquals(3000.0, after.getTotalSpent());
        assertEquals(7000.0, after.getNetWorth());
    }

    @Test
    void getStats_totalSavedIsReservedSavingsNotNetCashFlow() {
        stubTotals("10000.00", "3000.00");

        LifetimeStatsDTO stats = lifetimeService.getStats(user, null);

        assertEquals(2000.0, stats.getTotalSaved());
    }

    @Test
    void getAchievements_firstBloodRequiresAnExpense() {
        stubTotals("10000.00", null);
        AchievementDTO incomeOnly = lifetimeService.getAchievements(user).get(0);
        assertFalse(incomeOnly.isUnlocked());

        stubTotals("10000.00", "50.00");
        AchievementDTO withExpense = lifetimeService.getAchievements(user).get(0);
        assertTrue(withExpense.isUnlocked());
    }
}
