package com.manager.money_manager.exception;

import com.manager.money_manager.controller.DebtController;
import com.manager.money_manager.controller.TransactionController;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.DebtService;
import com.manager.money_manager.service.TransactionService;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class GlobalExceptionHandlerTest {

    private final TransactionService transactionService = mock(TransactionService.class);
    private final DebtService debtService = mock(DebtService.class);
    private final MockMvc mvc = MockMvcBuilders
            .standaloneSetup(new TransactionController(transactionService), new DebtController(debtService))
            .setControllerAdvice(new GlobalExceptionHandler())
            .build();

    private MockHttpServletRequestBuilder asUser(MockHttpServletRequestBuilder builder) {
        User user = new User();
        user.setId(1L);
        return builder.requestAttr("currentUser", user);
    }

    private static final String VALID_TX = "{\"type\":\"EXPENSE\",\"amount\":5,\"transactionDate\":\"2026-09-01\","
            + "\"note\":\"x\",\"paymentMethod\":\"CASH\",\"categoryId\":1}";

    @Test
    void resourceNotFound_returns404WithMessage() throws Exception {
        when(transactionService.getTransaction(anyLong(), any()))
                .thenThrow(new ResourceNotFoundException("Transaction not found with id: 99"));

        mvc.perform(asUser(get("/api/v1/transactions/99")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("Not Found"))
                .andExpect(jsonPath("$.message").value("Transaction not found with id: 99"));
    }

    @Test
    void badRequest_returns400WithMessage() throws Exception {
        when(debtService.recordRepayment(anyLong(), any(), any()))
                .thenThrow(new BadRequestException("This debt record is already fully settled."));

        mvc.perform(asUser(post("/api/v1/debts/1/repayments").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"amount\":10,\"repaymentDate\":\"2026-09-01\",\"paymentMethod\":\"CASH\"}")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("This debt record is already fully settled."));
    }

    @Test
    void validationFailure_returns400WithFieldMessageAndNoInternals() throws Exception {
        String missingAmount = VALID_TX.replace("\"amount\":5,", "");

        mvc.perform(asUser(post("/api/v1/transactions").contentType(MediaType.APPLICATION_JSON).content(missingAmount)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Amount must not be null"));
    }

    @Test
    void malformedJsonAndBadEnum_return400() throws Exception {
        mvc.perform(asUser(post("/api/v1/transactions").contentType(MediaType.APPLICATION_JSON).content("{not json")))
                .andExpect(status().isBadRequest());
        mvc.perform(asUser(post("/api/v1/transactions").contentType(MediaType.APPLICATION_JSON)
                        .content(VALID_TX.replace("EXPENSE", "BOGUS"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Malformed or unreadable request body"));
    }

    @Test
    void badPathOrQueryParameterType_returns400() throws Exception {
        mvc.perform(asUser(get("/api/v1/transactions/abc"))).andExpect(status().isBadRequest());
        mvc.perform(asUser(get("/api/v1/transactions/export").param("startDate", "not-a-date")))
                .andExpect(status().isBadRequest());
    }

    @Test
    void unexpectedException_returns500WithoutLeakingDetails() throws Exception {
        when(transactionService.getTransaction(anyLong(), any()))
                .thenThrow(new IllegalStateException("could not execute statement; SQL [insert into secret_table]"));

        mvc.perform(asUser(get("/api/v1/transactions/1")))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.message").value("An unexpected error occurred."));
    }
}
