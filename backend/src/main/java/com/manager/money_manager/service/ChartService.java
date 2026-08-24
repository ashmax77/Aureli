package com.manager.money_manager.service;

import com.manager.money_manager.dto.CategoryBreakdownDTO;
import com.manager.money_manager.dto.MonthlyTrendDTO;
import com.manager.money_manager.model.Category;
import com.manager.money_manager.model.TransactionType;
import com.manager.money_manager.model.User;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;
import java.util.stream.Collectors;

@Service
@Transactional(readOnly = true)
public class ChartService {

    private final TransactionRepository transactionRepository;
    private final CategoryRepository categoryRepository;

    public ChartService(TransactionRepository transactionRepository, CategoryRepository categoryRepository) {
        this.transactionRepository = transactionRepository;
        this.categoryRepository = categoryRepository;
    }

    public List<MonthlyTrendDTO> getMonthlyTrends(User user, int limitMonths) {
        LocalDate sinceDate = LocalDate.now().minusMonths(limitMonths - 1).withDayOfMonth(1);
        
        List<Object[]> rawTrends = transactionRepository.sumAmountMonthlyTrends(user.getId(), sinceDate);
        
        // Populate maps to merge INCOME/EXPENSE by month string
        Map<String, BigDecimal> incomeMap = new HashMap<>();
        Map<String, BigDecimal> expenseMap = new HashMap<>();
        
        // Generate list of expected months in chronological order
        List<String> monthKeys = new ArrayList<>();
        for (int i = 0; i < limitMonths; i++) {
            monthKeys.add(YearMonth.from(sinceDate.plusMonths(i)).toString());
        }

        for (Object[] row : rawTrends) {
            String month = (String) row[0];
            TransactionType type = (TransactionType) row[1];
            BigDecimal sum = (BigDecimal) row[2];
            
            if (type == TransactionType.INCOME) {
                incomeMap.put(month, sum);
            } else if (type == TransactionType.EXPENSE) {
                expenseMap.put(month, sum);
            }
        }

        List<MonthlyTrendDTO> trends = new ArrayList<>();
        for (String month : monthKeys) {
            BigDecimal income = incomeMap.getOrDefault(month, BigDecimal.ZERO);
            BigDecimal expense = expenseMap.getOrDefault(month, BigDecimal.ZERO);
            trends.add(new MonthlyTrendDTO(month, income, expense));
        }

        return trends;
    }

    public List<CategoryBreakdownDTO> getCategoryBreakdown(User user, Integer year, Integer month) {
        LocalDate now = LocalDate.now();
        int targetYear = (year != null) ? year : now.getYear();
        int targetMonth = (month != null) ? month : now.getMonthValue();

        YearMonth yearMonth = YearMonth.of(targetYear, targetMonth);
        LocalDate startDate = yearMonth.atDay(1);
        LocalDate endDate = yearMonth.atEndOfMonth();

        // 1. Fetch user categories to fetch matching color keys and names
        Map<Long, Category> categoryMap = categoryRepository.findByUserId(user.getId()).stream()
                .collect(Collectors.toMap(Category::getId, c -> c));

        // 2. Fetch sum of expenses grouped by category
        List<Object[]> categorySpends = transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                user.getId(), TransactionType.EXPENSE, startDate, endDate
        );

        BigDecimal totalExpenses = categorySpends.stream()
                .map(row -> (BigDecimal) row[1])
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        List<CategoryBreakdownDTO> breakdown = new ArrayList<>();
        if (totalExpenses.compareTo(BigDecimal.ZERO) == 0) {
            return breakdown; // No expenses to plot
        }

        for (Object[] row : categorySpends) {
            Long categoryId = (Long) row[0];
            BigDecimal spend = (BigDecimal) row[1];
            Category category = categoryMap.get(categoryId);

            if (category != null) {
                double percentage = spend.multiply(new BigDecimal("100"))
                        .divide(totalExpenses, 2, RoundingMode.HALF_UP)
                        .doubleValue();

                breakdown.add(new CategoryBreakdownDTO(
                        categoryId,
                        category.getName(),
                        spend,
                        percentage,
                        category.getColorKey()
                ));
            }
        }

        // Sort descending by spend amount
        breakdown.sort((a, b) -> b.getTotalAmount().compareTo(a.getTotalAmount()));
        return breakdown;
    }
}
