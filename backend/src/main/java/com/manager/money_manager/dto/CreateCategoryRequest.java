package com.manager.money_manager.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter
@Setter
public class CreateCategoryRequest {

    @NotBlank(message = "Category name must not be blank")
    private String name;

    private BigDecimal budgetLimit;
}
