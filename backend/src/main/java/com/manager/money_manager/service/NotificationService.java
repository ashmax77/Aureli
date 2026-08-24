package com.manager.money_manager.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Service
public class NotificationService {
    
    private static final Logger logger = LoggerFactory.getLogger(NotificationService.class);

    @Async
    public void sendPushNotification(String fcmToken, String title, String body) {
        if (fcmToken == null || fcmToken.trim().isEmpty()) {
            return;
        }

        try {
            Message message = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .build();

            String response = FirebaseMessaging.getInstance().send(message);
            logger.info("Successfully sent push notification: {}", response);
        } catch (Exception e) {
            logger.error("Failed to send push notification to token {}: {}", fcmToken, e.getMessage());
        }
    }
}
