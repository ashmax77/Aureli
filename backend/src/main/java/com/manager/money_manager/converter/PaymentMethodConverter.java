package com.manager.money_manager.converter;

import com.manager.money_manager.model.PaymentMethod;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class PaymentMethodConverter implements AttributeConverter<PaymentMethod, String> {

    @Override
    public String convertToDatabaseColumn(PaymentMethod attribute) {
        if (attribute == null) {
            return PaymentMethod.CASH.name();
        }
        return attribute.name();
    }

    @Override
    public PaymentMethod convertToEntityAttribute(String dbData) {
        if (dbData == null) {
            return PaymentMethod.CASH;
        }
        try {
            return PaymentMethod.valueOf(dbData.toUpperCase());
        } catch (IllegalArgumentException e) {
            if ("BANK_TRANSFER".equalsIgnoreCase(dbData)) {
                return PaymentMethod.BANK_TRANSFER;
            }
            return PaymentMethod.CASH;
        }
    }
}
