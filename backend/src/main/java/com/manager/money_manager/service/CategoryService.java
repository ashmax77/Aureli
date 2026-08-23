package com.manager.money_manager.service;

import com.manager.money_manager.dto.CategoryDTO;
import com.manager.money_manager.dto.CreateCategoryRequest;
import com.manager.money_manager.exception.BadRequestException;
import com.manager.money_manager.exception.ResourceNotFoundException;
import com.manager.money_manager.model.Category;
import com.manager.money_manager.model.User;
import com.manager.money_manager.repository.CategoryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional
public class CategoryService {

    private final CategoryRepository categoryRepository;

    public CategoryService(CategoryRepository categoryRepository) {
        this.categoryRepository = categoryRepository;
    }

    public CategoryDTO createCategory(CreateCategoryRequest request, User user) {
        if (categoryRepository.existsByUserIdAndNameIgnoreCase(user.getId(), request.getName())) {
            throw new BadRequestException("Category with name '" + request.getName() + "' already exists.");
        }

        Category category = new Category();
        category.setUser(user);
        category.setName(request.getName());
        category.setBudgetLimit(request.getBudgetLimit());

        Category saved = categoryRepository.save(category);
        return mapToDTO(saved);
    }

    @Transactional(readOnly = true)
    public List<CategoryDTO> getCategories(User user) {
        return categoryRepository.findByUserId(user.getId()).stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public CategoryDTO getCategory(Long id, User user) {
        Category category = categoryRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + id));
        return mapToDTO(category);
    }

    public CategoryDTO updateCategory(Long id, CreateCategoryRequest request, User user) {
        Category category = categoryRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + id));

        // If name changes, check for duplicate name
        if (!category.getName().equalsIgnoreCase(request.getName()) &&
                categoryRepository.existsByUserIdAndNameIgnoreCase(user.getId(), request.getName())) {
            throw new BadRequestException("Category with name '" + request.getName() + "' already exists.");
        }

        category.setName(request.getName());
        category.setBudgetLimit(request.getBudgetLimit());

        Category updated = categoryRepository.save(category);
        return mapToDTO(updated);
    }

    public void deleteCategory(Long id, User user) {
        Category category = categoryRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + id));
        categoryRepository.delete(category);
    }

    private CategoryDTO mapToDTO(Category category) {
        CategoryDTO dto = new CategoryDTO();
        dto.setId(category.getId());
        dto.setName(category.getName());
        dto.setBudgetLimit(category.getBudgetLimit());
        return dto;
    }
}
