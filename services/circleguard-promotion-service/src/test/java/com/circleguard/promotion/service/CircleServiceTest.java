package com.circleguard.promotion.service;

import com.circleguard.promotion.model.graph.CircleNode;
import com.circleguard.promotion.model.graph.UserNode;
import com.circleguard.promotion.repository.graph.CircleNodeRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.Set;

import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CircleServiceTest {

    @Mock
    private CircleNodeRepository circleRepository;

    @Mock
    private HealthStatusService healthStatusService;

    @InjectMocks
    private CircleService circleService;

    @Test
    void forceFenceCircle_promotesOnlyActiveMembers() {
        UserNode activeUser = UserNode.builder().anonymousId("ACTIVE-1").status("ACTIVE").build();
        UserNode probableUser = UserNode.builder().anonymousId("PROBABLE-1").status("PROBABLE").build();
        UserNode confirmedUser = UserNode.builder().anonymousId("CONFIRMED-1").status("CONFIRMED").build();

        CircleNode circle = CircleNode.builder()
                .id(10L)
                .name("Risk Group")
                .members(Set.of(activeUser, probableUser, confirmedUser))
                .build();

        when(circleRepository.findById(10L)).thenReturn(Optional.of(circle));

        circleService.forceFenceCircle(10L);

        verify(circleRepository).save(circle);
        verify(healthStatusService).updateStatus("ACTIVE-1", "PROBABLE");
        verify(healthStatusService, never()).updateStatus("PROBABLE-1", "PROBABLE");
        verify(healthStatusService, never()).updateStatus("CONFIRMED-1", "PROBABLE");
    }
}
