package com.manager.money_manager.dto;

import com.manager.money_manager.model.TransactionType;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter
@Setter
public class CategoryDTO {
    private Long id;
    private TransactionType type;
    private String name;
    private String iconKey;
    private String colorKey;
    private boolean isArchived;
    private boolean isSystemDefault;
}
