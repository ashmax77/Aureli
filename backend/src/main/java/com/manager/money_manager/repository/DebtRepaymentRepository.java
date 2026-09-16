package com.manager.money_manager.repository;

import com.manager.money_manager.model.DebtRepayment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DebtRepaymentRepository extends JpaRepository<DebtRepayment, Long> {

    List<DebtRepayment> findByDebtRecordIdAndUserIdOrderByRepaymentDateDesc(Long debtRecordId, Long userId);

    List<DebtRepayment> findByUserIdOrderByRepaymentDateDesc(Long userId);
}
