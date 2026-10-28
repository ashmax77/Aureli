package com.manager.money_manager.service;

import com.manager.money_manager.dto.*;
import com.manager.money_manager.exception.BadRequestException;
import com.manager.money_manager.exception.ResourceNotFoundException;
import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.DebtRecordRepository;
import com.manager.money_manager.repository.DebtRepaymentRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional
public class DebtService {

    private final DebtRecordRepository debtRecordRepository;
    private final DebtRepaymentRepository debtRepaymentRepository;

    public DebtService(DebtRecordRepository debtRecordRepository,
                       DebtRepaymentRepository debtRepaymentRepository) {
        this.debtRecordRepository = debtRecordRepository;
        this.debtRepaymentRepository = debtRepaymentRepository;
    }

    @Transactional(readOnly = true)
    public DebtSummaryDTO getSummary(User user) {
        BigDecimal totalLent = debtRecordRepository.sumRemainingAmountByUserIdAndType(user.getId(), DebtType.LENT);
        if (totalLent == null) totalLent = BigDecimal.ZERO;

        BigDecimal totalBorrowed = debtRecordRepository.sumRemainingAmountByUserIdAndType(user.getId(), DebtType.BORROWED);
        if (totalBorrowed == null) totalBorrowed = BigDecimal.ZERO;

        BigDecimal netDebtPosition = totalLent.subtract(totalBorrowed);
        long activeLentCount = debtRecordRepository.countByUserIdAndTypeAndStatusActive(user.getId(), DebtType.LENT);
        long activeBorrowedCount = debtRecordRepository.countByUserIdAndTypeAndStatusActive(user.getId(), DebtType.BORROWED);
        long overdueCount = debtRecordRepository.countByUserIdAndStatusOverdue(user.getId());

        DebtSummaryDTO dto = new DebtSummaryDTO();
        dto.setTotalLent(totalLent);
        dto.setTotalBorrowed(totalBorrowed);
        dto.setNetDebtPosition(netDebtPosition);
        dto.setActiveLentCount(activeLentCount);
        dto.setActiveBorrowedCount(activeBorrowedCount);
        dto.setOverdueCount(overdueCount);
        return dto;
    }

