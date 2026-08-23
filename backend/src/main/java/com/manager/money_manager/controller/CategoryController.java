package com.manager.money_manager.controller;

import com.manager.money_manager.dto.CategoryDTO;
import com.manager.money_manager.dto.CreateCategoryRequest;
import com.manager.money_manager.model.User;
import com.manager.money_manager.service.CategoryService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/api/v1/categories")
public class CategoryController {

    private final CategoryService categoryService;

    public CategoryController(CategoryService categoryService) {
        this.categoryService = categoryService;
    }

    @PostMapping
    public ResponseEntity<CategoryDTO> createCategory(
            @Valid @RequestBody CreateCategoryRequest request,
            @RequestAttribute("currentUser") User user) {
        CategoryDTO created = categoryService.createCategory(request, user);
        return new ResponseEntity<>(created, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<CategoryDTO>> getCategories(@RequestAttribute("currentUser") User user) {
        List<CategoryDTO> categories = categoryService.getCategories(user);
        return ResponseEntity.ok(categories);
    }

    @GetMapping("/{id}")
    public ResponseEntity<CategoryDTO> getCategory(
            @PathVariable Long id,
            @RequestAttribute("currentUser") User user) {
        CategoryDTO category = categoryService.getCategory(id, user);
        return ResponseEntity.ok(category);
    }

    @PutMapping("/{id}")
    public ResponseEntity<CategoryDTO> updateCategory(
            @PathVariable Long id,
            @Valid @RequestBody CreateCategoryRequest request,
            @RequestAttribute("currentUser") User user) {
        CategoryDTO updated = categoryService.updateCategory(id, request, user);
        return ResponseEntity.ok(updated);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteCategory(
            @PathVariable Long id,
            @RequestAttribute("currentUser") User user) {
        categoryService.deleteCategory(id, user);
        return ResponseEntity.noContent().build();
    }
}
