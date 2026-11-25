package com.manager.money_manager.service;

import com.manager.money_manager.dto.CreateScheduledTransactionRequest;
import com.manager.money_manager.dto.CreateTransactionRequest;
import com.manager.money_manager.dto.ScheduledTransactionDTO;
import com.manager.money_manager.dto.TransactionDTO;
import com.manager.money_manager.exception.BadRequestException;
import com.manager.money_manager.exception.ResourceNotFoundException;
import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.CategoryBudgetRepository;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.ScheduledTransactionRepository;
import com.manager.money_manager.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional
public class ScheduledTransactionService {

    private final ScheduledTransactionRepository scheduledTransactionRepository;
    private final CategoryRepository categoryRepository;
    private final TransactionService transactionService;
    private final TransactionRepository transactionRepository;
    private final CategoryBudgetRepository categoryBudgetRepository;

    public ScheduledTransactionService(ScheduledTransactionRepository scheduledTransactionRepository,
                                       CategoryRepository categoryRepository,
                                       TransactionService transactionService,
                                       TransactionRepository transactionRepository,
                                       CategoryBudgetRepository categoryBudgetRepository) {
        this.scheduledTransactionRepository = scheduledTransactionRepository;
        this.categoryRepository = categoryRepository;
        this.transactionService = transactionService;
        this.transactionRepository = transactionRepository;
        this.categoryBudgetRepository = categoryBudgetRepository;
    }

    public List<ScheduledTransactionDTO> getScheduledTransactions(User user, ScheduledStatus status) {
        List<ScheduledTransaction> list;
        if (status != null) {
            list = scheduledTransactionRepository.findByUserIdAndStatusOrderByDueDateAsc(user.getId(), status);
        } else {
            list = scheduledTransactionRepository.findByUserIdOrderByDueDateAsc(user.getId());
        }
        return list.stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    public ScheduledTransactionDTO createScheduledTransaction(CreateScheduledTransactionRequest request, User user) {
        Category category = categoryRepository.findByIdAndUserId(request.getCategoryId(), user.getId())
                .orElseThrow(() -> new IllegalArgumentException("Category not found or does not belong to user"));

        if (request.getDueDate() == null) {
            throw new BadRequestException("Due date is required");
        }

        TransactionType type = request.getType() != null ? request.getType() : TransactionType.EXPENSE;
        if (type == TransactionType.EXPENSE) {
            validateScheduledAmountMargin(user, request.getDueDate(), request.getAmount(), null);
        }

        ScheduledTransaction st = new ScheduledTransaction();
        st.setUser(user);
        st.setCategory(category);
        st.setType(type);
        st.setTitle(request.getTitle());
        st.setAmount(request.getAmount());
        st.setDueDate(request.getDueDate());
        st.setAnchorDay(request.getDueDate().getDayOfMonth());
        st.setPaymentMethod(request.getPaymentMethod() != null ? request.getPaymentMethod() : PaymentMethod.CASH);
        st.setNote(request.getNote());
        st.setRecurringFrequency(request.getRecurringFrequency() != null ? request.getRecurringFrequency() : ScheduledFrequency.ONCE);
        st.setStatus(ScheduledStatus.PENDING);
        st.setReminderDaysBefore(request.getReminderDaysBefore() != null ? request.getReminderDaysBefore() : 3);

        ScheduledTransaction saved = scheduledTransactionRepository.save(st);
        return mapToDTO(saved);
    }

    public ScheduledTransactionDTO updateScheduledTransaction(Long id, CreateScheduledTransactionRequest request, User user) {
        ScheduledTransaction st = scheduledTransactionRepository.findByIdAndUserId(id, user.getId())
            .orElseThrow(() -> new ResourceNotFoundException("Scheduled transaction not found"));

        Category category = categoryRepository.findByIdAndUserId(request.getCategoryId(), user.getId())
                .orElseThrow(() -> new IllegalArgumentException("Category not found or does not belong to user"));

        TransactionType type = request.getType() != null ? request.getType() : st.getType();
        LocalDate dueDate = request.getDueDate() != null ? request.getDueDate() : st.getDueDate();
        BigDecimal amount = request.getAmount() != null ? request.getAmount() : st.getAmount();

        if (type == TransactionType.EXPENSE) {
            validateScheduledAmountMargin(user, dueDate, amount, id);
        }

        st.setCategory(category);
        st.setType(type);
        st.setTitle(request.getTitle());
        st.setAmount(amount);
        if (request.getDueDate() != null) {
            st.setAnchorDay(request.getDueDate().getDayOfMonth());
        }
        st.setDueDate(dueDate);
        if (request.getPaymentMethod() != null) st.setPaymentMethod(request.getPaymentMethod());
        st.setNote(request.getNote());
        if (request.getRecurringFrequency() != null) st.setRecurringFrequency(request.getRecurringFrequency());
        if (request.getReminderDaysBefore() != null) st.setReminderDaysBefore(request.getReminderDaysBefore());

        ScheduledTransaction saved = scheduledTransactionRepository.save(st);
        return mapToDTO(saved);
    }

    private void validateScheduledAmountMargin(User user, LocalDate dueDate, BigDecimal amount, Long excludeId) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0 || dueDate == null) {
            return;
        }

