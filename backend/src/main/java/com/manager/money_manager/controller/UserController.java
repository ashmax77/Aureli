package com.manager.money_manager.controller;

import com.manager.money_manager.model.User;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class UserController {

    @GetMapping("/me")
    public ResponseEntity<User> getProfile(@RequestAttribute("currentUser") User currentUser) {
        return ResponseEntity.ok(currentUser);
    }
}
