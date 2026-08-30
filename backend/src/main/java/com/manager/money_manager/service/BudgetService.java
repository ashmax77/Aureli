package com.manager.money_manager.service;

import com.manager.money_manager.dto.BudgetSummaryResponseDTO;
import com.manager.money_manager.dto.CategoryBudgetSummaryDTO;
import com.manager.money_manager.dto.CreateBudgetRequest;
import com.manager.money_manager.dto.CategoryBudgetDTO;
import com.manager.money_manager.exception.BadRequestException;
import com.manager.money_manager.exception.ResourceNotFoundException;
import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.CategoryBudgetRepository;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@Transactional
public class BudgetService {

    private final CategoryRepository categoryRepository;
    private final TransactionRepository transactionRepository;
    private final CategoryBudgetRepository categoryBudgetRepository;

    public BudgetService(CategoryRepository categoryRepository,
                         TransactionRepository transactionRepository,
                         CategoryBudgetRepository categoryBudgetRepository) {
        this.categoryRepository = categoryRepository;
        this.transactionRepository = transactionRepository;
        this.categoryBudgetRepository = categoryBudgetRepository;
    }

    @Transactional(readOnly = true)
    public BudgetSummaryResponseDTO getBudgetSummary(User user, Integer year, Integer month) {
        // Default to current year and month if not provided
        LocalDate now = LocalDate.now();
        int targetYear = (year != null) ? year : now.getYear();
        int targetMonth = (month != null) ? month : now.getMonthValue();

        // Enforce registration date month block
        LocalDateTime registeredAt = user.getCreatedAt();
        if (registeredAt != null) {
            YearMonth regYearMonth = YearMonth.of(registeredAt.getYear(), registeredAt.getMonthValue());
            YearMonth targetYearMonth = YearMonth.of(targetYear, targetMonth);
            if (targetYearMonth.isBefore(regYearMonth)) {
                throw new BadRequestException("Cannot access budget data for months prior to registration date.");
            }
        }

        YearMonth yearMonth = YearMonth.of(targetYear, targetMonth);
        LocalDate startDate = yearMonth.atDay(1);
        LocalDate endDate = yearMonth.atEndOfMonth();

        // 1. Fetch cash flow metrics (total income vs total expenses) for the month
        List<Object[]> typeAggregates = transactionRepository.sumAmountByUserIdAndDateBetweenGroupByType(
                user.getId(), startDate, endDate
        );

        BigDecimal totalIncome = BigDecimal.ZERO;
        BigDecimal totalExpenses = BigDecimal.ZERO;

        for (Object[] row : typeAggregates) {
            TransactionType type = (TransactionType) row[0];
            BigDecimal sum = (BigDecimal) row[1];
            if (type == TransactionType.INCOME) {
                totalIncome = sum;
            } else if (type == TransactionType.EXPENSE) {
                totalExpenses = sum;
            }
        }

        BigDecimal netCashFlow = totalIncome.subtract(totalExpenses);

        // 2. Fetch all EXPENSE categories owned by the user (budgets only apply to expenses)
        List<Category> expenseCategories = categoryRepository.findByUserId(user.getId()).stream()
                .filter(cat -> cat.getType() == TransactionType.EXPENSE && !cat.isArchived())
                .collect(Collectors.toList());

        // 3. Fetch aggregated expense sums grouped by category for the month
        List<Object[]> rawAggregates = transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                user.getId(), TransactionType.EXPENSE, startDate, endDate
        );

        // Map categoryId -> sum(amount)
        Map<Long, BigDecimal> spendMap = rawAggregates.stream()
                .collect(Collectors.toMap(
                        row -> (Long) row[0],
                        row -> (BigDecimal) row[1]
                ));

        // 4. Map expense categories to summary DTOs
        List<CategoryBudgetSummaryDTO> summaries = new ArrayList<>();
        for (Category category : expenseCategories) {
            Optional<CategoryBudget> categoryBudgetOpt = categoryBudgetRepository
                    .findByCategoryIdAndBudgetMonthAndUserId(category.getId(), startDate, user.getId());

            BigDecimal limit = categoryBudgetOpt.map(CategoryBudget::getAmountLimit).orElse(null);
            BigDecimal spend = spendMap.getOrDefault(category.getId(), BigDecimal.ZERO);
            BigDecimal remaining = BigDecimal.ZERO;
            boolean isOver = false;

            if (limit != null) {
                remaining = limit.subtract(spend);
                isOver = spend.compareTo(limit) > 0;
            }

            CategoryBudgetSummaryDTO dto = new CategoryBudgetSummaryDTO();
            dto.setCategoryId(category.getId());
            dto.setCategoryName(category.getName());
            dto.setBudgetLimit(limit);
            dto.setCurrentSpend(spend);
            dto.setRemainingBudget(remaining);
            dto.setOverBudget(isOver);

            BudgetAlertState alertState = BudgetAlertState.NORMAL;
            if (limit != null && limit.compareTo(BigDecimal.ZERO) > 0) {
                BigDecimal threshold = limit.multiply(new BigDecimal("0.90"));
                if (spend.compareTo(limit) > 0) {
                    alertState = BudgetAlertState.EXCEEDED;
                } else if (spend.compareTo(threshold) >= 0) {
                    alertState = BudgetAlertState.NEARING;
                }
            }
            dto.setAlertState(alertState);

            summaries.add(dto);
        }

        BudgetSummaryResponseDTO response = new BudgetSummaryResponseDTO();
        response.setTotalIncome(totalIncome);
        response.setTotalExpenses(totalExpenses);
        response.setNetCashFlow(netCashFlow);
        response.setCategoryBudgets(summaries);

        return response;
    }

    public CategoryBudgetDTO setCategoryBudget(CreateBudgetRequest request, User user) {
        Category category = categoryRepository.findByIdAndUserId(request.getCategoryId(), user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + request.getCategoryId()));

        if (category.getType() != TransactionType.EXPENSE) {
            throw new BadRequestException("Budgets can only be set on expense categories");
        }

        LocalDate normalizedMonth = request.getBudgetMonth().withDayOfMonth(1);

        // Enforce registration date month block
        LocalDateTime registeredAt = user.getCreatedAt();
        if (registeredAt != null) {
            YearMonth regYearMonth = YearMonth.of(registeredAt.getYear(), registeredAt.getMonthValue());
            YearMonth targetYearMonth = YearMonth.from(normalizedMonth);
            if (targetYearMonth.isBefore(regYearMonth)) {
                throw new BadRequestException("Cannot setup budget limits for months prior to registration date.");
            }
        }

        CategoryBudget cb = categoryBudgetRepository
                .findByCategoryIdAndBudgetMonthAndUserId(category.getId(), normalizedMonth, user.getId())
                .orElseGet(() -> {
                    CategoryBudget newCb = new CategoryBudget();
                    newCb.setUser(user);
                    newCb.setCategory(category);
                    newCb.setBudgetMonth(normalizedMonth);
                    return newCb;
                });

        cb.setAmountLimit(request.getAmountLimit());
        CategoryBudget saved = categoryBudgetRepository.save(cb);

        return mapToBudgetDTO(saved);
    }

    private CategoryBudgetDTO mapToBudgetDTO(CategoryBudget cb) {
        CategoryBudgetDTO dto = new CategoryBudgetDTO();
        dto.setId(cb.getId());
        dto.setCategoryId(cb.getCategory().getId());
        dto.setCategoryName(cb.getCategory().getName());
        dto.setBudgetMonth(cb.getBudgetMonth());
        dto.setAmountLimit(cb.getAmountLimit());
        return dto;
    }
}
