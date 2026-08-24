package com.manager.money_manager.controller;

import com.manager.money_manager.dto.CategoryDTO;
import com.manager.money_manager.dto.CreateCategoryRequest;
import com.manager.money_manager.model.TransactionType;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.CategoryService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CategoryControllerTest {

    @Mock
    private CategoryService categoryService;

    @InjectMocks
    private CategoryController categoryController;

    private User user;
    private CategoryDTO categoryDTO;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");

        categoryDTO = new CategoryDTO();
        categoryDTO.setId(10L);
        categoryDTO.setName("Food");
        categoryDTO.setType(TransactionType.EXPENSE);
    }

    @Test
    void getCategories_success() {
        when(categoryService.getCategories(user)).thenReturn(List.of(categoryDTO));

        ResponseEntity<List<CategoryDTO>> response = categoryController.getCategories(user);

        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        assertEquals(1, response.getBody().size());
        assertEquals("Food", response.getBody().get(0).getName());
    }

    @Test
    void getCategory_success() {
        when(categoryService.getCategory(10L, user)).thenReturn(categoryDTO);

        ResponseEntity<CategoryDTO> response = categoryController.getCategory(10L, user);

        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        assertEquals(10L, response.getBody().getId());
    }

    @Test
    void createCategory_success() {
        CreateCategoryRequest request = new CreateCategoryRequest();
        request.setName("Food");
        request.setType(TransactionType.EXPENSE);

        when(categoryService.createCategory(request, user)).thenReturn(categoryDTO);

        ResponseEntity<CategoryDTO> response = categoryController.createCategory(request, user);

        assertNotNull(response);
        assertEquals(201, response.getStatusCode().value());
        assertEquals("Food", response.getBody().getName());
    }

    @Test
    void updateCategory_success() {
        CreateCategoryRequest request = new CreateCategoryRequest();
        request.setName("Dineout");
        request.setType(TransactionType.EXPENSE);

        CategoryDTO updatedDTO = new CategoryDTO();
        updatedDTO.setId(10L);
        updatedDTO.setName("Dineout");
        updatedDTO.setType(TransactionType.EXPENSE);

        when(categoryService.updateCategory(10L, request, user)).thenReturn(updatedDTO);

        ResponseEntity<CategoryDTO> response = categoryController.updateCategory(10L, request, user);

        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        assertEquals("Dineout", response.getBody().getName());
    }

    @Test
    void deleteCategory_success() {
        ResponseEntity<Void> response = categoryController.deleteCategory(10L, user);

        assertNotNull(response);
        assertEquals(204, response.getStatusCode().value());
    }
}
