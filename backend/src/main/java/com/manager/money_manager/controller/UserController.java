package com.manager.money_manager.controller;

import com.manager.money_manager.dto.FcmTokenUpdateRequest;
import com.manager.money_manager.dto.OnboardingUpdateRequest;
import com.manager.money_manager.dto.SavingsRateUpdateRequest;
import com.manager.money_manager.dto.UserProfileDTO;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.UserService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping("/me")
    public ResponseEntity<UserProfileDTO> getProfile(@RequestAttribute("currentUser") User currentUser) {
        return ResponseEntity.ok(toProfile(currentUser));
    }

    @PatchMapping("/me/onboarding")
    public ResponseEntity<UserProfileDTO> updateOnboarding(
            @Valid @RequestBody OnboardingUpdateRequest request,
            @RequestAttribute("currentUser") User currentUser) {
        User updated = userService.updateOnboarding(currentUser.getFirebaseUid(), request.getStatus());
        return ResponseEntity.ok(toProfile(updated));
    }

    @PatchMapping("/me/fcm-token")
    public ResponseEntity<UserProfileDTO> updateFcmToken(
            @Valid @RequestBody FcmTokenUpdateRequest request,
            @RequestAttribute("currentUser") User currentUser) {
        User updated = userService.updateFcmToken(currentUser.getFirebaseUid(), request.getFcmToken());
        return ResponseEntity.ok(toProfile(updated));
    }

    @PatchMapping("/me/savings-rate")
    public ResponseEntity<UserProfileDTO> updateSavingsRate(
            @Valid @RequestBody SavingsRateUpdateRequest request,
            @RequestAttribute("currentUser") User currentUser) {
        User updated = userService.updateSavingsRate(currentUser.getFirebaseUid(), request.getSavingsRatePercentage());
        return ResponseEntity.ok(toProfile(updated));
    }

    private UserProfileDTO toProfile(User user) {
        UserProfileDTO profile = new UserProfileDTO();
        profile.setId(user.getId());
        profile.setFirebaseUid(user.getFirebaseUid());
        profile.setEmail(user.getEmail());
        profile.setCurrencyCode(user.getCurrencyCode());
        profile.setOnboardingStatus(user.getOnboardingStatus());
        profile.setOnboardingCompletedAt(user.getOnboardingCompletedAt());
        profile.setSavingsRatePercentage(user.getSavingsRatePercentage());
        profile.setCreatedAt(user.getCreatedAt());
        return profile;
    }
}
