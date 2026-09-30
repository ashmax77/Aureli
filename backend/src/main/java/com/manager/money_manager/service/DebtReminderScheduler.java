package com.manager.money_manager.service;

import com.manager.money_manager.model.DebtRecord;
import com.manager.money_manager.model.DebtStatus;
import com.manager.money_manager.model.DebtType;
import com.manager.money_manager.repository.DebtRecordRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class DebtReminderScheduler {

    private static final Logger logger = LoggerFactory.getLogger(DebtReminderScheduler.class);

    private final DebtRecordRepository debtRecordRepository;
    private final NotificationService notificationService;

    public DebtReminderScheduler(DebtRecordRepository debtRecordRepository,
                                 NotificationService notificationService) {
        this.debtRecordRepository = debtRecordRepository;
        this.notificationService = notificationService;
    }

    /**
     * Daily check at 8:00 AM for upcoming and overdue loan/debt due dates.
     * Also runs periodic check every hour to handle due dates smoothly.
     */
    @Scheduled(cron = "0 0 8 * * *")
    @Scheduled(fixedRate = 3600000, initialDelay = 15000)
    @Transactional
    public void processDebtDueReminders() {
        logger.info("Executing loan & debt reminder check...");
        LocalDate today = LocalDate.now();

        List<DebtRecord> activeDebts = debtRecordRepository.findActiveDebtsForReminderCheck(today.plusDays(7));
        int remindersSent = 0;

        for (DebtRecord debt : activeDebts) {
            if (debt.getDueDate() == null) continue;

            int reminderDays = debt.getReminderDaysBefore() != null ? debt.getReminderDaysBefore() : 3;
            long daysUntilDue = ChronoUnit.DAYS.between(today, debt.getDueDate());

            // Check if within reminder window
            if (daysUntilDue <= reminderDays) {
                // Deduplicate for today
                if (debt.getLastNotifiedAt() != null && debt.getLastNotifiedAt().toLocalDate().equals(today)) {
                    continue;
                }

                String formattedDate = debt.getDueDate().format(DateTimeFormatter.ofPattern("MMM d, yyyy"));
                String amountStr = String.format("LKR %,d", debt.getRemainingAmount().longValue());
                String title;
                String body;

                if (debt.getType() == DebtType.BORROWED) {
                    if (daysUntilDue == 0) {
                        title = "⏰ Loan Payment Due Today: " + debt.getCounterpartyName();
                        body = "Your loan installment of " + amountStr + " to " + debt.getCounterpartyName() + " is due today!";
                    } else if (daysUntilDue > 0) {
                        title = "⏰ Upcoming Loan Due: " + debt.getCounterpartyName();
                        body = "Your loan repayment of " + amountStr + " to " + debt.getCounterpartyName() + " is due in " + daysUntilDue + " day(s) on " + formattedDate + ".";
                    } else {
                        debt.setStatus(DebtStatus.OVERDUE);
                        title = "⚠️ Overdue Loan Payment: " + debt.getCounterpartyName();
                        body = "Your loan payment of " + amountStr + " to " + debt.getCounterpartyName() + " was due on " + formattedDate + ". Please review and settle it.";
                    }
                } else {
                    // LENT (Receivable)
                    if (daysUntilDue == 0) {
                        title = "🔔 Follow-up Reminder Today: " + debt.getCounterpartyName();
                        body = amountStr + " lent to " + debt.getCounterpartyName() + " is scheduled for return today.";
                    } else if (daysUntilDue > 0) {
                        title = "🔔 Upcoming Return: " + debt.getCounterpartyName();
                        body = amountStr + " lent to " + debt.getCounterpartyName() + " is expected back in " + daysUntilDue + " day(s) on " + formattedDate + ".";
                    } else {
                        debt.setStatus(DebtStatus.OVERDUE);
                        title = "⚠️ Overdue Receivable: " + debt.getCounterpartyName();
                        body = amountStr + " lent to " + debt.getCounterpartyName() + " was due on " + formattedDate + ". Time for a polite follow-up!";
                    }
                }

                try {
                    notificationService.sendPushAlertsToUser(debt.getUser().getId(), title, body);
                    debt.setLastNotifiedAt(LocalDateTime.now(java.time.ZoneId.of("UTC")));
                    debtRecordRepository.save(debt);
                    remindersSent++;
                } catch (Exception e) {
                    logger.error("Error dispatching reminder for debt id {}: {}", debt.getId(), e.getMessage());
                }
            }
        }

        logger.info("Loan & debt reminder check completed. Sent {} reminders.", remindersSent);
    }
}
