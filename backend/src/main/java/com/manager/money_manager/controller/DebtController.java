package com.manager.money_manager.controller;

import com.manager.money_manager.dto.*;
import com.manager.money_manager.model.DebtStatus;
import com.manager.money_manager.model.DebtType;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.DebtService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/debts")
public class DebtController {

    private final DebtService debtService;

    public DebtController(DebtService debtService) {
        this.debtService = debtService;
    }

    @GetMapping("/summary")
    public ResponseEntity<DebtSummaryDTO> getSummary(@RequestAttribute("currentUser") User currentUser) {
        return ResponseEntity.ok(debtService.getSummary(currentUser));
    }

    @GetMapping
    public ResponseEntity<List<DebtRecordDTO>> getAllDebts(
            @RequestParam(required = false) DebtType type,
            @RequestParam(required = false) DebtStatus status,
            @RequestAttribute("currentUser") User currentUser) {
        return ResponseEntity.ok(debtService.getAllDebts(currentUser, type, status));
    }

    @GetMapping("/{id}")
    public ResponseEntity<DebtRecordDTO> getDebtById(
            @PathVariable Long id,
            @RequestAttribute("currentUser") User currentUser) {
        return ResponseEntity.ok(debtService.getDebtById(id, currentUser));
    }

    @PostMapping
    public ResponseEntity<DebtRecordDTO> createDebt(
            @Valid @RequestBody CreateDebtRequest request,
            @RequestAttribute("currentUser") User currentUser) {
        DebtRecordDTO created = debtService.createDebt(request, currentUser);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @PutMapping("/{id}")
    public ResponseEntity<DebtRecordDTO> updateDebt(
            @PathVariable Long id,
            @RequestBody UpdateDebtRequest request,
            @RequestAttribute("currentUser") User currentUser) {
        return ResponseEntity.ok(debtService.updateDebt(id, request, currentUser));
    }

    @PostMapping("/{id}/repayments")
    public ResponseEntity<DebtRecordDTO> recordRepayment(
            @PathVariable Long id,
            @Valid @RequestBody CreateDebtRepaymentRequest request,
            @RequestAttribute("currentUser") User currentUser) {
        return ResponseEntity.ok(debtService.recordRepayment(id, request, currentUser));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteDebt(
            @PathVariable Long id,
            @RequestAttribute("currentUser") User currentUser) {
        debtService.deleteDebt(id, currentUser);
        return ResponseEntity.noContent().build();
    }
}
