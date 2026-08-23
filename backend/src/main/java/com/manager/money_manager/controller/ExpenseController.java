package com.manager.money_manager.controller;

import com.manager.money_manager.dto.CreateExpenseRequest;
import com.manager.money_manager.dto.ExpenseDTO;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.ExpenseService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/expenses")
public class ExpenseController {

    private final ExpenseService expenseService;

    public ExpenseController(ExpenseService expenseService) {
        this.expenseService = expenseService;
    }

    @PostMapping
    public ResponseEntity<ExpenseDTO> createExpense(
            @Valid @RequestBody CreateExpenseRequest request,
            @RequestAttribute("currentUser") User user) {
        ExpenseDTO created = expenseService.createExpense(request, user);
        return new ResponseEntity<>(created, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<Page<ExpenseDTO>> getExpenses(
            @RequestAttribute("currentUser") User user,
            @PageableDefault(size = 10, sort = "date", direction = Sort.Direction.DESC) Pageable pageable) {
        Page<ExpenseDTO> expenses = expenseService.getExpenses(user, pageable);
        return ResponseEntity.ok(expenses);
    }

    @GetMapping("/{id}")
    public ResponseEntity<ExpenseDTO> getExpense(
            @PathVariable Long id,
            @RequestAttribute("currentUser") User user) {
        ExpenseDTO expense = expenseService.getExpense(id, user);
        return ResponseEntity.ok(expense);
    }

    @PutMapping("/{id}")
    public ResponseEntity<ExpenseDTO> updateExpense(
            @PathVariable Long id,
            @Valid @RequestBody CreateExpenseRequest request,
            @RequestAttribute("currentUser") User user) {
        ExpenseDTO updated = expenseService.updateExpense(id, request, user);
        return ResponseEntity.ok(updated);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteExpense(
            @PathVariable Long id,
            @RequestAttribute("currentUser") User user) {
        expenseService.deleteExpense(id, user);
        return ResponseEntity.noContent().build();
    }
}
