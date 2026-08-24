package com.manager.money_manager.service;

import com.manager.money_manager.dto.CreateTransactionRequest;
import com.manager.money_manager.dto.TransactionDTO;
import com.manager.money_manager.exception.BadRequestException;
import com.manager.money_manager.exception.ResourceNotFoundException;
import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.TransactionRepository;
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

    @InjectMocks
    private TransactionService transactionService;

    private User user;
    private Category category;
    private Transaction transaction;

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
    void createTransaction_success() {
        CreateTransactionRequest request = new CreateTransactionRequest();
        request.setType(TransactionType.EXPENSE);
        request.setCategoryId(10L);
        request.setAmount(new BigDecimal("150.00"));
        request.setTransactionDate(LocalDate.now());
        request.setPaymentMethod(PaymentMethod.CASH);

        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(category));
        when(transactionRepository.save(any(Transaction.class))).thenReturn(transaction);

        TransactionDTO result = transactionService.createTransaction(request, user);

        assertNotNull(result);
        assertEquals(100L, result.getId());
        assertEquals("Food", result.getCategoryName());
        verify(transactionRepository, times(1)).save(any(Transaction.class));
    }

    @Test
    void createTransaction_typeMismatch_throwsBadRequest() {
        CreateTransactionRequest request = new CreateTransactionRequest();
        request.setType(TransactionType.INCOME); // Mismatch: INCOME transaction under EXPENSE category
        request.setCategoryId(10L);
        request.setAmount(new BigDecimal("150.00"));
        request.setTransactionDate(LocalDate.now());
        request.setPaymentMethod(PaymentMethod.CASH);

        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(category));

        assertThrows(BadRequestException.class, () -> transactionService.createTransaction(request, user));
        verify(transactionRepository, never()).save(any(Transaction.class));
    }

    @Test
    void createTransaction_zeroAmount_throwsBadRequest() {
        CreateTransactionRequest request = new CreateTransactionRequest();
        request.setType(TransactionType.EXPENSE);
        request.setCategoryId(10L);
        request.setAmount(BigDecimal.ZERO); // Mismatch: zero amount
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
        assertEquals(100L, result.getContent().get(0).getId());
        verify(transactionRepository, times(1)).findAll(any(Specification.class), eq(pageable));
    }

    @Test
    void getRawTransactionsList_success() {
        when(transactionRepository.findAll(any(Specification.class))).thenReturn(List.of(transaction));

        List<Transaction> result = transactionService.getRawTransactionsList(
                user, TransactionType.EXPENSE, 10L, null, null, null, null, null
        );

        assertNotNull(result);
        assertEquals(1, result.size());
        assertEquals(100L, result.get(0).getId());
        verify(transactionRepository, times(1)).findAll(any(Specification.class));
    }

    @Test
    void getTransaction_success() {
        when(transactionRepository.findByIdAndUserId(100L, 1L)).thenReturn(Optional.of(transaction));

        TransactionDTO result = transactionService.getTransaction(100L, user);

        assertNotNull(result);
        assertEquals(100L, result.getId());
    }

    @Test
    void getTransaction_notOwnedByUser_throwsResourceNotFound() {
        when(transactionRepository.findByIdAndUserId(100L, 1L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> transactionService.getTransaction(100L, user));
    }
}
