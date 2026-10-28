package com.manager.money_manager.service;

import com.manager.money_manager.dto.CreateDebtRepaymentRequest;
import com.manager.money_manager.dto.CreateDebtRequest;
import com.manager.money_manager.dto.DebtRecordDTO;
import com.manager.money_manager.dto.DebtSummaryDTO;
import com.manager.money_manager.dto.UpdateDebtRequest;
import com.manager.money_manager.exception.BadRequestException;
import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.DebtRecordRepository;
import com.manager.money_manager.repository.DebtRepaymentRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DebtServiceTest {

    @Mock
    private DebtRecordRepository debtRecordRepository;

    @Mock
    private DebtRepaymentRepository debtRepaymentRepository;

    @InjectMocks
    private DebtService debtService;

    private User user;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");
    }

    @Test
    void createDebt_withoutInterest_calculatesCorrectTotal() {
        CreateDebtRequest req = new CreateDebtRequest();
        req.setType(DebtType.BORROWED);
        req.setCounterpartyName("Commercial Bank");
        req.setPrincipalAmount(new BigDecimal("10000.00"));
        req.setStartDate(LocalDate.of(2026, 9, 1));
        req.setDueDate(LocalDate.of(2026, 12, 1));

        when(debtRecordRepository.save(any(DebtRecord.class))).thenAnswer(i -> i.getArgument(0));

        DebtRecordDTO result = debtService.createDebt(req, user);

        assertNotNull(result);
        assertEquals(new BigDecimal("10000.00"), result.getPrincipalAmount());
        assertEquals(new BigDecimal("10000.00"), result.getTotalAmountDue());
        assertEquals(new BigDecimal("10000.00"), result.getRemainingAmount());
        assertEquals(BigDecimal.ZERO, result.getAmountRepaid());
        assertEquals(DebtStatus.ACTIVE, result.getStatus());
    }

    @Test
    void createDebt_withInterest_calculatesCorrectTotal() {
        CreateDebtRequest req = new CreateDebtRequest();
        req.setType(DebtType.BORROWED);
        req.setCounterpartyName("Private Lender");
        req.setPrincipalAmount(new BigDecimal("50000.00"));
        req.setInterestRate(new BigDecimal("10.00")); // 10% interest -> 5,000 LKR
        req.setStartDate(LocalDate.of(2026, 9, 1));
        req.setDueDate(LocalDate.of(2026, 10, 1));

        when(debtRecordRepository.save(any(DebtRecord.class))).thenAnswer(i -> i.getArgument(0));

        DebtRecordDTO result = debtService.createDebt(req, user);

        assertNotNull(result);
        assertEquals(new BigDecimal("50000.00"), result.getPrincipalAmount());
        assertEquals(new BigDecimal("55000.00"), result.getTotalAmountDue());
        assertEquals(new BigDecimal("55000.00"), result.getRemainingAmount());
    }

    @Test
    void recordRepayment_partial_reducesRemainingBalance() {
        DebtRecord debt = new DebtRecord();
        debt.setId(10L);
        debt.setUser(user);
        debt.setType(DebtType.LENT);
        debt.setCounterpartyName("Alice");
        debt.setPrincipalAmount(new BigDecimal("5000.00"));
        debt.setTotalAmountDue(new BigDecimal("5000.00"));
        debt.setAmountRepaid(BigDecimal.ZERO);
        debt.setRemainingAmount(new BigDecimal("5000.00"));
        debt.setStatus(DebtStatus.ACTIVE);

        when(debtRecordRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(debt));
        when(debtRecordRepository.save(any(DebtRecord.class))).thenAnswer(i -> i.getArgument(0));

        CreateDebtRepaymentRequest repReq = new CreateDebtRepaymentRequest();
        repReq.setAmount(new BigDecimal("2000.00"));
        repReq.setRepaymentDate(LocalDate.of(2026, 9, 15));
        repReq.setPaymentMethod(PaymentMethod.BANK_TRANSFER);

        DebtRecordDTO result = debtService.recordRepayment(10L, repReq, user);

        assertNotNull(result);
        assertEquals(new BigDecimal("2000.00"), result.getAmountRepaid());
        assertEquals(new BigDecimal("3000.00"), result.getRemainingAmount());
        assertEquals(DebtStatus.ACTIVE, result.getStatus());
        verify(debtRepaymentRepository, times(1)).save(any(DebtRepayment.class));
    }

    @Test
    void recordRepayment_full_setsStatusSettled() {
        DebtRecord debt = new DebtRecord();
        debt.setId(10L);
        debt.setUser(user);
        debt.setType(DebtType.LENT);
        debt.setCounterpartyName("Alice");
        debt.setPrincipalAmount(new BigDecimal("5000.00"));
        debt.setTotalAmountDue(new BigDecimal("5000.00"));
        debt.setAmountRepaid(new BigDecimal("2000.00"));
        debt.setRemainingAmount(new BigDecimal("3000.00"));
        debt.setStatus(DebtStatus.ACTIVE);

        when(debtRecordRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(debt));
        when(debtRecordRepository.save(any(DebtRecord.class))).thenAnswer(i -> i.getArgument(0));

        CreateDebtRepaymentRequest repReq = new CreateDebtRepaymentRequest();
        repReq.setAmount(new BigDecimal("3000.00"));
        repReq.setRepaymentDate(LocalDate.of(2026, 9, 20));
        repReq.setPaymentMethod(PaymentMethod.CASH);

        DebtRecordDTO result = debtService.recordRepayment(10L, repReq, user);

        assertNotNull(result);
        assertEquals(new BigDecimal("5000.00"), result.getAmountRepaid());
        assertEquals(BigDecimal.ZERO, result.getRemainingAmount());
        assertEquals(DebtStatus.SETTLED, result.getStatus());
    }

    @Test
    void recordRepayment_exceedsRemaining_throwsBadRequestException() {
        DebtRecord debt = new DebtRecord();
        debt.setId(10L);
        debt.setUser(user);
        debt.setRemainingAmount(new BigDecimal("1000.00"));
        debt.setStatus(DebtStatus.ACTIVE);

        when(debtRecordRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(debt));

        CreateDebtRepaymentRequest repReq = new CreateDebtRepaymentRequest();
        repReq.setAmount(new BigDecimal("1500.00")); // Exceeds 1000 remaining!
        repReq.setRepaymentDate(LocalDate.now());
        repReq.setPaymentMethod(PaymentMethod.BANK_TRANSFER);

        assertThrows(BadRequestException.class, () -> debtService.recordRepayment(10L, repReq, user));
    }

    @Test
    void recordRepayment_alreadySettled_throwsBadRequestException() {
        DebtRecord debt = new DebtRecord();
        debt.setId(10L);
        debt.setUser(user);
        debt.setRemainingAmount(BigDecimal.ZERO);
        debt.setStatus(DebtStatus.SETTLED);

        when(debtRecordRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(debt));

        CreateDebtRepaymentRequest repReq = new CreateDebtRepaymentRequest();
        repReq.setAmount(new BigDecimal("500.00"));
        repReq.setRepaymentDate(LocalDate.now());
        repReq.setPaymentMethod(PaymentMethod.BANK_TRANSFER);

        assertThrows(BadRequestException.class, () -> debtService.recordRepayment(10L, repReq, user));
    }

    @Test
    void updateDebt_rejectsDirectStatusMutation() {
        DebtRecord debt = new DebtRecord();
        debt.setId(10L);
        debt.setUser(user);
        debt.setStatus(DebtStatus.ACTIVE);

        UpdateDebtRequest update = new UpdateDebtRequest();
        update.setStatus(DebtStatus.SETTLED);

        when(debtRecordRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(debt));

        assertThrows(BadRequestException.class, () -> debtService.updateDebt(10L, update, user));
        verify(debtRecordRepository, never()).save(any(DebtRecord.class));
    }

    @Test
    void getSummary_calculatesNetDebtPositionCorrectly() {
        // Lent = 15,000 LKR (receivables)
        when(debtRecordRepository.sumRemainingAmountByUserIdAndType(1L, DebtType.LENT))
                .thenReturn(new BigDecimal("15000.00"));
        // Borrowed = 10,000 LKR (liabilities)
        when(debtRecordRepository.sumRemainingAmountByUserIdAndType(1L, DebtType.BORROWED))
                .thenReturn(new BigDecimal("10000.00"));

        when(debtRecordRepository.countByUserIdAndTypeAndStatusActive(1L, DebtType.LENT)).thenReturn(2L);
        when(debtRecordRepository.countByUserIdAndTypeAndStatusActive(1L, DebtType.BORROWED)).thenReturn(1L);
        when(debtRecordRepository.countByUserIdAndStatusOverdue(1L)).thenReturn(0L);

        DebtSummaryDTO summary = debtService.getSummary(user);

        assertNotNull(summary);
        assertEquals(new BigDecimal("15000.00"), summary.getTotalLent());
        assertEquals(new BigDecimal("10000.00"), summary.getTotalBorrowed());
        // Net Debt Position = Total Lent - Total Borrowed = 15,000 - 10,000 = +5,000
        assertEquals(new BigDecimal("5000.00"), summary.getNetDebtPosition());
        assertEquals(2L, summary.getActiveLentCount());
        assertEquals(1L, summary.getActiveBorrowedCount());
        assertEquals(0L, summary.getOverdueCount());
    }

    @Test
    void deleteDebt_success() {
        DebtRecord debt = new DebtRecord();
        debt.setId(10L);
        debt.setUser(user);

        when(debtRecordRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(debt));

        debtService.deleteDebt(10L, user);

        verify(debtRecordRepository, times(1)).delete(debt);
    }
}
