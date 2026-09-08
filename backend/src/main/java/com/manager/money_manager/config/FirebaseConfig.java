package com.manager.money_manager.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Configuration;
import jakarta.annotation.PostConstruct;

import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

@Configuration
public class FirebaseConfig {

    private static final Logger logger = LoggerFactory.getLogger(FirebaseConfig.class);

    @PostConstruct
    public void initialize() {
        try {
            if (!FirebaseApp.getApps().isEmpty()) {
                logger.info("Firebase Admin SDK is already initialized.");
                return;
            }

            InputStream serviceAccountStream = null;

            // 1. Check for raw JSON in FIREBASE_CREDENTIALS_JSON environment variable
            String credentialsJson = System.getenv("FIREBASE_CREDENTIALS_JSON");
            if (credentialsJson == null || credentialsJson.trim().isEmpty()) {
                credentialsJson = System.getProperty("FIREBASE_CREDENTIALS_JSON");
            }

            if (credentialsJson != null && !credentialsJson.trim().isEmpty()) {
                logger.info("Initializing Firebase Admin SDK using FIREBASE_CREDENTIALS_JSON environment variable.");
                serviceAccountStream = new ByteArrayInputStream(credentialsJson.getBytes(StandardCharsets.UTF_8));
            }

            // 2. Check for Base64 encoded JSON in FIREBASE_CREDENTIALS_BASE64 environment variable
            if (serviceAccountStream == null) {
                String credentialsBase64 = System.getenv("FIREBASE_CREDENTIALS_BASE64");
                if (credentialsBase64 == null || credentialsBase64.trim().isEmpty()) {
                    credentialsBase64 = System.getProperty("FIREBASE_CREDENTIALS_BASE64");
                }
                if (credentialsBase64 != null && !credentialsBase64.trim().isEmpty()) {
                    logger.info("Initializing Firebase Admin SDK using FIREBASE_CREDENTIALS_BASE64 environment variable.");
                    byte[] decoded = Base64.getDecoder().decode(credentialsBase64.trim());
                    serviceAccountStream = new ByteArrayInputStream(decoded);
                }
            }

            // 3. Fallback to file path from FIREBASE_CONFIG_PATH or local fallback JSON files
            if (serviceAccountStream == null) {
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
                    logger.info("Initializing Firebase Admin SDK using file path: {}", configPath);
                    serviceAccountStream = new FileInputStream(configPath);
                }
            }

            if (serviceAccountStream != null) {
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccountStream))
                        .build();
                FirebaseApp.initializeApp(options);
                logger.info("Firebase Admin SDK has been successfully initialized!");
            } else {
                logger.warn("No Firebase Admin credentials found! Set FIREBASE_CREDENTIALS_JSON or FIREBASE_CREDENTIALS_BASE64 on Render environment variables.");
            }
        } catch (IOException e) {
            logger.error("Failed to initialize Firebase Admin SDK: {}", e.getMessage(), e);
        }
    }
}
