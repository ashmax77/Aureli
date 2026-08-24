package com.manager.money_manager.service;

import com.manager.money_manager.dto.CreateTransactionRequest;
import com.manager.money_manager.dto.TransactionDTO;
import com.manager.money_manager.exception.BadRequestException;
import com.manager.money_manager.exception.ResourceNotFoundException;
import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.TransactionRepository;
import com.manager.money_manager.repository.CategoryBudgetRepository;
import com.manager.money_manager.repository.BudgetAlertLogRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TransactionServiceTest {

    @Mock
    private TransactionRepository transactionRepository;

    @Mock
    private CategoryRepository categoryRepository;

    @Mock
    private NotificationService notificationService;

    @Mock
    private CategoryBudgetRepository categoryBudgetRepository;

    @Mock
    private BudgetAlertLogRepository budgetAlertLogRepository;

    @InjectMocks
    private TransactionService transactionService;

    private User user;
    private Category category;
    private Transaction transaction;
    private CategoryBudget categoryBudget;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");

        category = new Category();
        category.setId(10L);
        category.setType(TransactionType.EXPENSE);
        category.setName("Food");
        category.setUser(user);

        categoryBudget = new CategoryBudget();
        categoryBudget.setId(200L);
        categoryBudget.setUser(user);
        categoryBudget.setCategory(category);
        categoryBudget.setAmountLimit(new BigDecimal("500.00")); // Limit 500
        categoryBudget.setBudgetMonth(LocalDate.now().withDayOfMonth(1));

        transaction = new Transaction();
        transaction.setId(100L);
        transaction.setUser(user);
        transaction.setCategory(category);
        transaction.setType(TransactionType.EXPENSE);
        transaction.setAmount(new BigDecimal("150.00"));
        transaction.setTransactionDate(LocalDate.now());
        transaction.setPaymentMethod(PaymentMethod.CASH);
    }

    @Test
    void createTransaction_success_normalSpendNoAlert() {
        CreateTransactionRequest request = new CreateTransactionRequest();
        request.setType(TransactionType.EXPENSE);
        request.setCategoryId(10L);
        request.setAmount(new BigDecimal("150.00"));
        request.setTransactionDate(LocalDate.now());
        request.setPaymentMethod(PaymentMethod.CASH);

        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(category));
        when(transactionRepository.save(any(Transaction.class))).thenReturn(transaction);
        
        when(categoryBudgetRepository.findByCategoryIdAndBudgetMonthAndUserIdForUpdate(eq(10L), any(LocalDate.class), eq(1L)))
                .thenReturn(Optional.of(categoryBudget));

        // Spend before is 0. Spend after is 150. Threshold is 450. No alert.
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                eq(1L), eq(TransactionType.EXPENSE), any(LocalDate.class), any(LocalDate.class)
        )).thenReturn(List.of());

        TransactionDTO result = transactionService.createTransaction(request, user);

        assertNotNull(result);
        assertEquals(100L, result.getId());
        verify(transactionRepository, times(1)).save(any(Transaction.class));
        verify(notificationService, never()).sendPushAlertsToUser(anyLong(), any(), any());
    }

    @Test
    void createTransaction_crossesNearingThreshold_sendsAlert() {
        CreateTransactionRequest request = new CreateTransactionRequest();
        request.setType(TransactionType.EXPENSE);
        request.setCategoryId(10L);
        request.setAmount(new BigDecimal("60.00"));
        request.setTransactionDate(LocalDate.now());
        request.setPaymentMethod(PaymentMethod.CASH);

        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(category));
        when(transactionRepository.save(any(Transaction.class))).thenReturn(transaction);
        
        when(categoryBudgetRepository.findByCategoryIdAndBudgetMonthAndUserIdForUpdate(eq(10L), any(LocalDate.class), eq(1L)))
                .thenReturn(Optional.of(categoryBudget));

        // Spend before is 400. Spend after is 460 (crossed 90% threshold of 450). Sends NEARING push alert.
        Object[] rawSpend = new Object[]{10L, new BigDecimal("400.00")};
        List<Object[]> rawSpendList = List.<Object[]>of(rawSpend);
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                eq(1L), eq(TransactionType.EXPENSE), any(LocalDate.class), any(LocalDate.class)
        )).thenReturn(rawSpendList);

        when(budgetAlertLogRepository.existsByUserIdAndCategoryIdAndBudgetMonthAndThreshold(eq(1L), eq(10L), any(LocalDate.class), eq("NEARING_90")))
                .thenReturn(false);

        transactionService.createTransaction(request, user);

        verify(notificationService, times(1)).sendPushAlertsToUser(
                eq(1L),
                eq("Budget Warning: Nearing Limit"),
                contains("You have spent 460.00 LKR")
        );
    }

    @Test
    void createTransaction_crossesExceededLimit_sendsAlert() {
        CreateTransactionRequest request = new CreateTransactionRequest();
        request.setType(TransactionType.EXPENSE);
        request.setCategoryId(10L);
        request.setAmount(new BigDecimal("50.00"));
        request.setTransactionDate(LocalDate.now());
        request.setPaymentMethod(PaymentMethod.CASH);

        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(category));
        when(transactionRepository.save(any(Transaction.class))).thenReturn(transaction);
        
        when(categoryBudgetRepository.findByCategoryIdAndBudgetMonthAndUserIdForUpdate(eq(10L), any(LocalDate.class), eq(1L)))
                .thenReturn(Optional.of(categoryBudget));

        // Spend before is 460 (already nearing). Spend after is 510 (crossed 100% threshold of 500). Sends EXCEEDED push alert.
        Object[] rawSpend = new Object[]{10L, new BigDecimal("460.00")};
        List<Object[]> rawSpendList = List.<Object[]>of(rawSpend);
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                eq(1L), eq(TransactionType.EXPENSE), any(LocalDate.class), any(LocalDate.class)
        )).thenReturn(rawSpendList);

        when(budgetAlertLogRepository.existsByUserIdAndCategoryIdAndBudgetMonthAndThreshold(eq(1L), eq(10L), any(LocalDate.class), eq("EXCEEDED_100")))
                .thenReturn(false);

        transactionService.createTransaction(request, user);

        verify(notificationService, times(1)).sendPushAlertsToUser(
                eq(1L),
                eq("Budget Alert: Limit Exceeded"),
                contains("Budget limit has been exceeded.")
        );
    }

    @Test
    void createTransaction_typeMismatch_throwsBadRequest() {
        CreateTransactionRequest request = new CreateTransactionRequest();
        request.setType(TransactionType.INCOME);
        request.setCategoryId(10L);
        request.setAmount(new BigDecimal("150.00"));
        request.setTransactionDate(LocalDate.now());
        request.setPaymentMethod(PaymentMethod.CASH);

        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(category));

        assertThrows(BadRequestException.class, () -> transactionService.createTransaction(request, user));
        verify(transactionRepository, never()).save(any(Transaction.class));
    }

    @Test
    void getTransactions_filtered_success() {
        Pageable pageable = PageRequest.of(0, 10);
        Page<Transaction> page = new PageImpl<>(List.of(transaction));

        when(transactionRepository.findAll(any(Specification.class), eq(pageable))).thenReturn(page);

        Page<TransactionDTO> result = transactionService.getTransactions(
                user, TransactionType.EXPENSE, 10L, LocalDate.now(), LocalDate.now(),
                new BigDecimal("100.00"), new BigDecimal("200.00"), "lunch", pageable
        );

        assertNotNull(result);
        assertEquals(1, result.getContent().size());
        verify(transactionRepository, times(1)).findAll(any(Specification.class), eq(pageable));
    }
}
