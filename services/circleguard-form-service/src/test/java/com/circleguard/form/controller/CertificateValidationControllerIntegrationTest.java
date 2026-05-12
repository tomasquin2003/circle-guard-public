package com.circleguard.form.controller;

import com.circleguard.form.model.HealthSurvey;
import com.circleguard.form.model.ValidationStatus;
import com.circleguard.form.repository.HealthSurveyRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class CertificateValidationControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private HealthSurveyRepository healthSurveyRepository;

    @MockBean
    private KafkaTemplate<String, Object> kafkaTemplate;

    @Test
    void pendingThenValidate_ListsPendingSurvey_UpdatesStatus_AndPublishesApprovalEvent() throws Exception {
        UUID anonymousId = UUID.randomUUID();
        UUID adminId = UUID.randomUUID();

        HealthSurvey pendingSurvey = healthSurveyRepository.save(HealthSurvey.builder()
                .anonymousId(anonymousId)
                .attachmentPath("certs/pending.pdf")
                .validationStatus(ValidationStatus.PENDING)
                .build());

        healthSurveyRepository.save(HealthSurvey.builder()
                .anonymousId(UUID.randomUUID())
                .attachmentPath("certs/approved.pdf")
                .validationStatus(ValidationStatus.APPROVED)
                .build());

        mockMvc.perform(get("/api/v1/certificates/pending"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(pendingSurvey.getId().toString()))
                .andExpect(jsonPath("$[0].validationStatus").value("PENDING"));

        mockMvc.perform(post("/api/v1/certificates/{id}/validate", pendingSurvey.getId())
                        .param("status", ValidationStatus.APPROVED.name())
                        .param("adminId", adminId.toString()))
                .andExpect(status().isOk());

        HealthSurvey validatedSurvey = healthSurveyRepository.findById(pendingSurvey.getId()).orElseThrow();
        assertThat(validatedSurvey.getValidationStatus()).isEqualTo(ValidationStatus.APPROVED);
        assertThat(validatedSurvey.getValidatedBy()).isEqualTo(adminId);

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> eventCaptor = ArgumentCaptor.forClass(Map.class);
        verify(kafkaTemplate).send(eq("certificate.validated"), eq(anonymousId.toString()), eventCaptor.capture());
        assertThat(eventCaptor.getValue())
                .containsEntry("anonymousId", anonymousId)
                .containsEntry("status", "APPROVED")
                .containsEntry("adminId", adminId);
        assertThat(eventCaptor.getValue()).containsKey("timestamp");
    }
}
