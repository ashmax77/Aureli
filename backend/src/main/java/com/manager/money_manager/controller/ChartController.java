package com.manager.money_manager.controller;

import com.manager.money_manager.dto.CategoryBreakdownDTO;
import com.manager.money_manager.dto.MonthlyTrendDTO;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.ChartService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/v1/charts")
public class ChartController {

    private final ChartService chartService;

    public ChartController(ChartService chartService) {
        this.chartService = chartService;
    }

    @GetMapping("/monthly-trends")
    public ResponseEntity<List<MonthlyTrendDTO>> getMonthlyTrends(
            @RequestAttribute("currentUser") User user,
            @RequestParam(defaultValue = "6") int limit) {
        List<MonthlyTrendDTO> trends = chartService.getMonthlyTrends(user, limit);
        return ResponseEntity.ok(trends);
    }

    @GetMapping("/category-breakdown")
    public ResponseEntity<List<CategoryBreakdownDTO>> getCategoryBreakdown(
            @RequestAttribute("currentUser") User user,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer month) {
        List<CategoryBreakdownDTO> breakdown = chartService.getCategoryBreakdown(user, year, month);
        return ResponseEntity.ok(breakdown);
    }
}
