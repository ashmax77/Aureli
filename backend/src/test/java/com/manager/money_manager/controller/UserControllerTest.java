package com.manager.money_manager.controller;

import com.manager.money_manager.dto.FcmTokenUpdateRequest;
import com.manager.money_manager.dto.OnboardingUpdateRequest;
import com.manager.money_manager.model.OnboardingStatus;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserControllerTest {

    @Mock
    private UserService userService;

    @InjectMocks
    private UserController userController;

    private User user;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setFirebaseUid("uid_123");
        user.setEmail("user@example.com");
        user.setOnboardingStatus(OnboardingStatus.NOT_STARTED);
    }

    @Test
    void getProfile_success() {
        ResponseEntity<User> response = userController.getProfile(user);
        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        assertEquals("uid_123", response.getBody().getFirebaseUid());
    }

    @Test
    void updateOnboarding_success() {
        OnboardingUpdateRequest request = new OnboardingUpdateRequest();
        request.setStatus(OnboardingStatus.COMPLETED);

        User updatedUser = new User();
        updatedUser.setId(1L);
        updatedUser.setOnboardingStatus(OnboardingStatus.COMPLETED);

        when(userService.updateOnboarding("uid_123", OnboardingStatus.COMPLETED)).thenReturn(updatedUser);

        ResponseEntity<User> response = userController.updateOnboarding(request, user);

        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        assertEquals(OnboardingStatus.COMPLETED, response.getBody().getOnboardingStatus());
    }

    @Test
    void updateFcmToken_success() {
        FcmTokenUpdateRequest request = new FcmTokenUpdateRequest();
        request.setFcmToken("fcm_token_xyz");

        when(userService.updateFcmToken("uid_123", "fcm_token_xyz")).thenReturn(user);

        ResponseEntity<User> response = userController.updateFcmToken(request, user);

        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        verify(userService, times(1)).updateFcmToken("uid_123", "fcm_token_xyz");
    }
}
