package com.manager.money_manager.config;

/**
 * Thread-local context holder for storing authenticated user identity
 * to bind PostgreSQL session configuration for Row Level Security (RLS).
 */
public class UserContextHolder {

    private static final ThreadLocal<String> CURRENT_USER_ID = new ThreadLocal<>();

    public static void setUserId(String userId) {
        CURRENT_USER_ID.set(userId);
    }

    public static String getUserId() {
        return CURRENT_USER_ID.get();
    }

    public static void clear() {
        CURRENT_USER_ID.remove();
    }
}
