package com.manager.money_manager.service;

import com.manager.money_manager.dto.CreateTransactionRequest;
import com.manager.money_manager.dto.TransactionDTO;
import com.manager.money_manager.exception.BadRequestException;
import com.manager.money_manager.exception.ResourceNotFoundException;
import com.manager.money_manager.model.Category;
import com.manager.money_manager.model.Transaction;
import com.manager.money_manager.model.TransactionType;
import com.manager.money_manager.model.User;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.TransactionRepository;
import com.manager.money_manager.repository.TransactionSpecifications;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

@Service
@Transactional
public class TransactionService {

    private final TransactionRepository transactionRepository;
    private final CategoryRepository categoryRepository;
    private final NotificationService notificationService;

    public TransactionService(TransactionRepository transactionRepository, CategoryRepository categoryRepository, NotificationService notificationService) {
        this.transactionRepository = transactionRepository;
        this.categoryRepository = categoryRepository;
        this.notificationService = notificationService;
    }

    public TransactionDTO createTransaction(CreateTransactionRequest request, User user) {
        Category category = categoryRepository.findByIdAndUserId(request.getCategoryId(), user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + request.getCategoryId()));

        if (request.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new BadRequestException("Transaction amount must be greater than zero");
        }

        if (category.getType() != request.getType()) {
            throw new BadRequestException("Transaction type must match category type");
        }

        // Compute budget alert check before saving
        if (category.getType() == TransactionType.EXPENSE) {
            checkAndTriggerBudgetAlertForCreate(user, category, request.getAmount(), request.getTransactionDate());
        }

        Transaction transaction = new Transaction();
        transaction.setUser(user);
        transaction.setCategory(category);
        transaction.setType(request.getType());
        transaction.setAmount(request.getAmount());
        transaction.setTransactionDate(request.getTransactionDate());
        transaction.setNote(request.getNote());
        transaction.setPaymentMethod(request.getPaymentMethod());

