package com.circleguard.form.service;

import com.circleguard.form.model.HealthSurvey;
import com.circleguard.form.model.Question;
import com.circleguard.form.model.QuestionType;
import com.circleguard.form.model.Questionnaire;
import com.circleguard.form.model.ValidationStatus;
import com.circleguard.form.repository.HealthSurveyRepository;
import com.circleguard.form.repository.QuestionnaireRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;

@SpringBootTest
@ActiveProfiles("test")
class HealthSurveyServiceIntegrationTest {

    @Autowired
    private HealthSurveyService healthSurveyService;

    @Autowired
    private HealthSurveyRepository healthSurveyRepository;

    @Autowired
    private QuestionnaireRepository questionnaireRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockBean
    private KafkaTemplate<String, Object> kafkaTemplate;

    @Test
    void submitSurvey_WithAttachment_PersistsPendingLegacyFieldsAndPublishesEvent() {
        Question feverQuestion = Question.builder()
                .text("Do you have fever today?")
                .type(QuestionType.YES_NO)
                .orderIndex(1)
                .build();

        Questionnaire questionnaire = Questionnaire.builder()
                .title("Daily Health Survey")
                .version(3)
                .isActive(true)
                .questions(List.of(feverQuestion))
                .build();
        feverQuestion.setQuestionnaire(questionnaire);
        Questionnaire savedQuestionnaire = questionnaireRepository.save(questionnaire);
        UUID questionId = savedQuestionnaire.getQuestions().get(0).getId();

        UUID anonymousId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder()
                .anonymousId(anonymousId)
                .responses(Map.of(questionId.toString(), "YES"))
                .attachmentPath("medical/certificate.pdf")
                .build();

        HealthSurvey savedSurvey = healthSurveyService.submitSurvey(survey);
        assertThat(savedSurvey.getValidationStatus()).isEqualTo(ValidationStatus.PENDING);
        assertThat(savedSurvey.getHasFever()).isTrue();
        assertThat(savedSurvey.getHasCough()).isTrue();
        assertThat(savedSurvey.getAttachmentPath()).isEqualTo("medical/certificate.pdf");
        assertThat(healthSurveyRepository.count()).isEqualTo(1);

        Map<String, Object> persistedRow = jdbcTemplate.queryForMap(
                "select validation_status, has_fever, has_cough, attachment_path from health_surveys where id = ?",
                savedSurvey.getId());
        assertThat(String.valueOf(persistedRow.get("validation_status"))).isEqualTo(ValidationStatus.PENDING.name());
        assertThat(persistedRow.get("has_fever")).isEqualTo(true);
        assertThat(persistedRow.get("has_cough")).isEqualTo(true);
        assertThat(persistedRow.get("attachment_path")).isEqualTo("medical/certificate.pdf");

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> eventCaptor = ArgumentCaptor.forClass(Map.class);
        verify(kafkaTemplate).send(eq("survey.submitted"), eq(anonymousId.toString()), eventCaptor.capture());
        assertThat(eventCaptor.getValue())
                .containsEntry("anonymousId", anonymousId)
                .containsEntry("hasSymptoms", true);
        assertThat(eventCaptor.getValue()).containsKey("timestamp");
    }
}
