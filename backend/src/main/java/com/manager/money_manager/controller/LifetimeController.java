package com.manager.money_manager.controller;

import com.manager.money_manager.dto.AchievementDTO;
import com.manager.money_manager.dto.LifetimeStatsDTO;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.LifetimeService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/lifetime")
public class LifetimeController {

    private final LifetimeService lifetimeService;

    public LifetimeController(LifetimeService lifetimeService) {
        this.lifetimeService = lifetimeService;
    }

    @GetMapping("/stats")
    public ResponseEntity<LifetimeStatsDTO> getStats(
            @RequestAttribute("currentUser") User user,
            @RequestParam(required = false) Integer year) {
        LifetimeStatsDTO stats = lifetimeService.getStats(user, year);
        return ResponseEntity.ok(stats);
    }

    @GetMapping("/achievements")
    public ResponseEntity<List<AchievementDTO>> getAchievements(
            @RequestAttribute("currentUser") User user) {
        List<AchievementDTO> achievements = lifetimeService.getAchievements(user);
        return ResponseEntity.ok(achievements);
    }
}
