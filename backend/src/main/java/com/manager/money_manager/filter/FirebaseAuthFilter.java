package com.manager.money_manager.filter;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.UserService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;

@Component
public class FirebaseAuthFilter implements Filter {

    private static final Logger logger = LoggerFactory.getLogger(FirebaseAuthFilter.class);
    private final UserService userService;

    public FirebaseAuthFilter(UserService userService) {
        this.userService = userService;
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;

        String path = httpRequest.getRequestURI();
        
        // Skip auth filter for public endpoints (such as /api/health)
        if (path.startsWith("/api/health")) {
            chain.doFilter(request, response);
            return;
        }

        // Apply auth check to all business endpoints mapped to /api/v1/**
        if (path.startsWith("/api/v1/")) {
            String authHeader = httpRequest.getHeader("Authorization");
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                logger.warn("Request to {} blocked: Missing Authorization header", path);
                sendUnauthorizedError(httpResponse, "Missing or invalid Authorization header");
                return;
            }

            String idToken = authHeader.substring(7);

            User user;
            try {
                if (com.google.firebase.FirebaseApp.getApps().isEmpty()) {
                    logger.error("Cannot verify token: FirebaseApp is not initialized! Set FIREBASE_CREDENTIALS_JSON or FIREBASE_CREDENTIALS_BASE64 in Render environment variables.");
                    sendUnauthorizedError(httpResponse, "Backend Firebase Admin SDK not initialized");
                    return;
                }

                FirebaseToken decodedToken = FirebaseAuth.getInstance().verifyIdToken(idToken);
                String firebaseUid = decodedToken.getUid();
                String email = decodedToken.getEmail();

                // Find or auto-create local User record using transactional UserService
                user = userService.findOrCreateUser(firebaseUid, email);
            } catch (Exception e) {
                logger.error("Token verification failed for path {}: {}", path, e.getMessage(), e);
                sendUnauthorizedError(httpResponse, "Invalid or expired Firebase ID token");
                return;
            }

            try {
                // Attach user entity to request context & RLS context
                httpRequest.setAttribute("currentUser", user);
                com.manager.money_manager.config.UserContextHolder.setUserId(user.getFirebaseUid());

                chain.doFilter(request, response);
            } finally {
                com.manager.money_manager.config.UserContextHolder.clear();
            }
        } else {
            // Forward non-v1 requests directly
            chain.doFilter(request, response);
        }
    }

    private void sendUnauthorizedError(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write(String.format(
            "{\"error\": \"Unauthorized\", \"message\": \"%s\"}",
            message
        ));
    }
}
