package com.manager.money_manager.controller;

import com.manager.money_manager.dto.OnboardingUpdateRequest;
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
    public ResponseEntity<User> getProfile(@RequestAttribute("currentUser") User currentUser) {
        return ResponseEntity.ok(currentUser);
    }

    @PatchMapping("/me/onboarding")
    public ResponseEntity<User> updateOnboarding(
            @Valid @RequestBody OnboardingUpdateRequest request,
            @RequestAttribute("currentUser") User currentUser) {
        User updated = userService.updateOnboarding(currentUser.getFirebaseUid(), request.getStatus());
        return ResponseEntity.ok(updated);
    }
}
