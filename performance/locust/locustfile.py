import os
import uuid

from locust import HttpUser, between, task


GATEWAY_URL = os.getenv("CIRCLEGUARD_GATEWAY_URL", "http://localhost:8087")
IDENTITY_URL = os.getenv("CIRCLEGUARD_IDENTITY_URL", "http://localhost:8083")
FORM_URL = os.getenv("CIRCLEGUARD_FORM_URL", "http://localhost:8086")
PROMOTION_URL = os.getenv("CIRCLEGUARD_PROMOTION_URL", "http://localhost:8088")

SECURITY_STATUSES = {401, 403}


class CircleGuardUser(HttpUser):
    wait_time = between(1, 3)

    def on_start(self):
        self.real_identity = f"locust-user-{uuid.uuid4()}@circleguard.test"
        self.anonymous_id = None

    @task(3)
    def gateway_qr_invalid_token(self):
        payload = {"token": "locust-invalid-token"}

        with self.client.post(
            f"{GATEWAY_URL}/api/v1/gate/validate",
            json=payload,
            name="gateway_qr_invalid_token",
            catch_response=True,
            timeout=5,
        ) as response:
            if self._is_5xx(response):
                return
            if self._mark_security_response(response):
                return
            if response.status_code != 200:
                response.failure(f"Unexpected HTTP {response.status_code}")
                return

            body = self._json(response)
            if body is None:
                return

            status = str(body.get("status", "")).upper()
            message = str(body.get("message", "")).lower()
            valid = body.get("valid")

            if valid is False and (status == "RED" or "invalid" in message):
                response.success()
            else:
                response.failure(f"Invalid QR response body: {body}")

    @task(4)
    def identity_map(self):
        self._map_identity(name="identity_map")

    @task(2)
    def identity_lookup_protected(self):
        if not self.anonymous_id:
            self._map_identity(name="identity_map_setup")

        if not self.anonymous_id:
            return

        with self.client.get(
            f"{IDENTITY_URL}/api/v1/identities/lookup/{self.anonymous_id}",
            name="identity_lookup_protected",
            catch_response=True,
            timeout=5,
        ) as response:
            if self._is_5xx(response):
                return
            if self._mark_security_response(response):
                return
            if response.status_code != 200:
                response.failure(f"Unexpected HTTP {response.status_code}")
                return

            body = self._json(response)
            if body is None:
                return

            if body.get("realIdentity"):
                response.success()
            else:
                response.failure(f"Lookup response missing realIdentity: {body}")

    @task(3)
    def certificates_pending(self):
        with self.client.get(
            f"{FORM_URL}/api/v1/certificates/pending",
            name="certificates_pending",
            catch_response=True,
            timeout=5,
        ) as response:
            if self._is_5xx(response):
                return
            if self._mark_security_response(response):
                return
            if response.status_code != 200:
                response.failure(f"Unexpected HTTP {response.status_code}")
                return

            body = self._json(response)
            if body is None:
                return

            if isinstance(body, list):
                response.success()
            else:
                response.failure(f"Pending certificates response is not a list: {body}")

    @task(1)
    def promotion_health_smoke(self):
        with self.client.get(
            f"{PROMOTION_URL}/api/v1/health-status/stats",
            name="promotion_health_smoke",
            catch_response=True,
            timeout=5,
        ) as response:
            if self._is_5xx(response):
                return
            if self._mark_security_response(response):
                return
            if response.status_code != 200:
                response.failure(f"Unexpected HTTP {response.status_code}")
                return

            body = self._json(response)
            if body is None:
                return

            if "totalUsers" in body and "timestamp" in body:
                response.success()
            else:
                response.failure(f"Promotion stats response missing expected keys: {body}")

    def _map_identity(self, name):
        payload = {"realIdentity": self.real_identity}

        with self.client.post(
            f"{IDENTITY_URL}/api/v1/identities/map",
            json=payload,
            name=name,
            catch_response=True,
            timeout=5,
        ) as response:
            if self._is_5xx(response):
                return
            if response.status_code != 200:
                response.failure(f"Unexpected HTTP {response.status_code}")
                return

            body = self._json(response)
            if body is None:
                return

            anonymous_id = body.get("anonymousId")
            if anonymous_id:
                self.anonymous_id = anonymous_id
                response.success()
            else:
                response.failure(f"Identity map response missing anonymousId: {body}")

    def _json(self, response):
        try:
            return response.json()
        except ValueError:
            response.failure("Expected JSON response body")
            return None

    def _is_5xx(self, response):
        if response.status_code >= 500:
            response.failure(f"Infrastructure/server error HTTP {response.status_code}")
            return True
        return False

    def _mark_security_response(self, response):
        if response.status_code in SECURITY_STATUSES:
            response.success()
            return True
        return False
