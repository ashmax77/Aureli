package com.manager.money_manager.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter
@Setter
@AllArgsConstructor
public class CategoryBreakdownDTO {
    private Long categoryId;
    private String categoryName;
    private BigDecimal totalAmount;
    private double percentage;
    private String colorKey;
}