    @Transactional
    public List<DebtRecordDTO> getAllDebts(User user, DebtType type, DebtStatus status) {
        List<DebtRecord> records;
        if (type != null && status != null) {
            records = debtRecordRepository.findByUserIdAndTypeAndStatusOrderByCreatedAtDesc(user.getId(), type, status);
        } else if (type != null) {
            records = debtRecordRepository.findByUserIdAndTypeOrderByCreatedAtDesc(user.getId(), type);
        } else if (status != null) {
            records = debtRecordRepository.findByUserIdAndStatusOrderByCreatedAtDesc(user.getId(), status);
        } else {
            records = debtRecordRepository.findByUserIdOrderByCreatedAtDesc(user.getId());
        }

        // Auto-evaluate overdue status on reads if active and due date in the past
        LocalDate today = LocalDate.now();
        for (DebtRecord r : records) {
            if (r.getStatus() == DebtStatus.ACTIVE && r.getDueDate() != null && r.getDueDate().isBefore(today)) {
                r.setStatus(DebtStatus.OVERDUE);
                debtRecordRepository.save(r);
            }
        }

        return records.stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public DebtRecordDTO getDebtById(Long id, User user) {
        DebtRecord debt = debtRecordRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Debt record not found with id: " + id));
        return mapToDTO(debt);
    }

    public DebtRecordDTO createDebt(CreateDebtRequest request, User user) {
        DebtRecord debt = new DebtRecord();
        debt.setUser(user);
        debt.setType(request.getType());
        debt.setCounterpartyName(request.getCounterpartyName());
        debt.setCounterpartyContact(request.getCounterpartyContact());
        debt.setPrincipalAmount(request.getPrincipalAmount());
        debt.setInterestRate(request.getInterestRate());

        // Calculate total amount due with interest if provided
        BigDecimal totalDue = request.getPrincipalAmount();
        if (request.getInterestRate() != null && request.getInterestRate().compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal interest = request.getPrincipalAmount()
                    .multiply(request.getInterestRate())
                    .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
            totalDue = totalDue.add(interest);
        }
        debt.setTotalAmountDue(totalDue);
        debt.setAmountRepaid(BigDecimal.ZERO);
        debt.setRemainingAmount(totalDue);
        debt.setStartDate(request.getStartDate());
        debt.setDueDate(request.getDueDate());
        debt.setReminderDaysBefore(request.getReminderDaysBefore() != null ? request.getReminderDaysBefore() : 3);
        debt.setNote(request.getNote());

        LocalDate today = LocalDate.now();
        if (request.getDueDate() != null && request.getDueDate().isBefore(today)) {
            debt.setStatus(DebtStatus.OVERDUE);
        } else {
            debt.setStatus(DebtStatus.ACTIVE);
        }

        DebtRecord saved = debtRecordRepository.save(debt);
        return mapToDTO(saved);
    }

    public DebtRecordDTO updateDebt(Long id, UpdateDebtRequest request, User user) {
        DebtRecord debt = debtRecordRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Debt record not found with id: " + id));

        if (request.getCounterpartyName() != null && !request.getCounterpartyName().isBlank()) {
            debt.setCounterpartyName(request.getCounterpartyName());
        }
        if (request.getCounterpartyContact() != null) {
            debt.setCounterpartyContact(request.getCounterpartyContact());
        }
        if (request.getDueDate() != null) {
            debt.setDueDate(request.getDueDate());
            if (debt.getStatus() == DebtStatus.OVERDUE && !request.getDueDate().isBefore(LocalDate.now())) {
                debt.setStatus(DebtStatus.ACTIVE);
            }
        }
        if (request.getReminderDaysBefore() != null) {
            debt.setReminderDaysBefore(request.getReminderDaysBefore());
        }
        if (request.getStatus() != null) {
            throw new BadRequestException(
                    "Debt status is derived from repayments and cannot be changed directly");
        }
        if (request.getNote() != null) {
            debt.setNote(request.getNote());
        }

        DebtRecord updated = debtRecordRepository.save(debt);
        return mapToDTO(updated);
    }

    public DebtRecordDTO recordRepayment(Long debtId, CreateDebtRepaymentRequest request, User user) {
        DebtRecord debt = debtRecordRepository.findByIdAndUserId(debtId, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Debt record not found with id: " + debtId));

        if (debt.getStatus() == DebtStatus.SETTLED) {
            throw new BadRequestException("This debt record is already fully settled.");
        }

        if (request.getAmount().compareTo(debt.getRemainingAmount()) > 0) {
            throw new BadRequestException(String.format(
                    "Repayment amount of %.2f LKR exceeds the remaining balance of %.2f LKR",
                    request.getAmount(), debt.getRemainingAmount()
            ));
        }

        DebtRepayment repayment = new DebtRepayment();
        repayment.setDebtRecord(debt);
        repayment.setUser(user);
        repayment.setAmount(request.getAmount());
        repayment.setRepaymentDate(request.getRepaymentDate());
        repayment.setPaymentMethod(request.getPaymentMethod());
        repayment.setNote(request.getNote());
        debtRepaymentRepository.save(repayment);

        BigDecimal newAmountRepaid = debt.getAmountRepaid().add(request.getAmount());
        BigDecimal newRemaining = debt.getRemainingAmount().subtract(request.getAmount());
        debt.setAmountRepaid(newAmountRepaid);
        debt.setRemainingAmount(newRemaining);

        if (newRemaining.compareTo(BigDecimal.ZERO) <= 0) {
            debt.setRemainingAmount(BigDecimal.ZERO);
            debt.setStatus(DebtStatus.SETTLED);
        }

        debt.getRepayments().add(0, repayment);
        DebtRecord updated = debtRecordRepository.save(debt);
        return mapToDTO(updated);
    }

    public void deleteDebt(Long id, User user) {
        DebtRecord debt = debtRecordRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Debt record not found with id: " + id));
        debtRecordRepository.delete(debt);
    }

    private DebtRecordDTO mapToDTO(DebtRecord d) {
        DebtRecordDTO dto = new DebtRecordDTO();
        dto.setId(d.getId());
        dto.setType(d.getType());
        dto.setCounterpartyName(d.getCounterpartyName());
        dto.setCounterpartyContact(d.getCounterpartyContact());
        dto.setPrincipalAmount(d.getPrincipalAmount());
        dto.setInterestRate(d.getInterestRate());
        dto.setTotalAmountDue(d.getTotalAmountDue());
        dto.setAmountRepaid(d.getAmountRepaid());
        dto.setRemainingAmount(d.getRemainingAmount());
        dto.setStartDate(d.getStartDate());
        dto.setDueDate(d.getDueDate());
        dto.setStatus(d.getStatus());
        dto.setReminderDaysBefore(d.getReminderDaysBefore());
        dto.setNote(d.getNote());
        dto.setCreatedAt(d.getCreatedAt());
        dto.setUpdatedAt(d.getUpdatedAt());

        if (d.getRepayments() != null) {
            dto.setRepayments(d.getRepayments().stream().map(r -> {
                DebtRepaymentDTO repDto = new DebtRepaymentDTO();
                repDto.setId(r.getId());
                repDto.setDebtRecordId(d.getId());
                repDto.setAmount(r.getAmount());
                repDto.setRepaymentDate(r.getRepaymentDate());
                repDto.setPaymentMethod(r.getPaymentMethod());
                repDto.setNote(r.getNote());
                repDto.setCreatedAt(r.getCreatedAt());
                return repDto;
            }).collect(Collectors.toList()));
        }

        return dto;
    }
}
