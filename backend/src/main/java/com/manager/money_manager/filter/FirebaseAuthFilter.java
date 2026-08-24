package com.manager.money_manager.filter;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import com.manager.money_manager.model.Category;
import com.manager.money_manager.model.TransactionType;
import com.manager.money_manager.model.User;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.UserRepository;
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
    private final UserRepository userRepository;
    private final CategoryRepository categoryRepository;

    public FirebaseAuthFilter(UserRepository userRepository, CategoryRepository categoryRepository) {
        this.userRepository = userRepository;
        this.categoryRepository = categoryRepository;
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

            try {
                FirebaseToken decodedToken = FirebaseAuth.getInstance().verifyIdToken(idToken);
                String firebaseUid = decodedToken.getUid();
                String email = decodedToken.getEmail();

                // Find or auto-create local User record
                User user = userRepository.findByFirebaseUid(firebaseUid)
                        .orElseGet(() -> {
                            User newUser = new User();
                            newUser.setFirebaseUid(firebaseUid);
                            newUser.setEmail(email);
                            newUser.setCurrencyCode("LKR");
                            logger.info("Auto-creating user row for Firebase UID: {}", firebaseUid);
                            User saved = userRepository.save(newUser);
                            seedDefaultCategories(saved);
                            return saved;
                        });

                // Attach user entity to request context
                httpRequest.setAttribute("currentUser", user);
                chain.doFilter(request, response);
            } catch (Exception e) {
                logger.error("Token verification failed for path {}: {}", path, e.getMessage());
                sendUnauthorizedError(httpResponse, "Invalid or expired Firebase ID token");
            }
        } else {
            // Forward non-v1 requests directly
            chain.doFilter(request, response);
        }
    }

    private void seedDefaultCategories(User user) {
        logger.info("Seeding default categories for user: {}", user.getEmail());
        
        // Seed Expense Categories
        seedCategory(user, TransactionType.EXPENSE, "Food", "fastfood", "#E57373");
        seedCategory(user, TransactionType.EXPENSE, "Transport", "directions_car", "#64B5F6");
        seedCategory(user, TransactionType.EXPENSE, "Rent", "home", "#81C784");
        seedCategory(user, TransactionType.EXPENSE, "Utilities", "power", "#FFD54F");
        seedCategory(user, TransactionType.EXPENSE, "Shopping", "shopping_cart", "#BA68C8");
        seedCategory(user, TransactionType.EXPENSE, "Entertainment", "movie", "#FF8A65");

        // Seed Income Categories
        seedCategory(user, TransactionType.INCOME, "Salary", "attach_money", "#4DB6AC");
        seedCategory(user, TransactionType.INCOME, "Freelance", "work", "#7986CB");
        seedCategory(user, TransactionType.INCOME, "Investments", "trending_up", "#AED581");
        seedCategory(user, TransactionType.INCOME, "Gifts", "card_giftcard", "#F06292");
    }

    private void seedCategory(User user, TransactionType type, String name, String icon, String color) {
        Category category = new Category();
        category.setUser(user);
        category.setType(type);
        category.setName(name);
        category.setIconKey(icon);
        category.setColorKey(color);
        category.setSystemDefault(true);
        category.setArchived(false);
        categoryRepository.save(category);
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
