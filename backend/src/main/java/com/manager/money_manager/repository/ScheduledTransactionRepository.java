package com.manager.money_manager.repository;

import com.manager.money_manager.model.ScheduledStatus;
import com.manager.money_manager.model.ScheduledTransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface ScheduledTransactionRepository extends JpaRepository<ScheduledTransaction, Long> {

    List<ScheduledTransaction> findByUserIdOrderByDueDateAsc(Long userId);

    List<ScheduledTransaction> findByUserIdAndStatusOrderByDueDateAsc(Long userId, ScheduledStatus status);

    @Query("SELECT s FROM ScheduledTransaction s WHERE s.status = 'PENDING' AND s.dueDate <= :targetDate")
    List<ScheduledTransaction> findPendingForReminderCheck(@Param("targetDate") LocalDate targetDate);
}
