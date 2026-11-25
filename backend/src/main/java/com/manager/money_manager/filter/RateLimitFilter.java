package com.manager.money_manager.filter;

import com.manager.money_manager.model.User;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Bucket4j;
import io.github.bucket4j.Refill;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
@Order(2) // Run AFTER FirebaseAuthFilter (which should be Order 1 implicitly or explicitly)
public class RateLimitFilter implements Filter {

    private static final Logger logger = LoggerFactory.getLogger(RateLimitFilter.class);

    // Store buckets per user identifier (Firebase UID or IP address)
    private final Map<String, Bucket> cache = new ConcurrentHashMap<>();

    private Bucket createNewBucket() {
        // Limit: 60 requests per minute
        Refill refill = Refill.greedy(60, Duration.ofMinutes(1));
        Bandwidth limit = Bandwidth.classic(60, refill);
        return Bucket4j.builder().addLimit(limit).build();
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;

        String path = httpRequest.getRequestURI();

        // Skip rate limiting for health check
        if ("/api/health".equals(path) || "/api/health/".equals(path)) {
            chain.doFilter(request, response);
            return;
        }

        // Determine rate limit key
        String rateLimitKey;
        User currentUser = (User) httpRequest.getAttribute("currentUser");
        
        if (currentUser != null) {
            rateLimitKey = currentUser.getFirebaseUid(); // Limit by authenticated user
        } else {
            // Fallback to IP address if no user is found (e.g. they failed auth)
            rateLimitKey = httpRequest.getRemoteAddr();
        }

        Bucket bucket = cache.computeIfAbsent(rateLimitKey, k -> createNewBucket());

        if (bucket.tryConsume(1)) {
            // Request allowed
            chain.doFilter(request, response);
        } else {
            // Rate limit exceeded
            logger.warn("Rate limit exceeded for key: {}", rateLimitKey);
            sendRateLimitExceededError(httpResponse);
        }
    }

    private void sendRateLimitExceededError(HttpServletResponse response) throws IOException {
        response.setStatus(429); // 429 Too Many Requests
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write(
            "{\"error\": \"Too Many Requests\", \"message\": \"You have exceeded the maximum number of requests allowed per minute. Please try again later.\"}"
        );
    }
}
