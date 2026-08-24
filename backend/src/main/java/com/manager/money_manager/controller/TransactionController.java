package com.manager.money_manager.controller;

import com.manager.money_manager.dto.CreateTransactionRequest;
import com.manager.money_manager.dto.TransactionDTO;
import com.manager.money_manager.model.Transaction;
import com.manager.money_manager.model.TransactionType;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.TransactionService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;
import jakarta.validation.Valid;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;

@RestController
@RequestMapping("/api/v1/transactions")
public class TransactionController {

    private final TransactionService transactionService;

    public TransactionController(TransactionService transactionService) {
        this.transactionService = transactionService;
    }

    @PostMapping
    public ResponseEntity<TransactionDTO> createTransaction(
            @Valid @RequestBody CreateTransactionRequest request,
            @RequestAttribute("currentUser") User user) {
        TransactionDTO created = transactionService.createTransaction(request, user);
        return new ResponseEntity<>(created, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<Page<TransactionDTO>> getTransactions(
            @RequestAttribute("currentUser") User user,
            @RequestParam(required = false) TransactionType type,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) LocalDate startDate,
            @RequestParam(required = false) LocalDate endDate,
            @RequestParam(required = false) BigDecimal minAmount,
            @RequestParam(required = false) BigDecimal maxAmount,
            @RequestParam(required = false) String search,
            @PageableDefault(size = 10, sort = "transactionDate", direction = Sort.Direction.DESC) Pageable pageable) {
        
        Page<TransactionDTO> transactions = transactionService.getTransactions(
                user, type, categoryId, startDate, endDate, minAmount, maxAmount, search, pageable
        );
        return ResponseEntity.ok(transactions);
    }

    @GetMapping("/export")
    public ResponseEntity<StreamingResponseBody> exportTransactionsCsv(
            @RequestAttribute("currentUser") User user,
            @RequestParam(required = false) TransactionType type,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) LocalDate startDate,
            @RequestParam(required = false) LocalDate endDate,
            @RequestParam(required = false) BigDecimal minAmount,
            @RequestParam(required = false) BigDecimal maxAmount,
            @RequestParam(required = false) String search) {

        List<Transaction> transactions = transactionService.getRawTransactionsList(
                user, type, categoryId, startDate, endDate, minAmount, maxAmount, search
        );

        // Sort chronologically (newest first) for CSV exports
        transactions.sort(Comparator.comparing(Transaction::getTransactionDate).reversed());

        StreamingResponseBody responseBody = outputStream -> {
            java.io.BufferedWriter writer = new java.io.BufferedWriter(new java.io.OutputStreamWriter(outputStream, java.nio.charset.StandardCharsets.UTF_8));
            // RFC 4180 CSV Header
            writer.write("Date,Type,Category,Amount,Payment Method,Note\n");

            for (Transaction t : transactions) {
                String noteEscaped = (t.getNote() != null) ? escapeCsvField(t.getNote()) : "";
                String categoryNameEscaped = escapeCsvField(t.getCategory().getName());
                
                writer.write(String.format("%s,%s,%s,%s,%s,%s\n",
                        t.getTransactionDate().toString(),
                        t.getType().toString(),
                        categoryNameEscaped,
                        t.getAmount().toString(),
                        t.getPaymentMethod().toString(),
                        noteEscaped
                ));
            }
            writer.flush();
        };

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"transactions.csv\"")
                .contentType(MediaType.parseMediaType("text/csv"))
                .body(responseBody);
    }

    @GetMapping("/{id}")
    public ResponseEntity<TransactionDTO> getTransaction(
            @PathVariable Long id,
            @RequestAttribute("currentUser") User user) {
        TransactionDTO transaction = transactionService.getTransaction(id, user);
        return ResponseEntity.ok(transaction);
    }

    @PutMapping("/{id}")
    public ResponseEntity<TransactionDTO> updateTransaction(
            @PathVariable Long id,
            @Valid @RequestBody CreateTransactionRequest request,
            @RequestAttribute("currentUser") User user) {
        TransactionDTO updated = transactionService.updateTransaction(id, request, user);
        return ResponseEntity.ok(updated);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteTransaction(
            @PathVariable Long id,
            @RequestAttribute("currentUser") User user) {
        transactionService.deleteTransaction(id, user);
        return ResponseEntity.noContent().build();
    }

    private String escapeCsvField(String field) {
        if (field.startsWith("=") || field.startsWith("+") || field.startsWith("-") || field.startsWith("@")) {
            field = "'" + field;
        }
        if (field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")) {
            return "\"" + field.replace("\"", "\"\"") + "\"";
        }
        return field;
    }
}
