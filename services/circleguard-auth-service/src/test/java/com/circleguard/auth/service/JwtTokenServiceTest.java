package com.circleguard.auth.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JwtTokenServiceTest {

    @Test
    void generateToken_includesSubjectPermissionsAndExpiration() {
        String secret = "my-super-secret-test-key-32-chars-long";
        long expiration = 60_000L;
        JwtTokenService jwtTokenService = new JwtTokenService(secret, expiration);

        UUID anonymousId = UUID.randomUUID();
        Authentication authentication = Mockito.mock(Authentication.class);
        Mockito.doReturn(List.of(new SimpleGrantedAuthority("identity:lookup")))
                .when(authentication)
                .getAuthorities();

        String token = jwtTokenService.generateToken(anonymousId, authentication);

        Claims claims = Jwts.parserBuilder()
                .setSigningKey(secret.getBytes())
                .build()
                .parseClaimsJws(token)
                .getBody();

        assertNotNull(token);
        assertEquals(anonymousId.toString(), claims.getSubject());
        assertEquals(List.of("identity:lookup"), claims.get("permissions", List.class));
        assertNotNull(claims.getIssuedAt());
        assertNotNull(claims.getExpiration());
        assertTrue(claims.getExpiration().after(claims.getIssuedAt()));
    }
}
