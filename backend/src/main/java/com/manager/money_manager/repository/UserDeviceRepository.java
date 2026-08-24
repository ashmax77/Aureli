package com.manager.money_manager.repository;

import com.manager.money_manager.model.UserDevice;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface UserDeviceRepository extends JpaRepository<UserDevice, Long> {
    Optional<UserDevice> findByFcmToken(String fcmToken);
    List<UserDevice> findByUserId(Long userId);
    void deleteByFcmToken(String fcmToken);
}
