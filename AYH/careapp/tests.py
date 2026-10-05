from django.contrib.auth.models import User
from django.contrib.auth.tokens import default_token_generator
from django.core import mail
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode

from careapp.auth_utils import authenticate_with_identifier
from careapp.models import (
    AdminNotification,
    BloodRequest,
    DonorProfile,
    DonorResponse,
    UserProfile,
)
from careapp.password_reset_service import (
    GENERIC_SUCCESS_MESSAGE,
    send_password_reset_for_email,
)
from careapp.services.donor_response import (
    CODE_ALREADY_FULFILLED,
    DonorResponseError,
    record_donor_response,
)
from careapp.services.eligibility import (
    STATUS_COOLING_OFF,
    STATUS_ELIGIBLE,
    STATUS_UNKNOWN,
    compute_eligibility,
    sync_last_donation_from_user_profile,
)


@override_settings(
    APP_BASE_URL="https://blood450.example.com",
    EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend",
    DEFAULT_FROM_EMAIL="Blood450 <noreply@blood450.example.com>",
)
class PasswordResetTests(TestCase):
    def setUp(self):
        self.donor = User.objects.create_user(
            username="donor_reset",
            email="donor.reset@example.com",
            password="oldpass12345",
        )
        self.admin = User.objects.create_user(
            username="admin_reset",
            email="admin.reset@example.com",
            password="adminpass12345",
            is_staff=True,
        )
        self.google_user = User.objects.create_user(
            username="google_reset",
            email="google.reset@example.com",
        )
        self.google_user.set_unusable_password()
        self.google_user.save()

    def _api_reset(self, email):
        return self.client.post(
            "/api/auth/password-reset/",
            {"email": email},
            content_type="application/json",
        )

    def test_existing_user_returns_generic_success(self):
        response = self._api_reset("donor.reset@example.com")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["message"], GENERIC_SUCCESS_MESSAGE)

    def test_unknown_email_returns_same_generic_success(self):
        response = self._api_reset("nobody@example.com")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["message"], GENERIC_SUCCESS_MESSAGE)
        self.assertEqual(len(mail.outbox), 0)

    def test_reset_email_generated_for_existing_user(self):
        send_password_reset_for_email("donor.reset@example.com")
        self.assertEqual(len(mail.outbox), 1)
        body = mail.outbox[0].body
        self.assertIn("https://blood450.example.com/accounts/reset/", body)
        self.assertNotIn("localhost", body)

    def _reset_urls(self, user):
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        token = default_token_generator.make_token(user)
        token_url = reverse(
            "password_reset_confirm",
            kwargs={"uidb64": uid, "token": token},
        )
        return uid, token_url

    def _submit_new_password(self, user, new_password):
        uid, token_url = self._reset_urls(user)
        redirect = self.client.get(token_url)
        self.assertEqual(redirect.status_code, 302)
        set_password_url = redirect["Location"]
        form = self.client.get(set_password_url)
        self.assertEqual(form.status_code, 200)
        return self.client.post(
            set_password_url,
            {"new_password1": new_password, "new_password2": new_password},
        )

    def test_reset_token_valid_and_password_changes(self):
        response = self._submit_new_password(self.donor, "newpass12345")
        self.assertEqual(response.status_code, 302)
        self.donor.refresh_from_db()
        self.assertTrue(self.donor.check_password("newpass12345"))
        self.assertFalse(self.donor.check_password("oldpass12345"))

    def test_new_password_login_succeeds(self):
        self.donor.set_password("brandnew12345")
        self.donor.save()
        user = authenticate_with_identifier("donor.reset@example.com", "brandnew12345")
        self.assertIsNotNone(user)

    def test_reset_token_cannot_be_reused(self):
        self._submit_new_password(self.donor, "reuse12345678")
        _, token_url = self._reset_urls(self.donor)
        reuse_get = self.client.get(token_url)
        self.assertEqual(reuse_get.status_code, 200)
        self.assertContains(reuse_get, "Link expired")
        self.donor.refresh_from_db()
        self.assertTrue(self.donor.check_password("reuse12345678"))

    def test_invalid_token_fails(self):
        uid = urlsafe_base64_encode(force_bytes(self.donor.pk))
        url = reverse("password_reset_confirm", kwargs={"uidb64": uid, "token": "bad-token"})
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Link expired")

    def test_google_only_user_receives_reset_email(self):
        sent = send_password_reset_for_email("google.reset@example.com")
        self.assertEqual(sent, 1)
        self.assertEqual(len(mail.outbox), 1)

    def test_google_user_can_establish_password_via_reset(self):
        response = self._submit_new_password(self.google_user, "hybrid12345678")
        self.assertEqual(response.status_code, 302)
        self.google_user.refresh_from_db()
        self.assertTrue(self.google_user.has_usable_password())
        self.assertTrue(self.google_user.check_password("hybrid12345678"))

    def test_admin_reset_works(self):
        response = self._api_reset("admin.reset@example.com")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(mail.outbox), 1)

    def test_no_account_enumeration_in_response(self):
        known = self._api_reset("donor.reset@example.com").json()
        unknown = self._api_reset("missing@example.com").json()
        self.assertEqual(known, unknown)

    def test_api_does_not_return_password_or_token(self):
        response = self._api_reset("donor.reset@example.com")
        data = response.json()
        self.assertNotIn("access", data)
        self.assertNotIn("refresh", data)
        self.assertNotIn("token", data)
        self.assertEqual(set(data.keys()), {"message"})


