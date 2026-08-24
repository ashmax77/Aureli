package com.manager.money_manager.service;

// import com.manager.money_manager.model.Category;
import com.manager.money_manager.model.OnboardingStatus;
// import com.manager.money_manager.model.TransactionType;
import com.manager.money_manager.model.User;
import com.manager.money_manager.repository.CategoryRepository;
import com.manager.money_manager.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
// import java.util.List;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private CategoryRepository categoryRepository;

    @InjectMocks
    private UserService userService;

    private User user;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setFirebaseUid("uid_123");
        user.setEmail("test@example.com");
        user.setOnboardingStatus(OnboardingStatus.NOT_STARTED);
    }

    @Test
    void findOrCreateUser_existingUser_returnsUserWithoutSeeding() {
        when(userRepository.findByFirebaseUid("uid_123")).thenReturn(Optional.of(user));

        User result = userService.findOrCreateUser("uid_123", "test@example.com");

        assertNotNull(result);
        assertEquals("uid_123", result.getFirebaseUid());
        verify(userRepository, never()).saveAndFlush(any(User.class));
        verify(categoryRepository, never()).saveAll(anyList());
    }

    @Test
    void findOrCreateUser_newUser_createsUserAndSeedsCategories() {
        when(userRepository.findByFirebaseUid("uid_123")).thenReturn(Optional.empty());
        when(userRepository.saveAndFlush(any(User.class))).thenReturn(user);

        User result = userService.findOrCreateUser("uid_123", "test@example.com");

        assertNotNull(result);
        assertEquals("uid_123", result.getFirebaseUid());
        verify(userRepository, times(1)).saveAndFlush(any(User.class));
        verify(categoryRepository, times(1)).saveAll(anyList());
    }

    @Test
    void findOrCreateUser_concurrentRegistration_reFetchesAndReturnsUser() {
        when(userRepository.findByFirebaseUid("uid_123"))
                .thenReturn(Optional.empty()) // First check: doesn't exist
                .thenReturn(Optional.of(user)); // Re-fetch query after violation: exists!

        // Mock unique key constraint failure
        when(userRepository.saveAndFlush(any(User.class)))
                .thenThrow(new DataIntegrityViolationException("Duplicate key violation on firebase_uid"));

        User result = userService.findOrCreateUser("uid_123", "test@example.com");

        assertNotNull(result);
        assertEquals("uid_123", result.getFirebaseUid());
        verify(userRepository, times(1)).saveAndFlush(any(User.class));
        verify(categoryRepository, never()).saveAll(anyList()); // Seeding skipped because we recovered from conflict
    }

    @Test
    void updateOnboarding_statusCompleted_updatesStatusAndDate() {
        when(userRepository.findByFirebaseUid("uid_123")).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        User result = userService.updateOnboarding("uid_123", OnboardingStatus.COMPLETED);

        assertNotNull(result);
        assertEquals(OnboardingStatus.COMPLETED, result.getOnboardingStatus());
        assertNotNull(result.getOnboardingCompletedAt());
        verify(userRepository, times(1)).save(user);
    }

    @Test
    void updateOnboarding_alreadyCompleted_isIdempotent() {
        user.setOnboardingStatus(OnboardingStatus.COMPLETED);
        when(userRepository.findByFirebaseUid("uid_123")).thenReturn(Optional.of(user));

        User result = userService.updateOnboarding("uid_123", OnboardingStatus.COMPLETED);

        assertNotNull(result);
        assertEquals(OnboardingStatus.COMPLETED, result.getOnboardingStatus());
        verify(userRepository, never()).save(any(User.class)); // Saved check skipped (idempotent)
    }
}
