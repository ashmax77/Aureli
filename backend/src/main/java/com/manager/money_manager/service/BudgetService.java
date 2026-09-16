package com.manager.money_manager.service;

import com.manager.money_manager.dto.BudgetSummaryResponseDTO;
import com.manager.money_manager.dto.CategoryBudgetSummaryDTO;
import com.manager.money_manager.dto.CreateBudgetRequest;
import com.manager.money_manager.dto.CategoryBudgetDTO;
import com.manager.money_manager.exception.BadRequestException;
import com.manager.money_manager.exception.ResourceNotFoundException;
import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.BudgetAlertLogRepository;
import com.manager.money_manager.repository.CategoryBudgetRepository;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.ScheduledTransactionRepository;
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
    private final ScheduledTransactionRepository scheduledTransactionRepository;
    private final NotificationService notificationService;
    private final BudgetAlertLogRepository budgetAlertLogRepository;

    public BudgetService(CategoryRepository categoryRepository,
                         TransactionRepository transactionRepository,
                         CategoryBudgetRepository categoryBudgetRepository,
                         ScheduledTransactionRepository scheduledTransactionRepository,
                         NotificationService notificationService,
                         BudgetAlertLogRepository budgetAlertLogRepository) {
        this.categoryRepository = categoryRepository;
        this.transactionRepository = transactionRepository;
        this.categoryBudgetRepository = categoryBudgetRepository;
        this.scheduledTransactionRepository = scheduledTransactionRepository;
        this.notificationService = notificationService;
        this.budgetAlertLogRepository = budgetAlertLogRepository;
    }

    /**
     * Note for Future Releases:
     * Currently, the valid transaction time duration for a month is strictly bounded from the 1st day 
     * to the last day of a given calendar month. 
     * In future releases with direct bank account synchronization, this logic will be upgraded to support 
     * custom financial month start dates (e.g. user salary payday).
     */
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

        // Map categoryId -> count(id)
        Map<Long, Long> countMap = rawAggregates.stream()
                .collect(Collectors.toMap(
                        row -> (Long) row[0],
                        row -> row.length > 2 ? (Long) row[2] : 0L
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
            dto.setTransactionCount(countMap.getOrDefault(category.getId(), 0L));

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

        // 5. Fetch previous month's expenses
        YearMonth prevYearMonth = yearMonth.minusMonths(1);
        LocalDate prevStartDate = prevYearMonth.atDay(1);
        LocalDate prevEndDate = prevYearMonth.atEndOfMonth();

        List<Object[]> prevTypeAggregates = transactionRepository.sumAmountByUserIdAndDateBetweenGroupByType(
                user.getId(), prevStartDate, prevEndDate
        );

        BigDecimal previousMonthExpenses = BigDecimal.ZERO;
        for (Object[] row : prevTypeAggregates) {
            TransactionType type = (TransactionType) row[0];
            BigDecimal sum = (BigDecimal) row[1];
            if (type == TransactionType.EXPENSE) {
                previousMonthExpenses = sum;
            }
        }

        // 6. Compute Savings Vault & Spendable Allowance metrics
        Double savingsRate = user.getSavingsRatePercentage() != null ? user.getSavingsRatePercentage() : 20.0;
        BigDecimal rateMultiplier = BigDecimal.valueOf(savingsRate).divide(BigDecimal.valueOf(100), 4, java.math.RoundingMode.HALF_UP);

        // Monthly reserved savings: totalIncome * (savingsRate / 100)
        BigDecimal monthlyReservedSavings = totalIncome.multiply(rateMultiplier).setScale(2, java.math.RoundingMode.HALF_UP);

        // Cumulative savings: All historical income up to endDate * (savingsRate / 100)
        BigDecimal totalHistoricalIncome = transactionRepository.sumTotalIncomeByUserIdUpToDate(user.getId(), endDate);
        if (totalHistoricalIncome == null) {
            totalHistoricalIncome = BigDecimal.ZERO;
        }
        BigDecimal cumulativeSavings = totalHistoricalIncome.multiply(rateMultiplier).setScale(2, java.math.RoundingMode.HALF_UP);

        // Scheduled recurring payments for this month
        BigDecimal scheduledPaymentsTotal = scheduledTransactionRepository.sumPendingExpensesByUserIdAndDueDateBetween(user.getId(), startDate, endDate);
        if (scheduledPaymentsTotal == null) {
            scheduledPaymentsTotal = BigDecimal.ZERO;
        }

        // Spendable allowance: max(0, totalIncome - monthlyReservedSavings - scheduledPaymentsTotal)
        BigDecimal spendableAllowance = totalIncome.subtract(monthlyReservedSavings).subtract(scheduledPaymentsTotal);
        if (spendableAllowance.compareTo(BigDecimal.ZERO) < 0) {
            spendableAllowance = BigDecimal.ZERO;
        }

        // Total allocated category budgets for this month
        BigDecimal totalAllocatedCategoryBudgets = BigDecimal.ZERO;
        for (CategoryBudgetSummaryDTO catSummary : summaries) {
            if (catSummary.getBudgetLimit() != null) {
                totalAllocatedCategoryBudgets = totalAllocatedCategoryBudgets.add(catSummary.getBudgetLimit());
            }
        }

        // Unallocated allowance
        BigDecimal unallocatedAllowance = spendableAllowance.subtract(totalAllocatedCategoryBudgets);
        if (unallocatedAllowance.compareTo(BigDecimal.ZERO) < 0) {
            unallocatedAllowance = BigDecimal.ZERO;
        }

        // 7. Compute Payment Method breakdowns (CARD & BANK_TRANSFER)
        BigDecimal cardExpenses = BigDecimal.ZERO;
        BigDecimal bankTransferExpenses = BigDecimal.ZERO;
        List<Object[]> paymentMethodAggregates = transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByPaymentMethod(
                user.getId(), TransactionType.EXPENSE, startDate, endDate
        );
        if (paymentMethodAggregates != null) {
            for (Object[] row : paymentMethodAggregates) {
                PaymentMethod method = (PaymentMethod) row[0];
                BigDecimal sum = (BigDecimal) row[1];
                if (method == PaymentMethod.CARD) {
                    cardExpenses = sum;
                } else if (method == PaymentMethod.BANK_TRANSFER) {
                    bankTransferExpenses = sum;
                }
            }
        }

        BudgetSummaryResponseDTO response = new BudgetSummaryResponseDTO();
        response.setTotalIncome(totalIncome);
        response.setTotalExpenses(totalExpenses);
        response.setNetCashFlow(netCashFlow);
        response.setPreviousMonthExpenses(previousMonthExpenses);
        response.setCategoryBudgets(summaries);

        response.setSavingsRatePercentage(savingsRate);
        response.setMonthlyReservedSavings(monthlyReservedSavings);
        response.setCumulativeSavings(cumulativeSavings);
        response.setScheduledPaymentsTotal(scheduledPaymentsTotal);
        response.setSpendableAllowance(spendableAllowance);
        response.setTotalAllocatedCategoryBudgets(totalAllocatedCategoryBudgets);
        response.setUnallocatedAllowance(unallocatedAllowance);

        response.setCardExpenses(cardExpenses);
        response.setBankTransferExpenses(bankTransferExpenses);

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

        // Check if existing spend in this category already reaches or exceeds 90%/100% of the new budget limit
        evaluateAndTriggerForBudgetUpdate(user, category, normalizedMonth, request.getAmountLimit());

        return mapToBudgetDTO(saved);
    }

    private void evaluateAndTriggerForBudgetUpdate(User user, Category category, LocalDate normalizedMonth, BigDecimal limit) {
        if (limit == null || limit.compareTo(BigDecimal.ZERO) <= 0) {
            return;
        }

        YearMonth ym = YearMonth.from(normalizedMonth);
        List<Object[]> aggregates = transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                user.getId(), TransactionType.EXPENSE, ym.atDay(1), ym.atEndOfMonth()
        );

        BigDecimal currentSpend = aggregates.stream()
                .filter(row -> row[0].equals(category.getId()))
                .map(row -> (BigDecimal) row[1])
                .findFirst()
                .orElse(BigDecimal.ZERO);

        if (currentSpend.compareTo(BigDecimal.ZERO) <= 0) {
            return;
        }

        BigDecimal threshold = limit.multiply(new BigDecimal("0.90"));

        if (currentSpend.compareTo(limit) > 0) {
            triggerAlert(user, category, normalizedMonth, "EXCEEDED_100",
                    "Budget Alert: Limit Exceeded",
                    String.format("You have spent %.2f LKR of your %.2f LKR limit on %s. Budget limit has been exceeded.", currentSpend, limit, category.getName()));
        } else if (currentSpend.compareTo(threshold) >= 0) {
            triggerAlert(user, category, normalizedMonth, "NEARING_90",
                    "Budget Warning: Nearing Limit",
                    String.format("You have spent %.2f LKR of your %.2f LKR limit on %s.", currentSpend, limit, category.getName()));
        }
    }

    private void triggerAlert(User user, Category category, LocalDate normalizedMonth, String threshold, String title, String body) {
        boolean alreadyAlerted = budgetAlertLogRepository
                .existsByUserIdAndCategoryIdAndBudgetMonthAndThreshold(user.getId(), category.getId(), normalizedMonth, threshold);

        if (!alreadyAlerted) {
            BudgetAlertLog alertLog = new BudgetAlertLog();
            alertLog.setUser(user);
            alertLog.setCategory(category);
            alertLog.setBudgetMonth(normalizedMonth);
            alertLog.setThreshold(threshold);
            budgetAlertLogRepository.save(alertLog);

            notificationService.sendPushAlertsToUser(user.getId(), title, body);
        }
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
