package com.manager.money_manager.service;

import com.manager.money_manager.dto.BudgetSummaryResponseDTO;
import com.manager.money_manager.dto.CategoryBudgetSummaryDTO;
import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.BudgetAlertLogRepository;
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
class BudgetServiceTest {

    @Mock
    private CategoryRepository categoryRepository;

    @Mock
    private TransactionRepository transactionRepository;

    @Mock
    private CategoryBudgetRepository categoryBudgetRepository;

    @Mock
    private ScheduledTransactionRepository scheduledTransactionRepository;

    @Mock
    private NotificationService notificationService;

    @Mock
    private BudgetAlertLogRepository budgetAlertLogRepository;

    @InjectMocks
    private BudgetService budgetService;

    private User user;
    private Category foodCategory;
    private Category salaryCategory;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");

        foodCategory = new Category();
        foodCategory.setId(10L);
        foodCategory.setType(TransactionType.EXPENSE);
        foodCategory.setName("Food");
        foodCategory.setUser(user);

        salaryCategory = new Category();
        salaryCategory.setId(11L);
        salaryCategory.setType(TransactionType.INCOME);
        salaryCategory.setName("Salary");
        salaryCategory.setUser(user);
    }

    private CategoryBudget createBudget(Category category, BigDecimal limit) {
        CategoryBudget cb = new CategoryBudget();
        cb.setUser(user);
        cb.setCategory(category);
        cb.setAmountLimit(limit);
        cb.setBudgetMonth(LocalDate.of(2026, 8, 1));
        return cb;
    }

    @Test
    void getBudgetSummary_success_normalAlert() {
        when(categoryRepository.findByUserId(1L)).thenReturn(List.of(foodCategory, salaryCategory));

        Object[] incomeRow = new Object[]{TransactionType.INCOME, new BigDecimal("2000.00")};
        Object[] expenseRow = new Object[]{TransactionType.EXPENSE, new BigDecimal("350.00")};
        List<Object[]> typeList = List.<Object[]>of(incomeRow, expenseRow);
        when(transactionRepository.sumAmountByUserIdAndDateBetweenGroupByType(eq(1L), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(typeList);

        // Spend = 350 (70% of 500 limit) -> NORMAL alert
        Object[] categorySpendRow = new Object[]{10L, new BigDecimal("350.00"), 3L};
        List<Object[]> categoryList = List.<Object[]>of(categorySpendRow);
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                eq(1L), eq(TransactionType.EXPENSE), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(categoryList);

        CategoryBudget foodBudget = createBudget(foodCategory, new BigDecimal("500.00"));
        when(categoryBudgetRepository.findByCategoryIdAndBudgetMonthAndUserId(eq(10L), any(LocalDate.class), eq(1L)))
                .thenReturn(Optional.of(foodBudget));

        BudgetSummaryResponseDTO result = budgetService.getBudgetSummary(user, 2026, 8);

        assertNotNull(result);
        assertEquals(new BigDecimal("2000.00"), result.getTotalIncome());
        assertEquals(new BigDecimal("350.00"), result.getTotalExpenses());
        assertEquals(new BigDecimal("1650.00"), result.getNetCashFlow());

        assertEquals(1, result.getCategoryBudgets().size());
        CategoryBudgetSummaryDTO foodSummary = result.getCategoryBudgets().get(0);
        assertEquals(10L, foodSummary.getCategoryId());
        assertEquals("Food", foodSummary.getCategoryName());
        assertEquals(new BigDecimal("500.00"), foodSummary.getBudgetLimit());
        assertEquals(new BigDecimal("350.00"), foodSummary.getCurrentSpend());
        assertEquals(new BigDecimal("150.00"), foodSummary.getRemainingBudget());
        assertFalse(foodSummary.isOverBudget());
        assertEquals(BudgetAlertState.NORMAL, foodSummary.getAlertState());
    }

    @Test
    void getBudgetSummary_nearingAlert() {
        when(categoryRepository.findByUserId(1L)).thenReturn(List.of(foodCategory));
        when(transactionRepository.sumAmountByUserIdAndDateBetweenGroupByType(eq(1L), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of());

        // Spend = 460 (92% of 500 limit) -> NEARING alert
        Object[] categorySpendRow = new Object[]{10L, new BigDecimal("460.00"), 4L};
        List<Object[]> categoryList = List.<Object[]>of(categorySpendRow);
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                eq(1L), eq(TransactionType.EXPENSE), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(categoryList);

        CategoryBudget foodBudget = createBudget(foodCategory, new BigDecimal("500.00"));
        when(categoryBudgetRepository.findByCategoryIdAndBudgetMonthAndUserId(eq(10L), any(LocalDate.class), eq(1L)))
                .thenReturn(Optional.of(foodBudget));

        BudgetSummaryResponseDTO result = budgetService.getBudgetSummary(user, 2026, 8);

        CategoryBudgetSummaryDTO foodSummary = result.getCategoryBudgets().get(0);
        assertEquals(BudgetAlertState.NEARING, foodSummary.getAlertState());
        assertFalse(foodSummary.isOverBudget());
    }

    @Test
    void getBudgetSummary_exceededAlert() {
        when(categoryRepository.findByUserId(1L)).thenReturn(List.of(foodCategory));
        when(transactionRepository.sumAmountByUserIdAndDateBetweenGroupByType(eq(1L), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of());

        // Spend = 510 (102% of 500 limit) -> EXCEEDED alert
        Object[] categorySpendRow = new Object[]{10L, new BigDecimal("510.00"), 5L};
        List<Object[]> categoryList = List.<Object[]>of(categorySpendRow);
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                eq(1L), eq(TransactionType.EXPENSE), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(categoryList);

        CategoryBudget foodBudget = createBudget(foodCategory, new BigDecimal("500.00"));
        when(categoryBudgetRepository.findByCategoryIdAndBudgetMonthAndUserId(eq(10L), any(LocalDate.class), eq(1L)))
                .thenReturn(Optional.of(foodBudget));

        BudgetSummaryResponseDTO result = budgetService.getBudgetSummary(user, 2026, 8);

        CategoryBudgetSummaryDTO foodSummary = result.getCategoryBudgets().get(0);
        assertEquals(BudgetAlertState.EXCEEDED, foodSummary.getAlertState());
        assertTrue(foodSummary.isOverBudget());
    }

    @Test
    void setCategoryBudget_exceedsUnallocatedMargin_throwsBadRequestException() {
        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(foodCategory));

        user.setSavingsRatePercentage(20.0);
        LocalDate month = LocalDate.of(2026, 8, 1);
        LocalDate start = month.withDayOfMonth(1);
        LocalDate end = month.withDayOfMonth(month.lengthOfMonth());

        // Total income: 10,000 -> 20% savings = 2,000 reserved
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetween(eq(1L), eq(TransactionType.INCOME), eq(start), eq(end)))
                .thenReturn(new BigDecimal("10000.00"));

        // Scheduled payments: 1,000
        when(scheduledTransactionRepository.sumPendingExpensesByUserIdAndDueDateBetween(eq(1L), eq(start), eq(end)))
                .thenReturn(new BigDecimal("1000.00"));
        // Spendable allowance = 10,000 - 2,000 - 1,000 = 7,000

        // Other category budget = 5,000. Available margin = 7,000 - 5,000 = 2,000
        Category otherCategory = new Category();
        otherCategory.setId(99L);
        CategoryBudget otherBudget = createBudget(otherCategory, new BigDecimal("5000.00"));
        when(categoryBudgetRepository.findByUserIdAndBudgetMonth(1L, start))
                .thenReturn(List.of(otherBudget));

        com.manager.money_manager.dto.CreateBudgetRequest req = new com.manager.money_manager.dto.CreateBudgetRequest();
        req.setCategoryId(10L);
        req.setBudgetMonth(month);
        req.setAmountLimit(new BigDecimal("2500.00")); // Exceeds 2,000 available margin!

        assertThrows(com.manager.money_manager.exception.BadRequestException.class, () ->
                budgetService.setCategoryBudget(req, user));
    }

    @Test
    void setCategoryBudget_withinUnallocatedMargin_success() {
        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(foodCategory));

        user.setSavingsRatePercentage(20.0);
        LocalDate month = LocalDate.of(2026, 8, 1);
        LocalDate start = month.withDayOfMonth(1);
        LocalDate end = month.withDayOfMonth(month.lengthOfMonth());

        // Total income: 10,000 -> 20% savings = 2,000 reserved
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetween(eq(1L), eq(TransactionType.INCOME), eq(start), eq(end)))
                .thenReturn(new BigDecimal("10000.00"));

        // Scheduled payments: 1,000 -> spendable = 7,000
        when(scheduledTransactionRepository.sumPendingExpensesByUserIdAndDueDateBetween(eq(1L), eq(start), eq(end)))
                .thenReturn(new BigDecimal("1000.00"));

        // Other category budget = 5,000. Available margin = 2,000
        Category otherCategory = new Category();
        otherCategory.setId(99L);
        CategoryBudget otherBudget = createBudget(otherCategory, new BigDecimal("5000.00"));
        when(categoryBudgetRepository.findByUserIdAndBudgetMonth(1L, start))
                .thenReturn(List.of(otherBudget));

        CategoryBudget existingFoodCb = createBudget(foodCategory, BigDecimal.ZERO);
        when(categoryBudgetRepository.findByCategoryIdAndBudgetMonthAndUserId(10L, start, 1L))
                .thenReturn(Optional.of(existingFoodCb));
        when(categoryBudgetRepository.save(any(CategoryBudget.class))).thenAnswer(i -> i.getArgument(0));

        com.manager.money_manager.dto.CreateBudgetRequest req = new com.manager.money_manager.dto.CreateBudgetRequest();
        req.setCategoryId(10L);
        req.setBudgetMonth(month);
        req.setAmountLimit(new BigDecimal("1800.00")); // Within 2,000 available margin!

        com.manager.money_manager.dto.CategoryBudgetDTO result = budgetService.setCategoryBudget(req, user);
        assertNotNull(result);
        assertEquals(new BigDecimal("1800.00"), result.getAmountLimit());
    }
}
