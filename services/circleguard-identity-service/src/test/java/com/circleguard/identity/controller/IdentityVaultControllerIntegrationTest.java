package com.circleguard.identity.controller;

import com.circleguard.identity.event.IdentityAccessEvent;
import com.circleguard.identity.model.IdentityMapping;
import com.circleguard.identity.repository.IdentityMappingRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class IdentityVaultControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private IdentityMappingRepository repository;

    @MockBean
    private KafkaTemplate<String, Object> kafkaTemplate;

    @Test
    @WithMockUser(username = "health-admin", authorities = "identity:lookup")
    void mapThenLookup_PersistsMapping_ResolvesIdentity_AndAuditsAccess() throws Exception {
        String realIdentity = "integration-user@circleguard.test";

        String responseBody = mockMvc.perform(post("/api/v1/identities/map")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("realIdentity", realIdentity))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.anonymousId").isNotEmpty())
                .andReturn()
                .getResponse()
                .getContentAsString();

        Map<String, UUID> response = objectMapper.readValue(responseBody, new TypeReference<>() {});
        UUID anonymousId = response.get("anonymousId");

        IdentityMapping mapping = repository.findById(anonymousId).orElseThrow();
        assertThat(mapping.getRealIdentity()).isEqualTo(realIdentity);
        assertThat(mapping.getIdentityHash()).isNotBlank();
        assertThat(mapping.getSalt()).isNotBlank();

        mockMvc.perform(get("/api/v1/identities/lookup/{id}", anonymousId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.realIdentity").value(realIdentity));

        ArgumentCaptor<IdentityAccessEvent> eventCaptor = ArgumentCaptor.forClass(IdentityAccessEvent.class);
        verify(kafkaTemplate).send(eq("audit.identity.accessed"), eventCaptor.capture());

        IdentityAccessEvent event = eventCaptor.getValue();
        assertThat(event.getEventType()).isEqualTo("audit.identity.accessed");
        assertThat(event.getPayload().getAnonymousId()).isEqualTo(anonymousId);
        assertThat(event.getPayload().getRequestingUser()).isEqualTo("health-admin");
        assertThat(event.getPayload().getAccessStatus()).isEqualTo("SUCCESS");
    }
}
