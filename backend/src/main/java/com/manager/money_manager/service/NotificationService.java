package com.manager.money_manager.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.MessagingErrorCode;
import com.manager.money_manager.model.UserDevice;
import com.manager.money_manager.repository.UserDeviceRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
@Transactional
public class NotificationService {
    
    private static final Logger logger = LoggerFactory.getLogger(NotificationService.class);
    
    private final UserDeviceRepository userDeviceRepository;

    public NotificationService(UserDeviceRepository userDeviceRepository) {
        this.userDeviceRepository = userDeviceRepository;
    }

    @Async
    public void sendPushAlertsToUser(Long userId, String title, String body) {
        List<UserDevice> devices = userDeviceRepository.findByUserId(userId);
        if (devices.isEmpty()) {
            return;
        }

        for (UserDevice device : devices) {
            String token = device.getFcmToken();
            try {
                Message message = Message.builder()
                        .setToken(token)
                        .setNotification(Notification.builder()
                                .setTitle(title)
                                .setBody(body)
                                .build())
                        .build();

                String response = FirebaseMessaging.getInstance().send(message);
                logger.info("Successfully sent push notification to device id {}: {}", device.getId(), response);
            } catch (FirebaseMessagingException e) {
                logger.error("Firebase error sending to token {}: {}", token, e.getMessagingErrorCode());
                if (e.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED 
                        || e.getMessagingErrorCode() == MessagingErrorCode.INVALID_ARGUMENT) {
                    logger.warn("Deleting invalid or unregistered FCM token from DB: {}", token);
                    userDeviceRepository.deleteByFcmToken(token);
                }
            } catch (Exception e) {
                logger.error("Unknown error sending push notification to token {}: {}", token, e.getMessage());
            }
        }
    }
}
