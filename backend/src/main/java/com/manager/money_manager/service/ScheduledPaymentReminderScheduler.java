package com.manager.money_manager.service;

import com.manager.money_manager.model.ScheduledTransaction;
import com.manager.money_manager.repository.ScheduledTransactionRepository;
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
public class ScheduledPaymentReminderScheduler {

    private static final Logger logger = LoggerFactory.getLogger(ScheduledPaymentReminderScheduler.class);

    private final ScheduledTransactionRepository scheduledTransactionRepository;
    private final NotificationService notificationService;

    public ScheduledPaymentReminderScheduler(ScheduledTransactionRepository scheduledTransactionRepository,
                                             NotificationService notificationService) {
        this.scheduledTransactionRepository = scheduledTransactionRepository;
        this.notificationService = notificationService;
    }

    /**
     * Daily scheduled check at 8:00 AM for upcoming and overdue payment reminders.
     * Also runs fixedRate check every hour to handle near-due reminders cleanly.
     */
    @Scheduled(cron = "0 0 8 * * *")
    @Scheduled(fixedRate = 3600000, initialDelay = 10000)
    @Transactional
    public void processScheduledPaymentReminders() {
        logger.info("Executing scheduled payment reminder check...");
        LocalDate today = LocalDate.now();

        // Check for items due within 7 days
        List<ScheduledTransaction> pendingList = scheduledTransactionRepository.findPendingForReminderCheck(today.plusDays(7));

        int remindersSent = 0;
        for (ScheduledTransaction st : pendingList) {
            int reminderDays = st.getReminderDaysBefore() != null ? st.getReminderDaysBefore() : 3;
            long daysUntilDue = ChronoUnit.DAYS.between(today, st.getDueDate());

            // Notify if within reminder window (daysUntilDue <= reminderDays)
            if (daysUntilDue <= reminderDays) {
                // Check if already notified today
                if (st.getLastNotifiedAt() != null && st.getLastNotifiedAt().toLocalDate().equals(today)) {
                    continue;
                }

                String title;
                String body;
                String formattedDate = st.getDueDate().format(DateTimeFormatter.ofPattern("MMM d, yyyy"));
                String amountStr = String.format("LKR %,d", st.getAmount().longValue());

                if (daysUntilDue == 0) {
                    title = "⏰ Payment Due Today: " + st.getTitle();
                    body = "Your scheduled payment of " + amountStr + " for " + st.getTitle() + " is due today!";
                } else if (daysUntilDue > 0) {
                    title = "⏰ Payment Due Soon: " + st.getTitle();
                    body = "Your scheduled payment of " + amountStr + " for " + st.getTitle() + " is due in " + daysUntilDue + " day(s) on " + formattedDate + ".";
                } else {
                    title = "⚠️ Overdue Payment: " + st.getTitle();
                    body = "Your scheduled payment of " + amountStr + " for " + st.getTitle() + " was due on " + formattedDate + ". Please review and complete it.";
                }

                try {
                    notificationService.sendPushAlertsToUser(st.getUser().getId(), title, body);
                    st.setLastNotifiedAt(LocalDateTime.now());
                    scheduledTransactionRepository.save(st);
                    remindersSent++;
                } catch (Exception e) {
                    logger.error("Error sending reminder for scheduled payment id {}: {}", st.getId(), e.getMessage());
                }
            }
        }

        logger.info("Scheduled payment reminder check completed. Sent {} reminders.", remindersSent);
    }
}