class LeaderboardTests(TestCase):
    def setUp(self):
        from rest_framework.test import APIClient
        from rest_framework_simplejwt.tokens import RefreshToken

        self.client = APIClient()
        self._refresh_token_cls = RefreshToken

        self.admin = User.objects.create_user(
            username="admin_lb",
            email="admin.lb@example.com",
            password="adminpass12345",
            is_staff=True,
        )
        self.donor_a = User.objects.create_user(
            username="donor_a",
            email="donor.a@example.com",
            password="donorpass12345",
            first_name="Alice",
            last_name="Alpha",
        )
        self.donor_b = User.objects.create_user(
            username="donor_b",
            email="donor.b@example.com",
            password="donorpass12345",
            first_name="Bob",
            last_name="Beta",
        )
        self.donor_c = User.objects.create_user(
            username="donor_c",
            email="donor.c@example.com",
            password="donorpass12345",
            first_name="Carol",
            last_name="Gamma",
        )
        self.no_profile_user = User.objects.create_user(
            username="noprofile",
            email="noprofile@example.com",
            password="noprofile12345",
        )

        self.profile_a = DonorProfile.objects.create(
            user=self.donor_a, phone="9000000001", blood_group="O+"
        )
        self.profile_b = DonorProfile.objects.create(
            user=self.donor_b, phone="9000000002", blood_group="A+"
        )
        self.profile_c = DonorProfile.objects.create(
            user=self.donor_c, phone="9000000003", blood_group="B+"
        )

    def _auth(self, user):
        token = self._refresh_token_cls.for_user(user).access_token
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def _create_request(self):
        return BloodRequest.objects.create(
            blood_group="O+",
            units_needed=1,
            urgency="high",
            created_by=self.admin,
        )

    def _accept(self, donor, blood_request):
        return DonorResponse.objects.create(
            donor=donor,
            blood_request=blood_request,
            response="accepted",
        )

    def _reject(self, donor, blood_request):
        return DonorResponse.objects.create(
            donor=donor,
            blood_request=blood_request,
            response="rejected",
        )

    def test_no_donors_with_donations_returns_empty_top(self):
        self._auth(self.donor_a)
        response = self.client.get("/api/leaderboard/")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["top_donors"], [])
        self.assertEqual(data["current_user"]["donations"], 0)
        self.assertEqual(data["current_user"]["rank"], 1)

    def test_one_completed_contribution_ranks_first(self):
        req = self._create_request()
        self._accept(self.donor_a, req)
        self._auth(self.donor_a)
        response = self.client.get("/api/leaderboard/")
        self.assertEqual(response.status_code, 200)
        top = response.json()["top_donors"]
        self.assertEqual(len(top), 1)
        self.assertEqual(top[0]["rank"], 1)
        self.assertEqual(top[0]["name"], "Alice Alpha")
        self.assertEqual(top[0]["donations"], 1)

    def test_multiple_donors_ranked_descending(self):
        for _ in range(3):
            self._accept(self.donor_a, self._create_request())
        for _ in range(2):
            self._accept(self.donor_b, self._create_request())
        self._accept(self.donor_c, self._create_request())

        self._auth(self.donor_b)
        response = self.client.get("/api/leaderboard/")
        top = response.json()["top_donors"]
        self.assertEqual([d["name"] for d in top], ["Alice Alpha", "Bob Beta", "Carol Gamma"])
        self.assertEqual([d["donations"] for d in top], [3, 2, 1])

    def test_tie_breaking_is_deterministic_by_user_id(self):
        for _ in range(2):
            self._accept(self.donor_a, self._create_request())
            self._accept(self.donor_b, self._create_request())

        self._auth(self.donor_a)
        top = self.client.get("/api/leaderboard/").json()["top_donors"]
        tied = [entry for entry in top if entry["donations"] == 2]
        self.assertEqual(len(tied), 2)
        self.assertLess(tied[0]["rank"], tied[1]["rank"])

    def test_rejected_responses_do_not_count(self):
        req = self._create_request()
        self._reject(self.donor_a, req)
        self._auth(self.donor_a)
        response = self.client.get("/api/leaderboard/")
        self.assertEqual(response.json()["top_donors"], [])
        self.assertEqual(response.json()["current_user"]["donations"], 0)

    def test_current_user_rank_returned_outside_top_ten(self):
        for i in range(11):
            donor = User.objects.create_user(
                username=f"extra_{i}",
                email=f"extra{i}@example.com",
                password="extra12345678",
            )
            DonorProfile.objects.create(user=donor, phone=f"910000{i:04d}", blood_group="O+")
            for _ in range(2):
                self._accept(donor, self._create_request())

        self._accept(self.donor_a, self._create_request())
        self._auth(self.donor_a)
        data = self.client.get("/api/leaderboard/").json()
        self.assertEqual(len(data["top_donors"]), 10)
        self.assertEqual(data["current_user"]["donations"], 1)
        self.assertGreater(data["current_user"]["rank"], 10)

    def test_unauthenticated_request_rejected(self):
        response = self.client.get("/api/leaderboard/")
        self.assertEqual(response.status_code, 401)

    def test_no_private_fields_exposed(self):
        self._accept(self.donor_a, self._create_request())
        self._auth(self.donor_a)
        payload = self.client.get("/api/leaderboard/").json()
        forbidden = {"email", "phone", "password", "user_id", "id", "donor_id"}
        for donor in payload["top_donors"]:
            self.assertTrue(forbidden.isdisjoint(donor.keys()))
        current = payload["current_user"]
        self.assertTrue(forbidden.isdisjoint(current.keys()))

    def test_user_without_donor_profile_has_null_current_user(self):
        self._auth(self.no_profile_user)
        data = self.client.get("/api/leaderboard/").json()
        self.assertIsNone(data["current_user"])


