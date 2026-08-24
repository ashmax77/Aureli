package com.manager.money_manager.service;

import com.manager.money_manager.model.Category;
import com.manager.money_manager.model.OnboardingStatus;
import com.manager.money_manager.model.TransactionType;
import com.manager.money_manager.model.User;
import com.manager.money_manager.model.UserDevice;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.UserRepository;
import com.manager.money_manager.repository.UserDeviceRepository;
import com.manager.money_manager.exception.ResourceNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

@Service
public class UserService {

    private static final Logger logger = LoggerFactory.getLogger(UserService.class);

    private final UserRepository userRepository;
    private final CategoryRepository categoryRepository;
    private final UserDeviceRepository userDeviceRepository;

    public UserService(UserRepository userRepository,
                       CategoryRepository categoryRepository,
                       UserDeviceRepository userDeviceRepository) {
        this.userRepository = userRepository;
        this.categoryRepository = categoryRepository;
        this.userDeviceRepository = userDeviceRepository;
    }

    @Transactional(rollbackFor = Exception.class)
    public User findOrCreateUser(String firebaseUid, String email) {
        return userRepository.findByFirebaseUid(firebaseUid)
                .orElseGet(() -> {
                    logger.info("Initializing first-time provisioning for Firebase UID: {}", firebaseUid);
                    User newUser = new User();
                    newUser.setFirebaseUid(firebaseUid);
                    newUser.setEmail(email);
                    newUser.setCurrencyCode("LKR");
                    newUser.setOnboardingStatus(OnboardingStatus.NOT_STARTED);

                    User savedUser;
                    try {
                        savedUser = userRepository.saveAndFlush(newUser);
                    } catch (DataIntegrityViolationException ex) {
                        logger.warn("Unique constraint conflict on UID {}. Re-fetching user.", firebaseUid);
                        return userRepository.findByFirebaseUid(firebaseUid)
                                .orElseThrow(() -> new IllegalStateException("Failed to recover concurrent user save"));
                    }

                    seedDefaultCategories(savedUser);
                    return savedUser;
                });
    }

    @Transactional
    public User updateOnboarding(String firebaseUid, OnboardingStatus status) {
        User user = userRepository.findByFirebaseUid(firebaseUid)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        if (user.getOnboardingStatus() == OnboardingStatus.COMPLETED) {
            // Idempotent transition
            return user;
        }

        if (status == OnboardingStatus.COMPLETED) {
            user.setOnboardingStatus(OnboardingStatus.COMPLETED);
            user.setOnboardingCompletedAt(LocalDateTime.now(ZoneOffset.UTC));
            return userRepository.save(user);
        }

        return user;
    }

    @Transactional
    public User updateFcmToken(String firebaseUid, String fcmToken) {
        User user = userRepository.findByFirebaseUid(firebaseUid)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        
        UserDevice device = userDeviceRepository.findByFcmToken(fcmToken)
                .orElseGet(() -> {
                    UserDevice newDevice = new UserDevice();
                    newDevice.setUser(user);
                    newDevice.setFcmToken(fcmToken);
                    newDevice.setPlatform("ANDROID"); // Default platform
                    return newDevice;
                });
        
        device.setLastSeenAt(LocalDateTime.now());
        userDeviceRepository.save(device);
        
        return user;
    }

    private void seedDefaultCategories(User user) {
        List<Category> categoryList = new ArrayList<>();

        // Expense Categories
        categoryList.add(createCategory(user, TransactionType.EXPENSE, "Food", "fastfood", "#E57373"));
        categoryList.add(createCategory(user, TransactionType.EXPENSE, "Transport", "directions_car", "#64B5F6"));
        categoryList.add(createCategory(user, TransactionType.EXPENSE, "Rent", "home", "#81C784"));
        categoryList.add(createCategory(user, TransactionType.EXPENSE, "Utilities", "power", "#FFD54F"));
        categoryList.add(createCategory(user, TransactionType.EXPENSE, "Shopping", "shopping_cart", "#BA68C8"));
        categoryList.add(createCategory(user, TransactionType.EXPENSE, "Entertainment", "movie", "#FF8A65"));

        // Income Categories
        categoryList.add(createCategory(user, TransactionType.INCOME, "Salary", "attach_money", "#4DB6AC"));
        categoryList.add(createCategory(user, TransactionType.INCOME, "Freelance", "work", "#7986CB"));
        categoryList.add(createCategory(user, TransactionType.INCOME, "Investments", "trending_up", "#AED581"));
        categoryList.add(createCategory(user, TransactionType.INCOME, "Gifts", "card_giftcard", "#F06292"));

        categoryRepository.saveAll(categoryList);
    }

    private Category createCategory(User user, TransactionType type, String name, String icon, String color) {
        Category category = new Category();
        category.setUser(user);
        category.setType(type);
        category.setName(name);
        category.setIconKey(icon);
        category.setColorKey(color);
        category.setSystemDefault(true);
        category.setArchived(false);
        return category;
    }
}
