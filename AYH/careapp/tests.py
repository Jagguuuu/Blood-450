from django.contrib.auth.models import User
from django.contrib.auth.tokens import default_token_generator
from django.core import mail
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode

from careapp.auth_utils import authenticate_with_identifier
from careapp.models import BloodRequest, DonorProfile, DonorResponse
from careapp.password_reset_service import (
    GENERIC_SUCCESS_MESSAGE,
    send_password_reset_for_email,
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