class DonorResponseServiceTests(TestCase):
    """Sprint 1.5 — shared accept/reject fulfillment lifecycle."""

    def setUp(self):
        from rest_framework.test import APIClient
        from rest_framework_simplejwt.tokens import RefreshToken

        self.api = APIClient()
        self._refresh_token_cls = RefreshToken

        self.admin = User.objects.create_user(
            username="admin_resp",
            email="admin.resp@example.com",
            password="adminpass12345",
            is_staff=True,
        )
        self.donor_a = User.objects.create_user(
            username="resp_donor_a",
            email="resp.a@example.com",
            password="donorpass12345",
        )
        self.donor_b = User.objects.create_user(
            username="resp_donor_b",
            email="resp.b@example.com",
            password="donorpass12345",
        )
        DonorProfile.objects.create(
            user=self.donor_a, phone="9111111111", blood_group="O+"
        )
        DonorProfile.objects.create(
            user=self.donor_b, phone="9222222222", blood_group="O+"
        )
        UserProfile.objects.create(user=self.donor_a)
        UserProfile.objects.create(user=self.donor_b)

    def _open_request(self):
        return BloodRequest.objects.create(
            blood_group="O+",
            units_needed=1,
            urgency="high",
            created_by=self.admin,
            status="open",
            is_active=True,
        )

    def _auth_api(self, user):
        token = self._refresh_token_cls.for_user(user).access_token
        self.api.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_first_accept_fulfills_request(self):
        req = self._open_request()
        result = record_donor_response(
            blood_request_id=req.id,
            donor=self.donor_a,
            response_value="accepted",
        )
        req.refresh_from_db()
        self.assertTrue(result.fulfilled)
        self.assertEqual(result.donor_response.response, "accepted")
        self.assertEqual(req.status, "fulfilled")
        self.assertFalse(req.is_active)
        self.assertIsNotNone(req.closed_at)
        self.assertEqual(req.closure_reason, "success")
        self.assertEqual(req.closure_type, "donor")
        self.assertEqual(
            AdminNotification.objects.filter(
                blood_request=req,
                notification_type=AdminNotification.TYPE_DONOR_ACCEPTED,
                donor=self.donor_a,
            ).count(),
            1,
        )

    def test_second_donor_accept_rejected(self):
        req = self._open_request()
        record_donor_response(
            blood_request_id=req.id,
            donor=self.donor_a,
            response_value="accepted",
        )
        with self.assertRaises(DonorResponseError) as ctx:
            record_donor_response(
                blood_request_id=req.id,
                donor=self.donor_b,
                response_value="accepted",
            )
        self.assertEqual(ctx.exception.code, CODE_ALREADY_FULFILLED)
        req.refresh_from_db()
        self.assertEqual(req.status, "fulfilled")
        self.assertEqual(
            DonorResponse.objects.filter(blood_request=req, response="accepted").count(),
            1,
        )
        self.assertFalse(
            DonorResponse.objects.filter(blood_request=req, donor=self.donor_b).exists()
        )

    def test_reject_keeps_request_active(self):
        req = self._open_request()
        result = record_donor_response(
            blood_request_id=req.id,
            donor=self.donor_a,
            response_value="rejected",
        )
        req.refresh_from_db()
        self.assertFalse(result.fulfilled)
        self.assertEqual(result.donor_response.response, "rejected")
        self.assertEqual(req.status, "open")
        self.assertTrue(req.is_active)
        self.assertIsNone(req.closed_at)

    def test_duplicate_response_update_or_create(self):
        req = self._open_request()
        record_donor_response(
            blood_request_id=req.id,
            donor=self.donor_a,
            response_value="rejected",
        )
        # Same donor can change to accept while request still open
        result = record_donor_response(
            blood_request_id=req.id,
            donor=self.donor_a,
            response_value="accepted",
        )
        self.assertFalse(result.created)
        self.assertTrue(result.fulfilled)
        self.assertEqual(
            DonorResponse.objects.filter(blood_request=req, donor=self.donor_a).count(),
            1,
        )

    def test_accept_does_not_modify_last_donation_date(self):
        req = self._open_request()
        donor_profile = self.donor_a.donor_profile
        user_profile = self.donor_a.user_profile
        donor_profile.last_donation_date = None
        donor_profile.save(update_fields=["last_donation_date"])
        user_profile.last_donation_date = None
        user_profile.save(update_fields=["last_donation_date"])

        record_donor_response(
            blood_request_id=req.id,
            donor=self.donor_a,
            response_value="accepted",
        )

        donor_profile.refresh_from_db()
        user_profile.refresh_from_db()
        self.assertIsNone(donor_profile.last_donation_date)
        self.assertIsNone(user_profile.last_donation_date)

    def test_api_accept_uses_shared_service(self):
        req = self._open_request()
        self._auth_api(self.donor_a)
        response = self.api.post(
            "/api/respond/",
            {"blood_request_id": req.id, "response": "accepted"},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json().get("fulfilled"))
        req.refresh_from_db()
        self.assertEqual(req.status, "fulfilled")
        self.assertFalse(req.is_active)

    def test_api_second_accept_returns_error(self):
        req = self._open_request()
        record_donor_response(
            blood_request_id=req.id,
            donor=self.donor_a,
            response_value="accepted",
        )
        self._auth_api(self.donor_b)
        response = self.api.post(
            "/api/respond/",
            {"blood_request_id": req.id, "response": "accepted"},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        body = response.json()
        self.assertEqual(body.get("code"), CODE_ALREADY_FULFILLED)
        self.assertIn("fulfilled", body.get("error", "").lower())

    def test_website_accept_uses_shared_service(self):
        req = self._open_request()
        self.client.force_login(self.donor_a)
        response = self.client.post(
            reverse("donor_respond"),
            data='{"blood_request_id": %d, "response": "accepted"}' % req.id,
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body.get("status"), "ok")
        self.assertTrue(body.get("fulfilled"))
        req.refresh_from_db()
        self.assertEqual(req.status, "fulfilled")
        self.assertFalse(req.is_active)

    def test_website_second_accept_returns_error(self):
        req = self._open_request()
        record_donor_response(
            blood_request_id=req.id,
            donor=self.donor_a,
            response_value="accepted",
        )
        self.client.force_login(self.donor_b)
        response = self.client.post(
            reverse("donor_respond"),
            data='{"blood_request_id": %d, "response": "accepted"}' % req.id,
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)
        body = response.json()
        self.assertEqual(body.get("status"), "error")
        self.assertEqual(body.get("code"), CODE_ALREADY_FULFILLED)


class EligibilityServiceTests(TestCase):
    """Sprint 2 — 90-day eligibility from DonorProfile.last_donation_date."""

    def setUp(self):
        from datetime import date, timedelta

        from rest_framework.test import APIClient
        from rest_framework_simplejwt.tokens import RefreshToken

        self.date = date
        self.timedelta = timedelta
        self.today = date(2026, 9, 28)
        self.api = APIClient()
        self._refresh_token_cls = RefreshToken

        self.user = User.objects.create_user(
            username="elig_donor",
            email="elig@example.com",
            password="donorpass12345",
        )
        self.user_profile = UserProfile.objects.create(user=self.user)
        self.donor = DonorProfile.objects.create(
            user=self.user,
            phone="9333333333",
            blood_group="O+",
        )

    def test_no_last_donation_date_is_unknown(self):
        result = compute_eligibility(None, today=self.today)
        self.assertEqual(result["eligibility_status"], STATUS_UNKNOWN)
        self.assertIsNone(result["days_since_last_donation"])
        self.assertIsNone(result["days_until_eligible"])

    def test_donation_89_days_ago_cooling_off(self):
        last = self.today - self.timedelta(days=89)
        result = compute_eligibility(last, today=self.today)
        self.assertEqual(result["eligibility_status"], STATUS_COOLING_OFF)
        self.assertEqual(result["days_since_last_donation"], 89)
        self.assertEqual(result["days_until_eligible"], 1)

    def test_donation_90_days_ago_eligible(self):
        """Boundary: days_since >= 90 → eligible (exactly 90 days ago is eligible)."""
        last = self.today - self.timedelta(days=90)
        result = compute_eligibility(last, today=self.today)
        self.assertEqual(result["eligibility_status"], STATUS_ELIGIBLE)
        self.assertEqual(result["days_since_last_donation"], 90)
        self.assertEqual(result["days_until_eligible"], 0)

    def test_donation_91_days_ago_eligible(self):
        last = self.today - self.timedelta(days=91)
        result = compute_eligibility(last, today=self.today)
        self.assertEqual(result["eligibility_status"], STATUS_ELIGIBLE)
        self.assertEqual(result["days_since_last_donation"], 91)

    def test_donor_profile_date_is_canonical(self):
        self.donor.last_donation_date = self.today - self.timedelta(days=50)
        self.donor.save(update_fields=["last_donation_date"])
        # UserProfile has a different older date — eligibility uses DonorProfile.
        self.user_profile.last_donation_date = self.today - self.timedelta(days=200)
        self.user_profile.save(update_fields=["last_donation_date"])
        from careapp.services.eligibility import eligibility_for_donor

        result = eligibility_for_donor(self.donor, today=self.today)
        self.assertEqual(result["eligibility_status"], STATUS_COOLING_OFF)
        self.assertEqual(result["days_since_last_donation"], 50)

    def test_userprofile_seeds_empty_donor_date(self):
        seed = self.today - self.timedelta(days=100)
        self.user_profile.last_donation_date = seed
        self.user_profile.save(update_fields=["last_donation_date"])
        self.donor.last_donation_date = None
        self.donor.save(update_fields=["last_donation_date"])
        changed = sync_last_donation_from_user_profile(self.donor, self.user_profile)
        self.assertTrue(changed)
        self.donor.refresh_from_db()
        self.assertEqual(self.donor.last_donation_date, seed)

    def test_existing_donor_date_not_overwritten(self):
        donor_date = self.today - self.timedelta(days=10)
        user_date = self.today - self.timedelta(days=200)
        self.donor.last_donation_date = donor_date
        self.donor.save(update_fields=["last_donation_date"])
        self.user_profile.last_donation_date = user_date
        self.user_profile.save(update_fields=["last_donation_date"])
        changed = sync_last_donation_from_user_profile(self.donor, self.user_profile)
        self.assertFalse(changed)
        self.donor.refresh_from_db()
        self.assertEqual(self.donor.last_donation_date, donor_date)

    def test_accept_does_not_set_last_donation_date(self):
        self.donor.last_donation_date = None
        self.donor.save(update_fields=["last_donation_date"])
        available_before = self.donor.is_available
        req = BloodRequest.objects.create(
            blood_group="O+",
            units_needed=1,
            urgency="high",
            created_by=self.user,
        )
        record_donor_response(
            blood_request_id=req.id,
            donor=self.user,
            response_value="accepted",
        )
        self.donor.refresh_from_db()
        self.assertIsNone(self.donor.last_donation_date)
        self.assertEqual(self.donor.is_available, available_before)

    def test_fulfill_does_not_set_last_donation_date(self):
        # Covered by accept path — fulfill is part of accept service.
        self.donor.last_donation_date = None
        self.donor.save(update_fields=["last_donation_date"])
        req = BloodRequest.objects.create(
            blood_group="O+",
            units_needed=1,
            urgency="medium",
            created_by=self.user,
        )
        record_donor_response(
            blood_request_id=req.id,
            donor=self.user,
            response_value="accepted",
        )
        req.refresh_from_db()
        self.assertEqual(req.status, "fulfilled")
        self.donor.refresh_from_db()
        self.assertIsNone(self.donor.last_donation_date)

    def test_api_exposes_eligibility_status(self):
        self.donor.last_donation_date = self.today - self.timedelta(days=91)
        self.donor.save(update_fields=["last_donation_date"])
        token = self._refresh_token_cls.for_user(self.user).access_token
        self.api.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
        response = self.api.get("/api/donors/me/")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body.get("last_donation_date"), "2026-06-29")
        self.assertEqual(body.get("eligibility_status"), STATUS_ELIGIBLE)
        self.assertIn("days_until_eligible", body)

    def test_create_profile_accepts_last_donation_date(self):
        other = User.objects.create_user(
            username="elig_create",
            email="elig.create@example.com",
            password="donorpass12345",
        )
        token = self._refresh_token_cls.for_user(other).access_token
        self.api.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
        response = self.api.post(
            "/api/donors/",
            {
                "phone": "9444444444",
                "blood_group": "A+",
                "is_available": True,
                "last_donation_date": "2026-01-01",
            },
            format="json",
        )
        self.assertIn(response.status_code, (200, 201))
        body = response.json()
        self.assertEqual(body.get("last_donation_date"), "2026-01-01")
        self.assertEqual(body.get("eligibility_status"), STATUS_ELIGIBLE)
