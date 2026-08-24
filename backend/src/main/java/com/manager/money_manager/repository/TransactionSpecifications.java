package com.manager.money_manager.repository;

import com.manager.money_manager.model.Transaction;
import com.manager.money_manager.model.TransactionType;
import org.springframework.data.jpa.domain.Specification;
import java.math.BigDecimal;
import java.time.LocalDate;

public class TransactionSpecifications {

    public static Specification<Transaction> hasUserId(Long userId) {
        return (root, query, cb) -> cb.equal(root.get("user").get("id"), userId);
    }

    public static Specification<Transaction> hasType(TransactionType type) {
        return (root, query, cb) -> type == null ? null : cb.equal(root.get("type"), type);
    }

    public static Specification<Transaction> hasCategoryId(Long categoryId) {
        return (root, query, cb) -> categoryId == null ? null : cb.equal(root.get("category").get("id"), categoryId);
    }

    public static Specification<Transaction> dateBetween(LocalDate start, LocalDate end) {
        return (root, query, cb) -> {
            if (start == null && end == null) return null;
            if (start != null && end == null) return cb.greaterThanOrEqualTo(root.get("transactionDate"), start);
            if (start == null && end != null) return cb.lessThanOrEqualTo(root.get("transactionDate"), end);
            return cb.between(root.get("transactionDate"), start, end);
        };
    }

    public static Specification<Transaction> amountBetween(BigDecimal min, BigDecimal max) {
        return (root, query, cb) -> {
            if (min == null && max == null) return null;
            if (min != null && max == null) return cb.greaterThanOrEqualTo(root.get("amount"), min);
            if (min == null && max != null) return cb.lessThanOrEqualTo(root.get("amount"), max);
            return cb.between(root.get("amount"), min, max);
        };
    }

    public static Specification<Transaction> noteContains(String search) {
        return (root, query, cb) -> {
            if (search == null || search.trim().isEmpty()) return null;
            return cb.like(cb.lower(root.get("note")), "%" + search.trim().toLowerCase() + "%");
        };
    }
}
