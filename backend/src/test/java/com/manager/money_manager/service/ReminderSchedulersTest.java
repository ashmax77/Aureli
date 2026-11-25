package com.manager.money_manager.service;

import com.manager.money_manager.model.*;
import com.manager.money_manager.repository.DebtRecordRepository;
import com.manager.money_manager.repository.ScheduledTransactionRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.TimeZone;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

class ReminderSchedulersTest {

    private TimeZone originalZone;
    private User user;

    @BeforeEach
    void setUp() {
        originalZone = TimeZone.getDefault();
        // Pick a zone whose calendar date differs from the UTC date right now, so the
        // dedupe logic is exercised in the situation that used to resend reminders.
        int utcHour = LocalDateTime.now(ZoneOffset.UTC).getHour();
        TimeZone.setDefault(TimeZone.getTimeZone(utcHour >= 11 ? "Pacific/Kiritimati" : "Pacific/Pago_Pago"));
        user = new User();
        user.setId(1L);
    }

    @AfterEach
    void tearDown() {
        TimeZone.setDefault(originalZone);
    }

    private DebtRecord debt(DebtType type, LocalDate due) {
        DebtRecord d = new DebtRecord();
        d.setId(5L);
        d.setUser(user);
        d.setType(type);
        d.setCounterpartyName("Bob");
        d.setDueDate(due);
        d.setRemainingAmount(new BigDecimal("500"));
        return d;
    }

    @Test
    void debtReminder_sentOncePerLocalDayEvenWhenJvmIsNotUtc() {
        DebtRecordRepository repo = mock(DebtRecordRepository.class);
        NotificationService ns = mock(NotificationService.class);
        DebtRecord d = debt(DebtType.BORROWED, LocalDate.now());
        when(repo.findActiveDebtsForReminderCheck(any())).thenReturn(List.of(d));
        DebtReminderScheduler scheduler = new DebtReminderScheduler(repo, ns);

        scheduler.processDebtDueReminders();
        scheduler.processDebtDueReminders();
        scheduler.processDebtDueReminders();

        verify(ns, times(1)).sendPushAlertsToUser(eq(1L), anyString(), anyString());
    }

    @Test
    void scheduledPaymentReminder_sentOncePerLocalDayEvenWhenJvmIsNotUtc() {
        ScheduledTransactionRepository repo = mock(ScheduledTransactionRepository.class);
        NotificationService ns = mock(NotificationService.class);
        ScheduledTransaction st = new ScheduledTransaction();
        st.setId(9L);
        st.setUser(user);
        st.setTitle("Rent");
        st.setAmount(new BigDecimal("100"));
        st.setDueDate(LocalDate.now());
        when(repo.findPendingForReminderCheck(any())).thenReturn(List.of(st));
        ScheduledPaymentReminderScheduler scheduler = new ScheduledPaymentReminderScheduler(repo, ns);

        scheduler.processScheduledPaymentReminders();
        scheduler.processScheduledPaymentReminders();
        scheduler.processScheduledPaymentReminders();

        verify(ns, times(1)).sendPushAlertsToUser(eq(1L), anyString(), anyString());
    }

    @Test
    void debtReminder_overdueDebtIsMarkedOverdueAndNotified() {
        DebtRecordRepository repo = mock(DebtRecordRepository.class);
        NotificationService ns = mock(NotificationService.class);
        DebtRecord d = debt(DebtType.LENT, LocalDate.now().minusDays(2));
        when(repo.findActiveDebtsForReminderCheck(any())).thenReturn(List.of(d));

        new DebtReminderScheduler(repo, ns).processDebtDueReminders();

        assertEquals(DebtStatus.OVERDUE, d.getStatus());
        verify(ns).sendPushAlertsToUser(eq(1L), Mockito.contains("Overdue"), anyString());
    }

    @Test
    void debtReminder_outsideReminderWindowIsSkipped() {
        DebtRecordRepository repo = mock(DebtRecordRepository.class);
        NotificationService ns = mock(NotificationService.class);
        DebtRecord d = debt(DebtType.BORROWED, LocalDate.now().plusDays(6));
        d.setReminderDaysBefore(3);
        when(repo.findActiveDebtsForReminderCheck(any())).thenReturn(List.of(d));

        new DebtReminderScheduler(repo, ns).processDebtDueReminders();

        verifyNoInteractions(ns);
        assertNull(d.getLastNotifiedAt());
    }
}
