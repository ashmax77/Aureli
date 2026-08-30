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

            if (configPath == null || configPath.isEmpty()) {
                java.io.File fallbackFile1 = new java.io.File("money-manager-e83f1-firebase-adminsdk-fbsvc-03d802029f.json");
                java.io.File fallbackFile2 = new java.io.File("backend/money-manager-e83f1-firebase-adminsdk-fbsvc-03d802029f.json");
                if (fallbackFile1.exists()) {
                    configPath = fallbackFile1.getAbsolutePath();
                } else if (fallbackFile2.exists()) {
                    configPath = fallbackFile2.getAbsolutePath();
                }
            }

            if (configPath != null && !configPath.isEmpty()) {
                FileInputStream serviceAccount = new FileInputStream(configPath);
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();

                if (FirebaseApp.getApps().isEmpty()) {
                    FirebaseApp.initializeApp(options);
                    logger.info("Firebase Admin SDK has been successfully initialized using path: {}", configPath);
                }
            } else {
                logger.warn("FIREBASE_CONFIG_PATH system property is not set and no fallback configuration file was found. Firebase Admin initialization skipped.");
            }
        } catch (IOException e) {
            logger.error("Failed to initialize Firebase Admin SDK: {}", e.getMessage(), e);
        }
    }
}
