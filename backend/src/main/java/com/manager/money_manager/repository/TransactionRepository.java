package com.manager.money_manager.repository;

import com.manager.money_manager.model.Transaction;
import com.manager.money_manager.model.TransactionType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface TransactionRepository extends JpaRepository<Transaction, Long>, JpaSpecificationExecutor<Transaction> {
    Page<Transaction> findByUserId(Long userId, Pageable pageable);
    Optional<Transaction> findByIdAndUserId(Long id, Long userId);

    @Query("SELECT t.category.id, SUM(t.amount), COUNT(t.id) " +
           "FROM Transaction t " +
           "WHERE t.user.id = :userId " +
           "AND t.type = :type " +
           "AND t.transactionDate BETWEEN :startDate AND :endDate " +
           "GROUP BY t.category.id")
    List<Object[]> sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
            @Param("userId") Long userId,
            @Param("type") TransactionType type,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    @Query("SELECT t.type, SUM(t.amount) " +
           "FROM Transaction t " +
           "WHERE t.user.id = :userId " +
           "AND t.transactionDate BETWEEN :startDate AND :endDate " +
           "GROUP BY t.type")
    List<Object[]> sumAmountByUserIdAndDateBetweenGroupByType(
            @Param("userId") Long userId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    @Query("SELECT FUNCTION('TO_CHAR', t.transactionDate, 'YYYY-MM') as monthStr, t.type, SUM(t.amount) " +
           "FROM Transaction t " +
           "WHERE t.user.id = :userId " +
           "AND t.transactionDate >= :sinceDate " +
           "GROUP BY FUNCTION('TO_CHAR', t.transactionDate, 'YYYY-MM'), t.type " +
           "ORDER BY monthStr ASC")
    List<Object[]> sumAmountMonthlyTrends(
            @Param("userId") Long userId,
            @Param("sinceDate") LocalDate sinceDate);
}
