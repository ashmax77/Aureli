package com.manager.money_manager.controller;

import com.manager.money_manager.dto.CreateScheduledTransactionRequest;
import com.manager.money_manager.dto.ScheduledTransactionDTO;
import com.manager.money_manager.dto.TransactionDTO;
import com.manager.money_manager.model.ScheduledStatus;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.ScheduledTransactionService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/scheduled-transactions")
public class ScheduledTransactionController {

    private final ScheduledTransactionService scheduledTransactionService;

    public ScheduledTransactionController(ScheduledTransactionService scheduledTransactionService) {
        this.scheduledTransactionService = scheduledTransactionService;
    }

    @GetMapping
    public ResponseEntity<List<ScheduledTransactionDTO>> getScheduledTransactions(
            @RequestAttribute("currentUser") User user,
            @RequestParam(required = false) ScheduledStatus status) {
        List<ScheduledTransactionDTO> list = scheduledTransactionService.getScheduledTransactions(user, status);
        return ResponseEntity.ok(list);
    }

    @PostMapping
    public ResponseEntity<ScheduledTransactionDTO> createScheduledTransaction(
            @Valid @RequestBody CreateScheduledTransactionRequest request,
            @RequestAttribute("currentUser") User user) {
        ScheduledTransactionDTO created = scheduledTransactionService.createScheduledTransaction(request, user);
        return new ResponseEntity<>(created, HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    public ResponseEntity<ScheduledTransactionDTO> updateScheduledTransaction(
            @PathVariable Long id,
            @Valid @RequestBody CreateScheduledTransactionRequest request,
            @RequestAttribute("currentUser") User user) {
        ScheduledTransactionDTO updated = scheduledTransactionService.updateScheduledTransaction(id, request, user);
        return ResponseEntity.ok(updated);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteScheduledTransaction(
            @PathVariable Long id,
            @RequestAttribute("currentUser") User user) {
        scheduledTransactionService.deleteScheduledTransaction(id, user);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/pay")
    public ResponseEntity<TransactionDTO> payScheduledTransaction(
            @PathVariable Long id,
            @RequestAttribute("currentUser") User user) {
        TransactionDTO createdTransaction = scheduledTransactionService.payScheduledTransaction(id, user);
        return ResponseEntity.ok(createdTransaction);
    }
}
