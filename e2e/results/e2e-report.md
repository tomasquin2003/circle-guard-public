# CircleGuard E2E Report

## Summary

- Execution date: 2026-05-14 00:56:03
- Suite version: 1.1.0
- Overall result: PASSED
- Smoke checks: 5 passed / 0 failed
- Functional checks: 2 passed / 0 failed / 1 blocked / 1 skipped
- Timeout per HTTP check: 10s

## Smoke / Operational Checks

| # | Check | Endpoint | Container | Docker | HTTP Status | Result |
|---|-------|----------|-----------|--------|-------------|--------|
| 1 | auth-service HTTP reachability | http://localhost:8180/actuator/health | circleguard-auth-service | UP | 404 | PASS |
| 2 | identity-service HTTP reachability | http://localhost:8083/actuator/health | circleguard-identity-service | UP | 401 | PASS |
| 3 | form-service HTTP reachability | http://localhost:8086/actuator/health | circleguard-form-service | UP | 404 | PASS |
| 4 | gateway-service HTTP reachability | http://localhost:8087/actuator/health | circleguard-gateway-service | UP | 404 | PASS |
| 5 | promotion-service + Neo4j health | http://localhost:8088/actuator/health | circleguard-promotion-service | UP | 404 | PASS |

## Functional E2E Checks

| Flow | Endpoint(s) | Status | Classification | Result | Explanation |
|------|-------------|--------|----------------|--------|-------------|
| Identity map/lookup | POST /api/v1/identities/map; GET /api/v1/identities/lookup/e965b58a-a7d1-4e90-897d-feb3d3239648 | BLOCKED_BY_AUTH | BLOCKED_BY_AUTH | DOCUMENTED_NON_CRITICAL | HTTP POST 200 / GET 401 - POST created anonymousId 'e965b58a-a7d1-4e90-897d-feb3d3239648'. Lookup is correctly protected by Spring Security without a JWT containing identity:lookup. |
| Certificates/Form pending list | GET /api/v1/certificates/pending | PASS | PASS | PASS | HTTP 200 - Endpoint returned 200. Pending certificate count: 0. Empty data is valid when no seed surveys exist. |
| Promotion health recovery | POST /api/v1/health/recovery/{id} | SKIPPED_NO_SEED | SKIPPED_NO_SEED | DOCUMENTED_NON_CRITICAL | HTTP N/A - The endpoint exists and is covered by integration tests with Testcontainers, but the running E2E stack has no known seeded Neo4j user id and no HEALTH_CENTER JWT credentials. No synthetic id was invented. |
| Gateway QR validation route | POST /api/v1/gate/validate | PASS | PASS | PASS | HTTP 200 - Route processed a real request and rejected an invalid QR token as RED, proving controller/service path is active. |

## Evidence

### Docker ps snapshot

```
NAMES                              STATUS                   PORTS
circleguard-promotion-service      Up 2 minutes             0.0.0.0:8088->8088/tcp, [::]:8088->8088/tcp
circleguard-form-service           Up 3 minutes             0.0.0.0:8086->8086/tcp, [::]:8086->8086/tcp
circleguard-notification-service   Up 3 minutes             0.0.0.0:8082->8082/tcp, [::]:8082->8082/tcp
circleguard-kafka                  Up 3 minutes             0.0.0.0:9092->9092/tcp, [::]:9092->9092/tcp
circleguard-auth-service           Up 3 minutes             0.0.0.0:8180->8180/tcp, [::]:8180->8180/tcp
circleguard-identity-service       Up 3 minutes             0.0.0.0:8083->8083/tcp, [::]:8083->8083/tcp
circleguard-gateway-service        Up 3 minutes             0.0.0.0:8087->8087/tcp, [::]:8087->8087/tcp
circleguard-postgres               Up 3 minutes             0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
circleguard-redis                  Up 3 minutes             0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp
circleguard-zookeeper              Up 3 minutes             2181/tcp, 2888/tcp, 3888/tcp
circleguard-ldap                   Up 3 minutes             0.0.0.0:389->389/tcp, [::]:389->389/tcp, 0.0.0.0:636->636/tcp, [::]:636->636/tcp
circleguard-neo4j                  Up 3 minutes (healthy)   0.0.0.0:7474->7474/tcp, [::]:7474->7474/tcp, 0.0.0.0:7687->7687/tcp, [::]:7687->7687/tcp
```

### Neo4j health status

- circleguard-neo4j: healthy

### Notification service reachability

- http://localhost:8082/actuator/health: HTTP 404 - reachable
- No functional notification REST endpoint was found in notification-service controllers; the service is Kafka-listener based.

### Endpoints invoked

| Name | Method | URL | HTTP Status | Request body |
|------|--------|-----|-------------|--------------|
| notification-service HTTP reachability (additional smoke evidence) | GET | http://localhost:8082/actuator/health | 404 | (none) |
| Identity map | POST | http://localhost:8083/api/v1/identities/map | 200 | {"realIdentity":"e2e-user@circleguard.test"} |
| Identity lookup | GET | http://localhost:8083/api/v1/identities/lookup/e965b58a-a7d1-4e90-897d-feb3d3239648 | 401 | (none) |
| Certificates pending | GET | http://localhost:8086/api/v1/certificates/pending | 200 | (none) |
| Gateway QR validation | POST | http://localhost:8087/api/v1/gate/validate | 200 | {"token":"e2e-invalid-token"} |

### Non-sensitive request bodies

- Identity map body uses only the synthetic test identity `e2e-user@circleguard.test`.
- Gateway validation body uses an intentionally invalid non-secret token string.
- No real credentials, JWTs, LDAP users or production identifiers are embedded in this suite.

## Limitations

- The smoke checks validate real availability of the local Docker Compose stack.
- The functional checks validate real REST endpoints when auth and seed data make that possible.
- Some flows can be `BLOCKED_BY_AUTH` because Spring Security/JWT protections are active and no seed credentials are available.
- Some flows can be `SKIPPED_NO_SEED` because the running stack has no known seeded business data, such as a Neo4j health user for recovery.
- This suite does not replace Java integration tests, contract tests, security tests or performance tests.
- Kafka and Redis are still validated indirectly through dependent endpoints; deeper broker/cache assertions remain integration-test territory.
- Locust remains pending for the performance-testing part of the workshop.

*Generated by CircleGuard E2E Suite v1.1.0*
