package com.manager.money_manager.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "debt_records")
@Getter
@Setter
public class DebtRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private DebtType type;

    @NotNull
    @Column(name = "counterparty_name", nullable = false, length = 150)
    private String counterpartyName;

    @Column(name = "counterparty_contact", length = 100)
    private String counterpartyContact;

    @NotNull
    @Column(name = "principal_amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal principalAmount;

    @Column(name = "interest_rate", precision = 5, scale = 2)
    private BigDecimal interestRate;

    @NotNull
    @Column(name = "total_amount_due", nullable = false, precision = 12, scale = 2)
    private BigDecimal totalAmountDue;

    @NotNull
    @Column(name = "amount_repaid", nullable = false, precision = 12, scale = 2)
    private BigDecimal amountRepaid = BigDecimal.ZERO;

    @NotNull
    @Column(name = "remaining_amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal remainingAmount;

    @NotNull
    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "due_date")
    private LocalDate dueDate;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private DebtStatus status = DebtStatus.ACTIVE;

    @Column(name = "reminder_days_before", nullable = false)
    private Integer reminderDaysBefore = 3;

    @Column(name = "last_notified_at")
    private LocalDateTime lastNotifiedAt;

    @Column(length = 500)
    private String note;

    @OneToMany(mappedBy = "debtRecord", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("repaymentDate DESC")
    private List<DebtRepayment> repayments = new ArrayList<>();

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now(java.time.ZoneId.of("UTC"));
        this.updatedAt = LocalDateTime.now(java.time.ZoneId.of("UTC"));
        if (this.amountRepaid == null) {
            this.amountRepaid = BigDecimal.ZERO;
        }
        if (this.totalAmountDue == null) {
            this.totalAmountDue = this.principalAmount;
        }
        if (this.remainingAmount == null) {
            this.remainingAmount = this.totalAmountDue.subtract(this.amountRepaid);
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now(java.time.ZoneId.of("UTC"));
    }
}
