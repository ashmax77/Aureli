package com.manager.money_manager.repository;

import com.manager.money_manager.model.DebtRecord;
import com.manager.money_manager.model.DebtStatus;
import com.manager.money_manager.model.DebtType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface DebtRecordRepository extends JpaRepository<DebtRecord, Long> {

    List<DebtRecord> findByUserIdOrderByCreatedAtDesc(Long userId);

    List<DebtRecord> findByUserIdAndTypeOrderByCreatedAtDesc(Long userId, DebtType type);

    List<DebtRecord> findByUserIdAndStatusOrderByCreatedAtDesc(Long userId, DebtStatus status);

    List<DebtRecord> findByUserIdAndTypeAndStatusOrderByCreatedAtDesc(Long userId, DebtType type, DebtStatus status);

    Optional<DebtRecord> findByIdAndUserId(Long id, Long userId);

    @Query("SELECT d FROM DebtRecord d " +
           "WHERE d.status = com.manager.money_manager.model.DebtStatus.ACTIVE " +
           "AND d.dueDate IS NOT NULL " +
           "AND d.dueDate <= :windowEndDate")
    List<DebtRecord> findActiveDebtsForReminderCheck(@Param("windowEndDate") LocalDate windowEndDate);

    @Query("SELECT COALESCE(SUM(d.remainingAmount), 0) FROM DebtRecord d " +
           "WHERE d.user.id = :userId AND d.type = :type AND d.status IN (com.manager.money_manager.model.DebtStatus.ACTIVE, com.manager.money_manager.model.DebtStatus.OVERDUE)")
    java.math.BigDecimal sumRemainingAmountByUserIdAndType(
            @Param("userId") Long userId,
            @Param("type") DebtType type);

    @Query("SELECT COUNT(d) FROM DebtRecord d " +
           "WHERE d.user.id = :userId AND d.type = :type AND d.status = com.manager.money_manager.model.DebtStatus.ACTIVE")
    long countByUserIdAndTypeAndStatusActive(
            @Param("userId") Long userId,
            @Param("type") DebtType type);

    @Query("SELECT COUNT(d) FROM DebtRecord d " +
           "WHERE d.user.id = :userId AND d.status = com.manager.money_manager.model.DebtStatus.OVERDUE")
    long countByUserIdAndStatusOverdue(@Param("userId") Long userId);
}
