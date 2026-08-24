package com.manager.money_manager.dto;

import com.manager.money_manager.model.TransactionType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter
@Setter
public class CreateCategoryRequest {

    @NotNull(message = "Category type must not be null")
    private TransactionType type;

    @NotBlank(message = "Category name must not be blank")
    private String name;

    private String iconKey;

    private String colorKey;
}
