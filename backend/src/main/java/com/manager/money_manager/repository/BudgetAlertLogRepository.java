package com.manager.money_manager.repository;

import com.manager.money_manager.model.BudgetAlertLog;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;

public interface BudgetAlertLogRepository extends JpaRepository<BudgetAlertLog, Long> {
    boolean existsByUserIdAndCategoryIdAndBudgetMonthAndThreshold(Long userId, Long categoryId, LocalDate budgetMonth, String threshold);
}
