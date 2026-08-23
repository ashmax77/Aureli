package com.manager.money_manager.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter
@Setter
public class CategoryDTO {
    private Long id;
    private String name;
    private BigDecimal budgetLimit;
}