        Transaction saved = transactionRepository.save(transaction);
        return mapToDTO(saved);
    }

    @Transactional(readOnly = true)
    public Page<TransactionDTO> getTransactions(User user, TransactionType type, Long categoryId,
                                                LocalDate startDate, LocalDate endDate,
                                                BigDecimal minAmount, BigDecimal maxAmount,
                                                String search, Pageable pageable) {
        Specification<Transaction> spec = buildSpecification(user, type, categoryId, startDate, endDate, minAmount, maxAmount, search);
        return transactionRepository.findAll(spec, pageable)
                .map(this::mapToDTO);
    }

    @Transactional(readOnly = true)
    public List<Transaction> getRawTransactionsList(User user, TransactionType type, Long categoryId,
                                                    LocalDate startDate, LocalDate endDate,
                                                    BigDecimal minAmount, BigDecimal maxAmount,
                                                    String search) {
        Specification<Transaction> spec = buildSpecification(user, type, categoryId, startDate, endDate, minAmount, maxAmount, search);
        return transactionRepository.findAll(spec);
    }

    private Specification<Transaction> buildSpecification(User user, TransactionType type, Long categoryId,
                                                           LocalDate startDate, LocalDate endDate,
                                                           BigDecimal minAmount, BigDecimal maxAmount,
                                                           String search) {
        return Specification.where(TransactionSpecifications.hasUserId(user.getId()))
                .and(TransactionSpecifications.hasType(type))
                .and(TransactionSpecifications.hasCategoryId(categoryId))
                .and(TransactionSpecifications.dateBetween(startDate, endDate))
                .and(TransactionSpecifications.amountBetween(minAmount, maxAmount))
                .and(TransactionSpecifications.noteContains(search));
    }

    @Transactional(readOnly = true)
    public TransactionDTO getTransaction(Long id, User user) {
        Transaction transaction = transactionRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found with id: " + id));
        return mapToDTO(transaction);
    }

    public TransactionDTO updateTransaction(Long id, CreateTransactionRequest request, User user) {
        Transaction transaction = transactionRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found with id: " + id));

        Category category = categoryRepository.findByIdAndUserId(request.getCategoryId(), user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + request.getCategoryId()));

        if (request.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new BadRequestException("Transaction amount must be greater than zero");
        }

        if (category.getType() != request.getType()) {
            throw new BadRequestException("Transaction type must match category type");
        }

        // Compute budget alert check before updating
        if (category.getType() == TransactionType.EXPENSE) {
            checkAndTriggerBudgetAlertForUpdate(user, category, transaction, request.getAmount(), request.getTransactionDate());
        }

        transaction.setCategory(category);
        transaction.setType(request.getType());
        transaction.setAmount(request.getAmount());
        transaction.setTransactionDate(request.getTransactionDate());
        transaction.setNote(request.getNote());
        transaction.setPaymentMethod(request.getPaymentMethod());

        Transaction updated = transactionRepository.save(transaction);
        return mapToDTO(updated);
    }

    public void deleteTransaction(Long id, User user) {
        Transaction transaction = transactionRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found with id: " + id));
        transactionRepository.delete(transaction);
    }

    private void checkAndTriggerBudgetAlertForCreate(User user, Category category, BigDecimal amountAdded, LocalDate date) {
        BigDecimal limit = category.getBudgetLimit();
        if (limit == null || limit.compareTo(BigDecimal.ZERO) <= 0) {
            return;
        }

        BigDecimal spendBefore = fetchCategorySpendForMonth(user.getId(), category.getId(), date);
        evaluateAndTrigger(user, category, spendBefore, spendBefore.add(amountAdded), limit);
    }

    private void checkAndTriggerBudgetAlertForUpdate(User user, Category category, Transaction oldTx, BigDecimal newAmount, LocalDate newDate) {
        BigDecimal limit = category.getBudgetLimit();
        if (limit == null || limit.compareTo(BigDecimal.ZERO) <= 0) {
            return;
        }

        BigDecimal spendBefore = fetchCategorySpendForMonth(user.getId(), category.getId(), newDate);
        
        // If the updated transaction was already in the same category and month, we must exclude its old amount to find true spendBefore
        if (oldTx.getCategory().getId().equals(category.getId()) && YearMonth.from(oldTx.getTransactionDate()).equals(YearMonth.from(newDate))) {
            spendBefore = spendBefore.subtract(oldTx.getAmount());
            if (spendBefore.compareTo(BigDecimal.ZERO) < 0) {
                spendBefore = BigDecimal.ZERO;
            }
        }

        evaluateAndTrigger(user, category, spendBefore, spendBefore.add(newAmount), limit);
    }

    private BigDecimal fetchCategorySpendForMonth(Long userId, Long categoryId, LocalDate date) {
        YearMonth yearMonth = YearMonth.from(date);
        LocalDate start = yearMonth.atDay(1);
        LocalDate end = yearMonth.atEndOfMonth();

        List<Object[]> rawAggregates = transactionRepository.sumAmountByUserIdAndTypeAndDateBetweenGroupByCategoryId(
                userId, TransactionType.EXPENSE, start, end
        );

        return rawAggregates.stream()
                .filter(row -> row[0].equals(categoryId))
                .map(row -> (BigDecimal) row[1])
                .findFirst()
                .orElse(BigDecimal.ZERO);
    }

    private void evaluateAndTrigger(User user, Category category, BigDecimal spendBefore, BigDecimal spendAfter, BigDecimal limit) {
        BigDecimal threshold = limit.multiply(new BigDecimal("0.90"));

        if (spendBefore.compareTo(threshold) < 0 && spendAfter.compareTo(threshold) >= 0 && spendAfter.compareTo(limit) <= 0) {
            notificationService.sendPushNotification(
                    user.getFcmToken(),
                    "Budget Warning: Nearing Limit",
                    String.format("You have spent %.2f LKR of your %.2f LKR limit on %s.", spendAfter, limit, category.getName())
            );
        } else if (spendBefore.compareTo(limit) <= 0 && spendAfter.compareTo(limit) > 0) {
            notificationService.sendPushNotification(
                    user.getFcmToken(),
                    "Budget Alert: Limit Exceeded",
                    String.format("You have spent %.2f LKR of your %.2f LKR limit on %s. Budget limit has been exceeded.", spendAfter, limit, category.getName())
            );
        }
    }

    private TransactionDTO mapToDTO(Transaction transaction) {
        TransactionDTO dto = new TransactionDTO();
        dto.setId(transaction.getId());
        dto.setType(transaction.getType());
        dto.setAmount(transaction.getAmount());
        dto.setTransactionDate(transaction.getTransactionDate());
        dto.setNote(transaction.getNote());
        dto.setPaymentMethod(transaction.getPaymentMethod());
        dto.setCategoryId(transaction.getCategory().getId());
        dto.setCategoryName(transaction.getCategory().getName());
        dto.setCreatedAt(transaction.getCreatedAt());
        dto.setUpdatedAt(transaction.getUpdatedAt());
        return dto;
    }
}
