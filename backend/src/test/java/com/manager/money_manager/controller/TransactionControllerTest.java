package com.manager.money_manager.controller;

import com.manager.money_manager.model.*;
import com.manager.money_manager.service.TransactionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TransactionControllerTest {

    @Mock
    private TransactionService transactionService;

    @InjectMocks
    private TransactionController transactionController;

    private User user;
    private Category category;
    private Transaction t1;
    private Transaction t2;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setEmail("user@example.com");

        category = new Category();
        category.setName("Food, Dineout"); // Category name with comma

        t1 = new Transaction();
        t1.setTransactionDate(LocalDate.of(2026, 8, 24));
        t1.setType(TransactionType.EXPENSE);
        t1.setCategory(category);
        t1.setAmount(new BigDecimal("150.00"));
        t1.setPaymentMethod(PaymentMethod.CASH);
        t1.setNote("Lunch, with team"); // Note with comma

        t2 = new Transaction();
        t2.setTransactionDate(LocalDate.of(2026, 8, 25));
        t2.setType(TransactionType.EXPENSE);
        t2.setCategory(category);
        t2.setAmount(new BigDecimal("35.00"));
        t2.setPaymentMethod(PaymentMethod.CARD);
        t2.setNote("Bought \"pizza\""); // Note with double quotes
    }

    @Test
    void exportTransactionsCsv_streamsValidRfc4180Csv() throws IOException {
        List<Transaction> mockTransactions = new ArrayList<>(List.of(t1, t2));
        
        when(transactionService.getRawTransactionsList(
                eq(user), any(), any(), any(), any(), any(), any(), any()
        )).thenReturn(mockTransactions);

        ResponseEntity<StreamingResponseBody> response = transactionController.exportTransactionsCsv(
                user, null, null, null, null, null, null, null
        );

        assertNotNull(response);
        assertEquals("attachment; filename=\"transactions.csv\"", response.getHeaders().getFirst("Content-Disposition"));
        assertEquals("text/csv", response.getHeaders().getContentType().toString());

        StreamingResponseBody body = response.getBody();
        assertNotNull(body);

        // Capture streamed output
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        body.writeTo(outputStream);
        String csvContent = outputStream.toString("UTF-8");

        // Verify CSV output structure and RFC 4180 escaping rules
        String[] lines = csvContent.split("\n");
        assertEquals(3, lines.length); // 1 header + 2 transaction lines

        // Header Row
        assertEquals("Date,Type,Category,Amount,Payment Method,Note", lines[0].trim());

        // Note with double quotes should be escaped: "Bought ""pizza"""
        // Category with comma should be escaped: "Food, Dineout"
        // Date sorting is descending (t2 with 2026-08-25 is first)
        String expectedRow1 = "2026-08-25,EXPENSE,\"Food, Dineout\",35.00,CARD,\"Bought \"\"pizza\"\"\"";
        String expectedRow2 = "2026-08-24,EXPENSE,\"Food, Dineout\",150.00,CASH,\"Lunch, with team\"";

        assertEquals(expectedRow1, lines[1].trim());
        assertEquals(expectedRow2, lines[2].trim());
    }
}
