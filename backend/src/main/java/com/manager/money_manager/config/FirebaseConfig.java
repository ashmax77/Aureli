package com.manager.money_manager.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Configuration;
import jakarta.annotation.PostConstruct;
import java.io.FileInputStream;
import java.io.IOException;

@Configuration
public class FirebaseConfig {

    private static final Logger logger = LoggerFactory.getLogger(FirebaseConfig.class);

    @PostConstruct
    public void initialize() {
        try {
            String configPath = System.getProperty("FIREBASE_CONFIG_PATH");
            if (configPath == null || configPath.isEmpty()) {
                configPath = System.getenv("FIREBASE_CONFIG_PATH");
            }

            if (configPath != null && !configPath.isEmpty()) {
                FileInputStream serviceAccount = new FileInputStream(configPath);
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();

                if (FirebaseApp.getApps().isEmpty()) {
                    FirebaseApp.initializeApp(options);
                    logger.info("Firebase Admin SDK has been successfully initialized.");
                }
            } else {
                logger.warn("FIREBASE_CONFIG_PATH system property is not set. Firebase Admin initialization skipped.");
            }
        } catch (IOException e) {
            logger.error("Failed to initialize Firebase Admin SDK: {}", e.getMessage(), e);
        }
    }
}
