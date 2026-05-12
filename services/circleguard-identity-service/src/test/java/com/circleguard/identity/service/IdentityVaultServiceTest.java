package com.circleguard.identity.service;

import com.circleguard.identity.model.IdentityMapping;
import com.circleguard.identity.repository.IdentityMappingRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class IdentityVaultServiceTest {

    @Mock
    private IdentityMappingRepository repository;

    private IdentityVaultService service;

    @BeforeEach
    void setUp() {
        service = new IdentityVaultService(repository);
        ReflectionTestUtils.setField(service, "hashSalt", "test-hash-salt");
    }

    @Test
    void getOrCreateAnonymousId_whenHashExists_returnsExistingIdWithoutDuplicateSave() {
        String realIdentity = "user@example.com";
        UUID existingId = UUID.randomUUID();
        IdentityMapping mapping = IdentityMapping.builder()
                .anonymousId(existingId)
                .realIdentity(realIdentity)
                .identityHash("existing-hash")
                .salt("salt123")
                .build();

        when(repository.findByIdentityHash(MockitoHelper.sha256(realIdentity + "test-hash-salt")))
                .thenReturn(Optional.of(mapping));

        UUID result = service.getOrCreateAnonymousId(realIdentity);

        assertEquals(existingId, result);
        verify(repository, never()).save(org.mockito.ArgumentMatchers.any(IdentityMapping.class));
    }

    private static final class MockitoHelper {
        private static String sha256(String value) {
            try {
                java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
                return java.util.HexFormat.of().formatHex(digest.digest(value.getBytes()));
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }
    }
}
