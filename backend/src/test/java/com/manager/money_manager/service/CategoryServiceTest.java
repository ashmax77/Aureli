package com.manager.money_manager.service;

import com.manager.money_manager.dto.CategoryDTO;
import com.manager.money_manager.dto.CreateCategoryRequest;
import com.manager.money_manager.exception.BadRequestException;
import com.manager.money_manager.exception.ResourceNotFoundException;
import com.manager.money_manager.model.Category;
import com.manager.money_manager.model.TransactionType;
import com.manager.money_manager.model.User;
import com.manager.money_manager.repository.CategoryRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import java.math.BigDecimal;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CategoryServiceTest {

    @Mock
    private CategoryRepository categoryRepository;

    @InjectMocks
    private CategoryService categoryService;

    private User user;
    private Category category;

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
        category.setBudgetLimit(new BigDecimal("500.00"));
    }

    @Test
    void createCategory_success() {
        CreateCategoryRequest request = new CreateCategoryRequest();
        request.setType(TransactionType.EXPENSE);
        request.setName("Food");
        request.setBudgetLimit(new BigDecimal("500.00"));

        when(categoryRepository.existsByUserIdAndNameIgnoreCaseAndType(1L, "Food", TransactionType.EXPENSE)).thenReturn(false);
        when(categoryRepository.save(any(Category.class))).thenReturn(category);

        CategoryDTO result = categoryService.createCategory(request, user);

        assertNotNull(result);
        assertEquals(10L, result.getId());
        assertEquals("Food", result.getName());
        assertEquals(TransactionType.EXPENSE, result.getType());
        verify(categoryRepository, times(1)).save(any(Category.class));
    }

    @Test
    void createCategory_duplicateName_throwsBadRequest() {
        CreateCategoryRequest request = new CreateCategoryRequest();
        request.setType(TransactionType.EXPENSE);
        request.setName("Food");

        when(categoryRepository.existsByUserIdAndNameIgnoreCaseAndType(1L, "Food", TransactionType.EXPENSE)).thenReturn(true);

        assertThrows(BadRequestException.class, () -> categoryService.createCategory(request, user));
        verify(categoryRepository, never()).save(any(Category.class));
    }

    @Test
    void getCategory_success() {
        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.of(category));

        CategoryDTO result = categoryService.getCategory(10L, user);

        assertNotNull(result);
        assertEquals(10L, result.getId());
    }

    @Test
    void getCategory_notOwnedByUser_throwsResourceNotFound() {
        when(categoryRepository.findByIdAndUserId(10L, 1L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> categoryService.getCategory(10L, user));
    }
}
