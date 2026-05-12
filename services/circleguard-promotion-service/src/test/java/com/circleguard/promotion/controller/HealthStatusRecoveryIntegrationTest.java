package com.circleguard.promotion.controller;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.neo4j.core.Neo4jClient;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.Neo4jContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Duration;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = {
        "spring.flyway.enabled=false",
        "spring.sql.init.mode=never",
        "spring.jpa.hibernate.ddl-auto=create-drop"
})
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Testcontainers
class HealthStatusRecoveryIntegrationTest {

    @Container
    static Neo4jContainer<?> neo4j = new Neo4jContainer<>("neo4j:5.12").withAdminPassword("password");

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("circleguard_promotion")
            .withUsername("admin")
            .withPassword("password");

    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7.2.1").withExposedPorts(6379);

    @DynamicPropertySource
    static void containerProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.neo4j.uri", neo4j::getBoltUrl);
        registry.add("spring.neo4j.authentication.username", () -> "neo4j");
        registry.add("spring.neo4j.authentication.password", () -> "password");
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.datasource.driver-class-name", postgres::getDriverClassName);
        registry.add("spring.data.redis.host", redis::getHost);
        registry.add("spring.data.redis.port", redis::getFirstMappedPort);
    }

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private Neo4jClient neo4jClient;

    @Autowired
    private StringRedisTemplate redisTemplate;

    @MockBean
    private KafkaTemplate<String, Object> kafkaTemplate;

    @BeforeEach
    void setUp() {
        neo4jClient.query("MATCH (n) DETACH DELETE n").run();
        redisTemplate.getConnectionFactory().getConnection().serverCommands().flushAll();
    }

    @Test
    @WithMockUser(roles = "HEALTH_CENTER")
    void recoverEndpoint_WithSecurity_TransitionsUserToRecovered_UpdatesRedis_AndPublishesStatusChange() throws Exception {
        String anonymousId = "recovery-user";
        neo4jClient.query("CREATE (:User {anonymousId: $id, status: 'CONFIRMED', statusUpdatedAt: timestamp()})")
                .bind(anonymousId).to("id")
                .run();

        mockMvc.perform(post("/api/v1/health/recovery/{id}", anonymousId))
                .andExpect(status().isOk());

        String persistedStatus = neo4jClient.query("MATCH (u:User {anonymousId: $id}) RETURN u.status AS status")
                .bind(anonymousId).to("id")
                .fetchAs(String.class)
                .one()
                .orElseThrow();
        assertThat(persistedStatus).isEqualTo("RECOVERED");

        assertThat(redisTemplate.opsForValue().get("user:status:" + anonymousId)).isEqualTo("RECOVERED");
        Long ttlSeconds = redisTemplate.getExpire("user:status:" + anonymousId);
        assertThat(ttlSeconds).isNotNull();
        assertThat(ttlSeconds).isPositive();
        assertThat(ttlSeconds).isLessThanOrEqualTo(Duration.ofDays(30).getSeconds());

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> eventCaptor = ArgumentCaptor.forClass(Map.class);
        verify(kafkaTemplate).send(eq("promotion.status.changed"), eq(anonymousId), eventCaptor.capture());
        assertThat(eventCaptor.getValue())
                .containsEntry("anonymousId", anonymousId)
                .containsEntry("status", "ACTIVE");
        assertThat(eventCaptor.getValue()).containsKey("timestamp");
    }
}
