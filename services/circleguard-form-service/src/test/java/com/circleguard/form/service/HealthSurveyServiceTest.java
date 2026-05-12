package com.circleguard.form.service;

import com.circleguard.form.model.HealthSurvey;
import com.circleguard.form.model.Questionnaire;
import com.circleguard.form.model.ValidationStatus;
import com.circleguard.form.repository.HealthSurveyRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.kafka.core.KafkaTemplate;

import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class HealthSurveyServiceTest {

    @Mock
    private HealthSurveyRepository repository;

    @Mock
    private QuestionnaireService questionnaireService;

    @Mock
    private SymptomMapper symptomMapper;

    @Mock
    private KafkaTemplate<String, Object> kafkaTemplate;

    @InjectMocks
    private HealthSurveyService healthSurveyService;

    @Test
    void submitSurvey_withAttachment_setsPendingAndPublishesSurveySubmitted() {
        UUID anonymousId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder()
                .anonymousId(anonymousId)
                .attachmentPath("certificates/test.pdf")
                .build();
        Questionnaire questionnaire = Questionnaire.builder().build();

        when(questionnaireService.getActiveQuestionnaire()).thenReturn(Optional.of(questionnaire));
        when(symptomMapper.hasSymptoms(survey, questionnaire)).thenReturn(false);
        when(repository.save(any(HealthSurvey.class))).thenAnswer(invocation -> invocation.getArgument(0));

        HealthSurvey saved = healthSurveyService.submitSurvey(survey);

        ArgumentCaptor<Map<String, Object>> eventCaptor = ArgumentCaptor.forClass(Map.class);

        assertEquals(ValidationStatus.PENDING, saved.getValidationStatus());
        assertFalse(saved.getHasFever());
        assertFalse(saved.getHasCough());

        verify(repository).save(survey);
        verify(kafkaTemplate).send(eq("survey.submitted"), eq(anonymousId.toString()), eventCaptor.capture());
        assertEquals(anonymousId, eventCaptor.getValue().get("anonymousId"));
        assertEquals(false, eventCaptor.getValue().get("hasSymptoms"));
        assertTrue(eventCaptor.getValue().containsKey("timestamp"));
    }
}
