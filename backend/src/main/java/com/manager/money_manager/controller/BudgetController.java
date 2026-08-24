package com.manager.money_manager.controller;

import com.manager.money_manager.dto.BudgetSummaryResponseDTO;
import com.manager.money_manager.dto.CreateBudgetRequest;
import com.manager.money_manager.dto.CategoryBudgetDTO;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.BudgetService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/budgets")
public class BudgetController {

    private final BudgetService budgetService;

    public BudgetController(BudgetService budgetService) {
        this.budgetService = budgetService;
    }

    @GetMapping("/summary")
    public ResponseEntity<BudgetSummaryResponseDTO> getBudgetSummary(
            @RequestAttribute("currentUser") User user,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer month) {
        BudgetSummaryResponseDTO summary = budgetService.getBudgetSummary(user, year, month);
        return ResponseEntity.ok(summary);
    }

    @PostMapping
    public ResponseEntity<CategoryBudgetDTO> setCategoryBudget(
            @Valid @RequestBody CreateBudgetRequest request,
            @RequestAttribute("currentUser") User user) {
        CategoryBudgetDTO dto = budgetService.setCategoryBudget(request, user);
        return new ResponseEntity<>(dto, HttpStatus.CREATED);
    }
}
