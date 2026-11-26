package com.manager.money_manager.dto;

import org.junit.jupiter.api.Test;

import java.beans.Introspector;
import java.beans.PropertyDescriptor;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DashboardSummaryDTOTest {

    @Test
    void dashboardSummaryCarriesEveryFieldOfTheFullSummary() throws Exception {
        BudgetSummaryResponseDTO source = new BudgetSummaryResponseDTO();
        source.setTotalIncome(new BigDecimal("100000"));
        source.setTotalExpenses(new BigDecimal("20000"));
        source.setNetCashFlow(new BigDecimal("80000"));
        source.setPreviousMonthExpenses(new BigDecimal("15000"));
        source.setCategoryBudgets(new ArrayList<>());
        source.setSavingsRatePercentage(20.0);
        source.setMonthlyReservedSavings(new BigDecimal("20000"));
        source.setCumulativeSavings(new BigDecimal("50000"));
        source.setScheduledPaymentsTotal(new BigDecimal("3000"));
        source.setSpendableAllowance(new BigDecimal("80000"));
        source.setTotalAllocatedCategoryBudgets(new BigDecimal("60000"));
        source.setUnallocatedAllowance(new BigDecimal("17000"));
        source.setCashIncome(new BigDecimal("40000"));
        source.setBankTransferIncome(new BigDecimal("60000"));
        source.setCashSpendable(new BigDecimal("32000"));
        source.setBankTransferSpendable(new BigDecimal("48000"));
        source.setCashExpenses(new BigDecimal("5000"));
        source.setCardExpenses(new BigDecimal("5000"));
        source.setBankTransferExpenses(new BigDecimal("15000"));

        DashboardSummaryDTO dto = DashboardSummaryDTO.from(source);

        assertEquals(new BigDecimal("32000"), dto.getCashSpendable());
        assertEquals(new BigDecimal("48000"), dto.getBankTransferSpendable());
        assertEquals(new BigDecimal("50000"), dto.getCumulativeSavings());
        assertEquals(new BigDecimal("17000"), dto.getUnallocatedAllowance());

        // Guard against the original bug: every property of the full summary must be copied.
        List<String> missing = new ArrayList<>();
        for (PropertyDescriptor pd : Introspector.getBeanInfo(BudgetSummaryResponseDTO.class, Object.class)
                .getPropertyDescriptors()) {
            Object value = pd.getReadMethod().invoke(source);
            PropertyDescriptor target = Arrays.stream(Introspector.getBeanInfo(DashboardSummaryDTO.class, Object.class)
                    .getPropertyDescriptors()).filter(p -> p.getName().equals(pd.getName())).findFirst().orElse(null);
            if (target == null || !java.util.Objects.equals(value, target.getReadMethod().invoke(dto))) {
                missing.add(pd.getName());
            }
        }
        assertTrue(missing.isEmpty(), "Dashboard summary drops fields: " + missing);
        assertNotNull(dto.getCategoryBudgets());
    }
}
