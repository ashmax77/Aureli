package com.manager.money_manager.service;

import com.manager.money_manager.dto.CategoryBreakdownDTO;
import com.manager.money_manager.dto.MonthlyTrendDTO;
import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.CategoryRepository;
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
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ChartServiceTest {

    @Mock
    private TransactionRepository transactionRepository;

    @Mock
    private CategoryRepository categoryRepository;

    @InjectMocks
    private ChartService chartService;

    private User user;
    private Category foodCategory;
    private Category transportCategory;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");

        foodCategory = new Category();
        foodCategory.setId(10L);
        foodCategory.setType(TransactionType.EXPENSE);
        foodCategory.setName("Food");
        foodCategory.setColorKey("#E57373");

        transportCategory = new Category();
        transportCategory.setId(11L);
        transportCategory.setType(TransactionType.EXPENSE);
        transportCategory.setName("Transport");
        transportCategory.setColorKey("#64B5F6");
    }

    @Test
    void getMonthlyTrends_success() {
        // Set up mock trends data (Format: month, type, sum)
        String currentMonthStr = LocalDate.now().minusMonths(1).toString().substring(0, 7);
        Object[] incomeRow = new Object[]{currentMonthStr, TransactionType.INCOME, new BigDecimal("1000.00")};
        Object[] expenseRow = new Object[]{currentMonthStr, TransactionType.EXPENSE, new BigDecimal("450.00")};

        List<Object[]> rawTrends = List.<Object[]>of(incomeRow, expenseRow);
        when(transactionRepository.sumAmountMonthlyTrends(eq(1L), any(LocalDate.class))).thenReturn(rawTrends);

        // Fetch last 3 months
        List<MonthlyTrendDTO> result = chartService.getMonthlyTrends(user, 3);

        assertNotNull(result);
        assertEquals(3, result.size());
        
        // Find the matched month
        MonthlyTrendDTO matched = result.stream()
                .filter(t -> t.getMonth().equals(currentMonthStr))
                .findFirst()
                .orElse(null);
        
        assertNotNull(matched);
        assertEquals(new BigDecimal("1000.00"), matched.getTotalIncome());
        assertEquals(new BigDecimal("450.00"), matched.getTotalExpenses());
    }

    @Test
    void getCategoryBreakdown_success() {
        when(categoryRepository.findByUserId(1L)).thenReturn(List.of(foodCategory, transportCategory));

        // Mock sum of expenses grouped by category (Format: categoryId, sum)
        Object[] foodRow = new Object[]{10L, new BigDecimal("300.00")};
        Object[] transportRow = new Object[]{11L, new BigDecimal("100.00")};
        
        List<Object[]> rawBreakdown = List.<Object[]>of(foodRow, transportRow);
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                eq(1L), eq(TransactionType.EXPENSE), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(rawBreakdown);

        List<CategoryBreakdownDTO> result = chartService.getCategoryBreakdown(user, 2026, 8);

        assertNotNull(result);
        assertEquals(2, result.size());

        // Verifies ordering (Food is sorted first because 300 > 100)
        CategoryBreakdownDTO foodResult = result.get(0);
        assertEquals(10L, foodResult.getCategoryId());
        assertEquals("Food", foodResult.getCategoryName());
        assertEquals(new BigDecimal("300.00"), foodResult.getTotalAmount());
        assertEquals(75.0, foodResult.getPercentage());
        assertEquals("#E57373", foodResult.getColorKey());

        CategoryBreakdownDTO transportResult = result.get(1);
        assertEquals(11L, transportResult.getCategoryId());
        assertEquals(25.0, transportResult.getPercentage());
    }

    @Test
    void getCategoryBreakdown_noExpenses_returnsEmptyList() {
        when(transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                eq(1L), eq(TransactionType.EXPENSE), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of());

        List<CategoryBreakdownDTO> result = chartService.getCategoryBreakdown(user, 2026, 8);

        assertNotNull(result);
        assertTrue(result.isEmpty(), "Breakdown should be empty when there are no expenses");
    }
}
