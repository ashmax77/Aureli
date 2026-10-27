package com.manager.money_manager.repository;

import com.manager.money_manager.model.AppNotification;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<AppNotification, Long> {

    List<AppNotification> findByUserIdOrderByCreatedAtDesc(Long userId);

    Page<AppNotification> findByUserId(Long userId, Pageable pageable);

    long countByUserIdAndIsReadFalse(Long userId);
}
