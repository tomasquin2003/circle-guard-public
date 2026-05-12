package com.circleguard.gateway.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.security.Key;
import java.time.Duration;
import java.util.Date;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(properties = "qr.secret=my-super-secret-test-key-32-chars-long")
@Testcontainers
class QrValidationServiceRedisIntegrationTest {

    private static final String QR_SECRET = "my-super-secret-test-key-32-chars-long";

    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7.2.1").withExposedPorts(6379);

    @DynamicPropertySource
    static void redisProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.data.redis.host", redis::getHost);
        registry.add("spring.data.redis.port", redis::getFirstMappedPort);
    }

    @Autowired
    private QrValidationService qrValidationService;

    @Autowired
    private StringRedisTemplate redisTemplate;

    @Test
    void validateToken_WithRedisBackedStatuses_DistinguishesGreenFromRedAndInvalid() {
        String clearUser = UUID.randomUUID().toString();
        String riskyUser = UUID.randomUUID().toString();
        redisTemplate.opsForValue().set("user:status:" + clearUser, "CLEAR");
        redisTemplate.opsForValue().set("user:status:" + riskyUser, "POTENTIAL");
        redisTemplate.expire("user:status:" + riskyUser, Duration.ofMinutes(5));

        QrValidationService.ValidationResult clearResult = qrValidationService.validateToken(tokenFor(clearUser, false));
        QrValidationService.ValidationResult riskyResult = qrValidationService.validateToken(tokenFor(riskyUser, false));
        QrValidationService.ValidationResult expiredResult = qrValidationService.validateToken(tokenFor(UUID.randomUUID().toString(), true));
        QrValidationService.ValidationResult malformedResult = qrValidationService.validateToken("not-a-jwt");

        assertThat(clearResult.valid()).isTrue();
        assertThat(clearResult.status()).isEqualTo("GREEN");

        assertThat(riskyResult.valid()).isFalse();
        assertThat(riskyResult.status()).isEqualTo("RED");
        assertThat(riskyResult.message()).contains("Health Risk");

        assertThat(expiredResult.valid()).isFalse();
        assertThat(expiredResult.status()).isEqualTo("RED");
        assertThat(expiredResult.message()).isEqualTo("Invalid or Expired Token");

        assertThat(malformedResult.valid()).isFalse();
        assertThat(malformedResult.status()).isEqualTo("RED");
        assertThat(malformedResult.message()).isEqualTo("Invalid or Expired Token");
    }

    private String tokenFor(String anonymousId, boolean expired) {
        Key key = Keys.hmacShaKeyFor(QR_SECRET.getBytes());
        var builder = Jwts.builder()
                .setSubject(anonymousId)
                .signWith(key, SignatureAlgorithm.HS256);
        if (expired) {
            builder.setExpiration(new Date(System.currentTimeMillis() - 1_000));
        }
        return builder.compact();
    }
}
