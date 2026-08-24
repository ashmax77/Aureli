package com.manager.money_manager.controller;

import com.manager.money_manager.dto.BudgetSummaryResponseDTO;
import com.manager.money_manager.dto.CategoryBudgetDTO;
import com.manager.money_manager.dto.CreateBudgetRequest;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.BudgetService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import java.math.BigDecimal;
import java.time.LocalDate;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BudgetControllerTest {

    @Mock
    private BudgetService budgetService;

    @InjectMocks
    private BudgetController budgetController;

    private User user;
    private BudgetSummaryResponseDTO summaryResponseDTO;
    private CategoryBudgetDTO categoryBudgetDTO;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");

        summaryResponseDTO = new BudgetSummaryResponseDTO();
        summaryResponseDTO.setTotalIncome(new BigDecimal("1000.00"));
        summaryResponseDTO.setTotalExpenses(new BigDecimal("300.00"));
        summaryResponseDTO.setNetCashFlow(new BigDecimal("700.00"));

        categoryBudgetDTO = new CategoryBudgetDTO();
        categoryBudgetDTO.setId(20L);
        categoryBudgetDTO.setCategoryId(10L);
        categoryBudgetDTO.setCategoryName("Food");
        categoryBudgetDTO.setBudgetMonth(LocalDate.of(2026, 8, 1));
        categoryBudgetDTO.setAmountLimit(new BigDecimal("500.00"));
    }

    @Test
    void getBudgetSummary_success() {
        when(budgetService.getBudgetSummary(user, 2026, 8)).thenReturn(summaryResponseDTO);

        ResponseEntity<BudgetSummaryResponseDTO> response = budgetController.getBudgetSummary(user, 2026, 8);

        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        assertEquals(new BigDecimal("700.00"), response.getBody().getNetCashFlow());
    }

    @Test
    void setCategoryBudget_success() {
        CreateBudgetRequest request = new CreateBudgetRequest();
        request.setCategoryId(10L);
        request.setBudgetMonth(LocalDate.of(2026, 8, 1));
        request.setAmountLimit(new BigDecimal("500.00"));

        when(budgetService.setCategoryBudget(request, user)).thenReturn(categoryBudgetDTO);

        ResponseEntity<CategoryBudgetDTO> response = budgetController.setCategoryBudget(request, user);

        assertNotNull(response);
        assertEquals(201, response.getStatusCode().value());
        assertEquals(new BigDecimal("500.00"), response.getBody().getAmountLimit());
    }
}
