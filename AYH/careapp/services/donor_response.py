"""
Canonical donor accept/reject + first-accept request fulfillment.

Website and Flutter API must call this service so both clients share one
request lifecycle. Acceptance fulfills the blood request; it does NOT
record a physical donation (do not touch last_donation_date).
"""
from __future__ import annotations

import logging
from dataclasses import dataclass

from django.db import transaction
from django.utils import timezone

from careapp.models import (
    AdminNotification,
    BloodRequest,
    DonorResponse,
    Notification,
)

logger = logging.getLogger(__name__)

RESPONSE_ACCEPTED = 'accepted'
RESPONSE_REJECTED = 'rejected'
VALID_RESPONSES = frozenset({RESPONSE_ACCEPTED, RESPONSE_REJECTED})

CODE_INVALID_INPUT = 'invalid_input'
CODE_NOT_FOUND = 'not_found'
CODE_ALREADY_FULFILLED = 'already_fulfilled'
CODE_ALREADY_ACCEPTED = 'already_accepted'


class DonorResponseError(Exception):
    """Business-rule failure for donor accept/reject."""

    def __init__(self, message: str, code: str = CODE_INVALID_INPUT):
        super().__init__(message)
        self.message = message
        self.code = code


@dataclass
class DonorResponseResult:
    donor_response: DonorResponse
    created: bool
    blood_request: BloodRequest
    message: str
    fulfilled: bool


def record_donor_response(*, blood_request_id, donor, response_value: str) -> DonorResponseResult:
    """
    Record accept/reject for a donor on a blood request.

    On first valid accept:
      - DonorResponse = accepted
      - BloodRequest status = fulfilled, is_active = False
      - closed_at / closure_reason=success / closure_type=donor
      - AdminNotification TYPE_DONOR_ACCEPTED

    Does NOT update DonorProfile.last_donation_date or UserProfile.last_donation_date.
    """
    if not blood_request_id or not response_value:
        raise DonorResponseError(
            'blood_request_id and response are required',
            code=CODE_INVALID_INPUT,
        )
    if response_value not in VALID_RESPONSES:
        raise DonorResponseError(
            'response must be "accepted" or "rejected"',
            code=CODE_INVALID_INPUT,
        )
    if donor is None or not getattr(donor, 'is_authenticated', True) or not getattr(donor, 'pk', None):
        raise DonorResponseError('Authentication required', code=CODE_INVALID_INPUT)

    with transaction.atomic():
        try:
            blood_request = (
                BloodRequest.objects.select_for_update()
                .get(pk=blood_request_id)
            )
        except BloodRequest.DoesNotExist as exc:
            raise DonorResponseError(
                'Blood request not found',
                code=CODE_NOT_FOUND,
            ) from exc

        if response_value == RESPONSE_ACCEPTED:
            if blood_request.status == 'fulfilled' or not blood_request.is_active:
                raise DonorResponseError(
                    'This request has already been fulfilled.',
                    code=CODE_ALREADY_FULFILLED,
                )
            other_accepted = (
                DonorResponse.objects.select_for_update()
                .filter(blood_request=blood_request, response=RESPONSE_ACCEPTED)
                .exclude(donor=donor)
                .exists()
            )
            if other_accepted:
                raise DonorResponseError(
                    'This request has already been fulfilled.',
                    code=CODE_ALREADY_ACCEPTED,
                )

        donor_response, created = DonorResponse.objects.update_or_create(
            blood_request=blood_request,
            donor=donor,
            defaults={'response': response_value},
        )

        fulfilled = False
        if response_value == RESPONSE_ACCEPTED:
            blood_request.status = 'fulfilled'
            blood_request.is_active = False
            blood_request.closed_at = timezone.now()
            blood_request.closure_reason = 'success'
            blood_request.closure_type = 'donor'
            blood_request.save(
                update_fields=[
                    'status',
                    'is_active',
                    'closed_at',
                    'closure_reason',
                    'closure_type',
                ]
            )
            fulfilled = True
            AdminNotification.objects.create(
                notification_type=AdminNotification.TYPE_DONOR_ACCEPTED,
                blood_request=blood_request,
                donor=donor,
            )

        Notification.objects.filter(
            user=donor,
            blood_request=blood_request,
        ).update(is_read=True)

    # Pool updates (standby promotion on reject) — best-effort, outside lock
    try:
        from careapp.donor_pool_service import handle_donor_response_for_pool

        handle_donor_response_for_pool(
            blood_request.id,
            donor.id,
            response_value == RESPONSE_ACCEPTED,
        )
    except Exception:
        logger.exception(
            'donor_response: pool update failed request_id=%s donor_id=%s',
            blood_request_id,
            getattr(donor, 'id', None),
        )

    action = 'created' if created else 'updated'
    if fulfilled:
        message = (
            f'Response {action} successfully. '
            'You are accepted for this blood request; the request is now fulfilled.'
        )
    else:
        message = f'Response {action} successfully'

    return DonorResponseResult(
        donor_response=donor_response,
        created=created,
        blood_request=blood_request,
        message=message,
        fulfilled=fulfilled,
    )
