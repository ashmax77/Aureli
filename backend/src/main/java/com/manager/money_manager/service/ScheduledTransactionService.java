package com.manager.money_manager.service;

import com.manager.money_manager.dto.CreateScheduledTransactionRequest;
import com.manager.money_manager.dto.CreateTransactionRequest;
import com.manager.money_manager.dto.ScheduledTransactionDTO;
import com.manager.money_manager.dto.TransactionDTO;
import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.ScheduledTransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional
public class ScheduledTransactionService {

    private final ScheduledTransactionRepository scheduledTransactionRepository;
    private final CategoryRepository categoryRepository;
    private final TransactionService transactionService;

    public ScheduledTransactionService(ScheduledTransactionRepository scheduledTransactionRepository,
                                       CategoryRepository categoryRepository,
                                       TransactionService transactionService) {
        this.scheduledTransactionRepository = scheduledTransactionRepository;
        this.categoryRepository = categoryRepository;
        this.transactionService = transactionService;
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

        ScheduledTransaction st = new ScheduledTransaction();
        st.setUser(user);
        st.setCategory(category);
        st.setType(request.getType() != null ? request.getType() : TransactionType.EXPENSE);
        st.setTitle(request.getTitle());
        st.setAmount(request.getAmount());
        st.setDueDate(request.getDueDate());
        st.setPaymentMethod(request.getPaymentMethod() != null ? request.getPaymentMethod() : PaymentMethod.CASH);
        st.setNote(request.getNote());
        st.setRecurringFrequency(request.getRecurringFrequency() != null ? request.getRecurringFrequency() : ScheduledFrequency.ONCE);
        st.setStatus(ScheduledStatus.PENDING);
        st.setReminderDaysBefore(request.getReminderDaysBefore() != null ? request.getReminderDaysBefore() : 3);

        ScheduledTransaction saved = scheduledTransactionRepository.save(st);
        return mapToDTO(saved);
    }

    public ScheduledTransactionDTO updateScheduledTransaction(Long id, CreateScheduledTransactionRequest request, User user) {
        ScheduledTransaction st = scheduledTransactionRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Scheduled transaction not found"));

        if (!st.getUser().getId().equals(user.getId())) {
            throw new IllegalArgumentException("Unauthorized access to scheduled transaction");
        }

        Category category = categoryRepository.findByIdAndUserId(request.getCategoryId(), user.getId())
                .orElseThrow(() -> new IllegalArgumentException("Category not found or does not belong to user"));

        st.setCategory(category);
        if (request.getType() != null) st.setType(request.getType());
        st.setTitle(request.getTitle());
        st.setAmount(request.getAmount());
        st.setDueDate(request.getDueDate());
        if (request.getPaymentMethod() != null) st.setPaymentMethod(request.getPaymentMethod());
        st.setNote(request.getNote());
        if (request.getRecurringFrequency() != null) st.setRecurringFrequency(request.getRecurringFrequency());
        if (request.getReminderDaysBefore() != null) st.setReminderDaysBefore(request.getReminderDaysBefore());

        ScheduledTransaction saved = scheduledTransactionRepository.save(st);
        return mapToDTO(saved);
    }

    public void deleteScheduledTransaction(Long id, User user) {
        ScheduledTransaction st = scheduledTransactionRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Scheduled transaction not found"));

        if (!st.getUser().getId().equals(user.getId())) {
            throw new IllegalArgumentException("Unauthorized access to scheduled transaction");
        }

        scheduledTransactionRepository.delete(st);
    }

    /**
     * Executes payment for a scheduled transaction:
     * 1. Log actual transaction in user's general transaction log.
     * 2. If recurring, advances due date to next cycle; if ONCE, marks as PAID.
     */
    public TransactionDTO payScheduledTransaction(Long id, User user) {
        ScheduledTransaction st = scheduledTransactionRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Scheduled transaction not found"));

        if (!st.getUser().getId().equals(user.getId())) {
            throw new IllegalArgumentException("Unauthorized access to scheduled transaction");
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
            LocalDate nextDueDate = calculateNextDueDate(st.getDueDate(), st.getRecurringFrequency());
            st.setDueDate(nextDueDate);
            st.setLastNotifiedAt(null); // Reset reminder status for next cycle
            st.setStatus(ScheduledStatus.PENDING);
        }

        scheduledTransactionRepository.save(st);
        return createdTx;
    }

    private LocalDate calculateNextDueDate(LocalDate currentDueDate, ScheduledFrequency frequency) {
        return switch (frequency) {
            case DAILY -> currentDueDate.plusDays(1);
            case WEEKLY -> currentDueDate.plusWeeks(1);
            case MONTHLY -> currentDueDate.plusMonths(1);
            case YEARLY -> currentDueDate.plusYears(1);
            default -> currentDueDate.plusMonths(1);
        };
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
