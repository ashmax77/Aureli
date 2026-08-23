package com.manager.money_manager.service;

import com.manager.money_manager.dto.CreateExpenseRequest;
import com.manager.money_manager.dto.ExpenseDTO;
import com.manager.money_manager.exception.ResourceNotFoundException;
import com.manager.money_manager.model.Category;
import com.manager.money_manager.model.Expense;
import com.manager.money_manager.model.User;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.ExpenseRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ExpenseServiceTest {

    @Mock
    private ExpenseRepository expenseRepository;

    @Mock
    private CategoryRepository categoryRepository;

    @InjectMocks
    private ExpenseService expenseService;

    private User user;
    private Category category;
    private Expense expense;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");

        category = new Category();
        category.setId(10L);
        category.setName("Food");
        category.setUser(user);

        expense = new Expense();
        expense.setId(100L);
        expense.setUser(user);
        expense.setCategory(category);
        expense.setAmount(new BigDecimal("150.00"));
        expense.setDate(LocalDate.now());
    }

    @Test
    void createExpense_success() {
        CreateExpenseRequest request = new CreateExpenseRequest();
        request.setCategoryId(10L);
        request.setAmount(new BigDecimal("150.00"));
        request.setDate(LocalDate.now());

        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(category));
        when(expenseRepository.save(any(Expense.class))).thenReturn(expense);

        ExpenseDTO result = expenseService.createExpense(request, user);

        assertNotNull(result);
        assertEquals(100L, result.getId());
        assertEquals("Food", result.getCategoryName());
        verify(expenseRepository, times(1)).save(any(Expense.class));
    }

    @Test
    void createExpense_categoryNotFound_throwsException() {
        CreateExpenseRequest request = new CreateExpenseRequest();
        request.setCategoryId(99L); // different category
        request.setAmount(new BigDecimal("150.00"));
        request.setDate(LocalDate.now());

        when(categoryRepository.findByIdAndUserId(99L, 1L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> expenseService.createExpense(request, user));
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    @Test
    void getExpense_success() {
        when(expenseRepository.findByIdAndUserId(100L, 1L)).thenReturn(Optional.of(expense));

        ExpenseDTO result = expenseService.getExpense(100L, user);

        assertNotNull(result);
        assertEquals(100L, result.getId());
    }

    @Test
    void getExpense_notOwnedByUser_throwsResourceNotFound() {
        when(expenseRepository.findByIdAndUserId(100L, 1L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> expenseService.getExpense(100L, user));
    }

    @Test
    void deleteExpense_success() {
        when(expenseRepository.findByIdAndUserId(100L, 1L)).thenReturn(Optional.of(expense));

        expenseService.deleteExpense(100L, user);

        verify(expenseRepository, times(1)).delete(expense);
    }

    @Test
    void deleteExpense_notOwnedByUser_throwsResourceNotFound() {
        when(expenseRepository.findByIdAndUserId(100L, 1L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> expenseService.deleteExpense(100L, user));
        verify(expenseRepository, never()).delete(any(Expense.class));
    }
}
