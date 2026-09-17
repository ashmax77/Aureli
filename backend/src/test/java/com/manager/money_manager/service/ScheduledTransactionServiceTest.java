package com.manager.money_manager.service;

import com.manager.money_manager.dto.CreateScheduledTransactionRequest;
import com.manager.money_manager.dto.ScheduledTransactionDTO;
import com.manager.money_manager.exception.BadRequestException;
import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.CategoryBudgetRepository;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.ScheduledTransactionRepository;
import com.manager.money_manager.repository.TransactionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ScheduledTransactionServiceTest {

    @Mock
    private ScheduledTransactionRepository scheduledTransactionRepository;

    @Mock
    private CategoryRepository categoryRepository;

    @Mock
    private TransactionService transactionService;

    @Mock
    private TransactionRepository transactionRepository;

    @Mock
    private CategoryBudgetRepository categoryBudgetRepository;

    @InjectMocks
    private ScheduledTransactionService scheduledTransactionService;

    private User user;
    private Category expenseCategory;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");
        user.setSavingsRatePercentage(20.0);

        expenseCategory = new Category();
        expenseCategory.setId(10L);
        expenseCategory.setType(TransactionType.EXPENSE);
        expenseCategory.setName("Utilities");
        expenseCategory.setUser(user);
    }

    @Test
    void createScheduledTransaction_exceedsMargin_throwsBadRequestException() {
        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(expenseCategory));

        LocalDate dueDate = LocalDate.of(2026, 9, 15);
        LocalDate start = LocalDate.of(2026, 9, 1);
        LocalDate end = LocalDate.of(2026, 9, 30);

        // Income = 10,000 LKR -> Savings 20% (2,000 LKR) -> Spendable = 8,000 LKR
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetween(eq(1L), eq(TransactionType.INCOME), eq(start), eq(end)))
                .thenReturn(new BigDecimal("10000.00"));

        // Category budgets = 5,000 LKR
        CategoryBudget cb = new CategoryBudget();
        cb.setAmountLimit(new BigDecimal("5000.00"));
        when(categoryBudgetRepository.findByUserIdAndBudgetMonth(1L, start))
                .thenReturn(List.of(cb));

        // Existing scheduled transactions = 2,000 LKR
        ScheduledTransaction existingSt = new ScheduledTransaction();
        existingSt.setId(100L);
        existingSt.setType(TransactionType.EXPENSE);
        existingSt.setAmount(new BigDecimal("2000.00"));
        existingSt.setDueDate(dueDate);
        when(scheduledTransactionRepository.findByUserIdAndStatusOrderByDueDateAsc(1L, ScheduledStatus.PENDING))
                .thenReturn(List.of(existingSt));

        // Available margin = 8,000 - 5,000 - 2,000 = 1,000 LKR
        CreateScheduledTransactionRequest req = new CreateScheduledTransactionRequest();
        req.setCategoryId(10L);
        req.setType(TransactionType.EXPENSE);
        req.setTitle("Internet Bill");
        req.setAmount(new BigDecimal("1500.00")); // Exceeds 1,000 LKR margin!
        req.setDueDate(dueDate);

        assertThrows(BadRequestException.class, () ->
                scheduledTransactionService.createScheduledTransaction(req, user));
    }

    @Test
    void createScheduledTransaction_withinMargin_success() {
        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(expenseCategory));

        LocalDate dueDate = LocalDate.of(2026, 9, 15);
        LocalDate start = LocalDate.of(2026, 9, 1);
        LocalDate end = LocalDate.of(2026, 9, 30);

        // Income = 10,000 LKR -> Savings 20% (2,000 LKR) -> Spendable = 8,000 LKR
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetween(eq(1L), eq(TransactionType.INCOME), eq(start), eq(end)))
                .thenReturn(new BigDecimal("10000.00"));

        // Category budgets = 5,000 LKR
        CategoryBudget cb = new CategoryBudget();
        cb.setAmountLimit(new BigDecimal("5000.00"));
        when(categoryBudgetRepository.findByUserIdAndBudgetMonth(1L, start))
                .thenReturn(List.of(cb));

        when(scheduledTransactionRepository.findByUserIdAndStatusOrderByDueDateAsc(1L, ScheduledStatus.PENDING))
                .thenReturn(List.of());

        // Available margin = 8,000 - 5,000 = 3,000 LKR
        CreateScheduledTransactionRequest req = new CreateScheduledTransactionRequest();
        req.setCategoryId(10L);
        req.setType(TransactionType.EXPENSE);
        req.setTitle("Internet Bill");
        req.setAmount(new BigDecimal("1500.00")); // Within margin
        req.setDueDate(dueDate);

        when(scheduledTransactionRepository.save(any(ScheduledTransaction.class))).thenAnswer(i -> {
            ScheduledTransaction st = i.getArgument(0);
            st.setId(200L);
            return st;
        });

        ScheduledTransactionDTO result = scheduledTransactionService.createScheduledTransaction(req, user);
        assertNotNull(result);
        assertEquals(new BigDecimal("1500.00"), result.getAmount());
        assertEquals("Internet Bill", result.getTitle());
    }
}
