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
        if (categoryRepository.existsByUserIdAndNameIgnoreCaseAndType(user.getId(), request.getName(), request.getType())) {
            throw new BadRequestException("Category with name '" + request.getName() + "' and type '" + request.getType() + "' already exists.");
        }

        Category category = new Category();
        category.setUser(user);
        category.setType(request.getType());
        category.setName(request.getName());
        category.setIconKey(request.getIconKey());
        category.setColorKey(request.getColorKey());
        category.setSystemDefault(false);
        category.setArchived(false);

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

        // If name or type changes, check for duplicate
        if ((!category.getName().equalsIgnoreCase(request.getName()) || category.getType() != request.getType()) &&
                categoryRepository.existsByUserIdAndNameIgnoreCaseAndType(user.getId(), request.getName(), request.getType())) {
            throw new BadRequestException("Category with name '" + request.getName() + "' and type '" + request.getType() + "' already exists.");
        }

        category.setType(request.getType());
        category.setName(request.getName());
        category.setIconKey(request.getIconKey());
        category.setColorKey(request.getColorKey());

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
        dto.setType(category.getType());
        dto.setName(category.getName());
        dto.setIconKey(category.getIconKey());
        dto.setColorKey(category.getColorKey());
        dto.setArchived(category.isArchived());
        dto.setSystemDefault(category.isSystemDefault());
        return dto;
    }
}
