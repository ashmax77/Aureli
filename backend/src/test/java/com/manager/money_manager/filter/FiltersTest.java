package com.manager.money_manager.filter;

import com.manager.money_manager.model.User;
import com.manager.money_manager.service.UserService;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;

class FiltersTest {

    private final FirebaseAuthFilter authFilter = new FirebaseAuthFilter(mock(UserService.class));

    private boolean passedThrough(MockFilterChain chain) {
        return chain.getRequest() != null;
    }

    @Test
    void authFilter_missingAuthorizationHeader_returns401AndBlocksChain() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        authFilter.doFilter(new MockHttpServletRequest("GET", "/api/v1/me"), response, chain);

        assertEquals(401, response.getStatus());
        assertFalse(passedThrough(chain));
    }

    @Test
    void authFilter_nonBearerScheme_returns401() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/me");
        request.addHeader("Authorization", "Basic abc");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        authFilter.doFilter(request, response, chain);

        assertEquals(401, response.getStatus());
        assertFalse(passedThrough(chain));
    }

    @Test
    void authFilter_healthEndpointIsPublic() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        authFilter.doFilter(new MockHttpServletRequest("GET", "/api/health"), response, chain);

        assertEquals(200, response.getStatus());
        assertTrue(passedThrough(chain));
    }

    @Test
    void authFilter_pathMerelyPrefixedWithHealthIsNotPublic() throws Exception {
        for (String path : new String[]{"/api/healthz/../v1/me", "/api/health-anything", "/api/health/../v1/me"}) {
            MockHttpServletResponse response = new MockHttpServletResponse();
            MockFilterChain chain = new MockFilterChain();

            authFilter.doFilter(new MockHttpServletRequest("GET", path), response, chain);

            assertEquals(401, response.getStatus(), path);
            assertFalse(passedThrough(chain), path);
        }
    }

    @Test
    void rateLimit_rejectsSixtyFirstRequestPerUserWithoutAffectingOthers() throws Exception {
        RateLimitFilter filter = new RateLimitFilter();
        User alice = userWithUid("alice");

        for (int i = 1; i <= 60; i++) {
            assertEquals(200, send(filter, "/api/v1/transactions", alice), "request " + i);
        }
        assertEquals(429, send(filter, "/api/v1/transactions", alice));
        assertEquals(200, send(filter, "/api/v1/transactions", userWithUid("bob")));
    }

    @Test
    void rateLimit_healthEndpointIsExemptButLookalikePathIsLimited() throws Exception {
        RateLimitFilter filter = new RateLimitFilter();
        User alice = userWithUid("alice");
        for (int i = 0; i < 60; i++) {
            send(filter, "/api/v1/transactions", alice);
        }

        assertEquals(200, send(filter, "/api/health", null));
        assertEquals(429, send(filter, "/api/health-anything", alice));
    }

    private int send(RateLimitFilter filter, String path, User user) throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", path);
        if (user != null) {
            request.setAttribute("currentUser", user);
        }
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(request, response, new MockFilterChain());
        return response.getStatus();
    }

    private User userWithUid(String uid) {
        User user = new User();
        user.setFirebaseUid(uid);
        return user;
    }
}