        YearMonth ym = YearMonth.from(dueDate);
        LocalDate start = ym.atDay(1);
        LocalDate end = ym.atEndOfMonth();

        BigDecimal totalIncome = transactionRepository.sumAmountByUserIdAndTypeAndDateBetween(
                user.getId(), TransactionType.INCOME, start, end
        );

        if (totalIncome != null && totalIncome.compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal monthlyReservedSavings = transactionRepository.sumSavingsAmountByUserIdAndDateBetween(
                    user.getId(), start, end);
            if (monthlyReservedSavings == null) {
                monthlyReservedSavings = BigDecimal.ZERO;
            }

            BigDecimal spendableAllowance = totalIncome.subtract(monthlyReservedSavings);
            if (spendableAllowance.compareTo(BigDecimal.ZERO) < 0) {
                spendableAllowance = BigDecimal.ZERO;
            }
            List<CategoryBudget> categoryBudgets = categoryBudgetRepository.findByUserIdAndBudgetMonth(user.getId(), start);
            BigDecimal totalCategoryBudgets = BigDecimal.ZERO;
            if (categoryBudgets != null) {
                for (CategoryBudget cb : categoryBudgets) {
                    if (cb.getAmountLimit() != null) {
                        totalCategoryBudgets = totalCategoryBudgets.add(cb.getAmountLimit());
                    }
                }
            }

            List<ScheduledTransaction> pendingList = scheduledTransactionRepository
                    .findByUserIdAndStatusOrderByDueDateAsc(user.getId(), ScheduledStatus.PENDING);
            BigDecimal otherScheduledTotal = BigDecimal.ZERO;
            if (pendingList != null) {
                for (ScheduledTransaction pending : pendingList) {
                    if (pending.getType() == TransactionType.EXPENSE
                            && (excludeId == null || !pending.getId().equals(excludeId))
                            && pending.getDueDate() != null
                            && YearMonth.from(pending.getDueDate()).equals(ym)) {
                        otherScheduledTotal = otherScheduledTotal.add(pending.getAmount());
                    }
                }
            }

            BigDecimal availableMargin = spendableAllowance.subtract(totalCategoryBudgets).subtract(otherScheduledTotal);
            if (availableMargin.compareTo(BigDecimal.ZERO) < 0) {
                availableMargin = BigDecimal.ZERO;
            }

            if (amount.compareTo(availableMargin) > 0) {
                throw new BadRequestException(String.format(
                        "Scheduled transaction amount of %.2f LKR exceeds the available spendable allowance of %.2f LKR",
                        amount, availableMargin
                ));
            }
        }
    }

    public void deleteScheduledTransaction(Long id, User user) {
        ScheduledTransaction st = scheduledTransactionRepository.findByIdAndUserId(id, user.getId())
            .orElseThrow(() -> new ResourceNotFoundException("Scheduled transaction not found"));

        scheduledTransactionRepository.delete(st);
    }

    /**
     * Executes payment for a scheduled transaction:
     * 1. Log actual transaction in user's general transaction log.
     * 2. If recurring, advances due date to next cycle; if ONCE, marks as PAID.
     */
    public TransactionDTO payScheduledTransaction(Long id, User user) {
        ScheduledTransaction st = scheduledTransactionRepository.findByIdAndUserId(id, user.getId())
            .orElseThrow(() -> new ResourceNotFoundException("Scheduled transaction not found"));

        if (st.getStatus() != ScheduledStatus.PENDING) {
            throw new BadRequestException("Only pending scheduled payments can be paid");
        }

        // Create actual financial transaction
        CreateTransactionRequest txReq = new CreateTransactionRequest();
        txReq.setCategoryId(st.getCategory().getId());
        txReq.setType(st.getType());
        txReq.setAmount(st.getAmount());
        txReq.setTransactionDate(LocalDate.now());
        txReq.setPaymentMethod(st.getPaymentMethod());
        txReq.setNote(st.getTitle() + (st.getNote() != null && !st.getNote().isBlank() ? " - " + st.getNote() : ""));

        TransactionDTO createdTx = transactionService.createTransaction(txReq, user);

        // Update scheduled transaction status or advance recurring date
        if (st.getRecurringFrequency() == ScheduledFrequency.ONCE) {
            st.setStatus(ScheduledStatus.PAID);
        } else {
            LocalDate nextDueDate = calculateNextDueDate(st.getDueDate(), st.getRecurringFrequency(), st.getAnchorDay());
            st.setDueDate(nextDueDate);
            st.setLastNotifiedAt(null); // Reset reminder status for next cycle
            st.setStatus(ScheduledStatus.PENDING);
        }

        scheduledTransactionRepository.save(st);
        return createdTx;
    }

    private LocalDate calculateNextDueDate(LocalDate currentDueDate, ScheduledFrequency frequency, Integer anchorDay) {
        LocalDate next = switch (frequency) {
            case DAILY -> currentDueDate.plusDays(1);
            case WEEKLY -> currentDueDate.plusWeeks(1);
            case YEARLY -> currentDueDate.plusYears(1);
            default -> currentDueDate.plusMonths(1);
        };
        if (frequency == ScheduledFrequency.DAILY || frequency == ScheduledFrequency.WEEKLY) {
            return next;
        }
        // Month-based schedules re-align to the original day so short months don't shift later cycles.
        int day = anchorDay != null ? anchorDay : currentDueDate.getDayOfMonth();
        return next.withDayOfMonth(Math.min(day, next.lengthOfMonth()));
    }

    public ScheduledTransactionDTO mapToDTO(ScheduledTransaction st) {
        ScheduledTransactionDTO dto = new ScheduledTransactionDTO();
        dto.setId(st.getId());
        dto.setCategoryId(st.getCategory().getId());
        dto.setCategoryName(st.getCategory().getName());
        dto.setType(st.getType());
        dto.setTitle(st.getTitle());
        dto.setAmount(st.getAmount());
        dto.setDueDate(st.getDueDate());
        dto.setPaymentMethod(st.getPaymentMethod());
        dto.setNote(st.getNote());
        dto.setRecurringFrequency(st.getRecurringFrequency());
        dto.setStatus(st.getStatus());
        dto.setReminderDaysBefore(st.getReminderDaysBefore());
        dto.setLastNotifiedAt(st.getLastNotifiedAt());
        dto.setCreatedAt(st.getCreatedAt());
        return dto;
    }
}
