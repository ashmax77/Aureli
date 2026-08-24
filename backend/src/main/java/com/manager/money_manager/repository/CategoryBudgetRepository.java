package com.manager.money_manager.repository;

import com.manager.money_manager.model.CategoryBudget;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.time.LocalDate;
import java.util.Optional;

public interface CategoryBudgetRepository extends JpaRepository<CategoryBudget, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT cb FROM CategoryBudget cb WHERE cb.category.id = :categoryId AND cb.budgetMonth = :month AND cb.user.id = :userId")
    Optional<CategoryBudget> findByCategoryIdAndBudgetMonthAndUserIdForUpdate(
            @Param("categoryId") Long categoryId,
            @Param("month") LocalDate month,
            @Param("userId") Long userId);

    Optional<CategoryBudget> findByCategoryIdAndBudgetMonthAndUserId(Long categoryId, LocalDate month, Long userId);
}
