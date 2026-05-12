package com.circleguard.gateway.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.test.util.ReflectionTestUtils;

import java.security.Key;
import java.util.Date;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

public class QrValidationServiceTest {

    private QrValidationService service;
    private StringRedisTemplate redisTemplate;
    private ValueOperations<String, String> valueOps;
    private final String secret = "my-super-secret-test-key-32-chars-long";

    @BeforeEach
    void setUp() {
        redisTemplate = Mockito.mock(StringRedisTemplate.class);
        valueOps = Mockito.mock(ValueOperations.class);
        Mockito.when(redisTemplate.opsForValue()).thenReturn(valueOps);
        
        service = new QrValidationService(redisTemplate);
        ReflectionTestUtils.setField(service, "qrSecret", secret);
    }

    @Test
    void shouldValidateCorrectTokenAndAllowAccess() {
        String anonymousId = UUID.randomUUID().toString();
        Key key = Keys.hmacShaKeyFor(secret.getBytes());
        String token = Jwts.builder()
                .setSubject(anonymousId)
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();

        Mockito.when(valueOps.get("user:status:" + anonymousId)).thenReturn("CLEAR");

        QrValidationService.ValidationResult result = service.validateToken(token);
        
        assertTrue(result.valid());
        assertEquals("GREEN", result.status());
    }

    @Test
    void shouldDenyAccessForContagiedUser() {
        String anonymousId = UUID.randomUUID().toString();
        Key key = Keys.hmacShaKeyFor(secret.getBytes());
        String token = Jwts.builder()
                .setSubject(anonymousId)
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();

        Mockito.when(valueOps.get("user:status:" + anonymousId)).thenReturn("CONTAGIED");

        QrValidationService.ValidationResult result = service.validateToken(token);
        
        assertFalse(result.valid());
        assertEquals("RED", result.status());
    }

    @Test
    void shouldReturnRedForExpiredOrMalformedToken() {
        String anonymousId = UUID.randomUUID().toString();
        Key key = Keys.hmacShaKeyFor(secret.getBytes());
        String expiredToken = Jwts.builder()
                .setSubject(anonymousId)
                .setExpiration(new Date(System.currentTimeMillis() - 1_000))
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();

        QrValidationService.ValidationResult expiredResult = service.validateToken(expiredToken);
        QrValidationService.ValidationResult malformedResult = service.validateToken("not-a-jwt");

        assertFalse(expiredResult.valid());
        assertEquals("RED", expiredResult.status());
        assertEquals("Invalid or Expired Token", expiredResult.message());

        assertFalse(malformedResult.valid());
        assertEquals("RED", malformedResult.status());
        assertEquals("Invalid or Expired Token", malformedResult.message());
    }
}
