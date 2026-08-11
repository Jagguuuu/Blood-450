from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required, user_passes_test
from django.contrib.auth import login
from django.contrib.auth.models import User
from django.contrib import messages
from django.utils.crypto import get_random_string
from urllib.parse import urlencode
from django.http import JsonResponse, HttpResponseRedirect
from django.urls import reverse
from django.views.decorators.http import require_http_methods
from django.views.decorators.csrf import ensure_csrf_cookie
from django.db import IntegrityError, transaction
from django.db.models import Count
from django.db.models.functions import TruncDate
from django.utils import timezone
from django.utils.dateparse import parse_date
from datetime import timedelta
from django.conf import settings as django_settings
from decimal import Decimal
import json
import logging
import os
import random
import uuid
from datetime import timedelta

from django.contrib.auth.views import LoginView

from .excel_analytics import read_excel_to_dataframe, build_charts_and_summary
from .models import (
    BloodRequest, DonorProfile, UserProfile, Notification, DonorResponse,
    AdminNotification, RequestTimeline, EtaTracking, DelayReason, DonorAssignment, FallbackAction,
    RadiusExpansionLog, BloodBankMaster, HospitalMaster, HospitalMetrics, DimCity,
    RequestDonorPoolAssignment, DonorOTP,
)
from .forms import DonorRegistrationForm, DonorLoginForm
from .utils import haversine_km, donor_has_location

logger = logging.getLogger(__name__)
DEFAULT_RADIUS_KM = getattr(django_settings, 'DEFAULT_RADIUS_KM', 10)




# Blood compatibility matrix - who can donate to whom
BLOOD_COMPATIBILITY = {
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'A-': ['A-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],  # Universal receiver
    'AB-': ['A-', 'B-', 'AB-', 'O-'],
    'O+': ['O+', 'O-'],
    'O-': ['O-'],  # Universal donor
}


def get_compatible_blood_groups(requested_blood_group):
    """
    Returns list of blood groups that can donate to the requested blood group.
    
    Args:
        requested_blood_group: The blood group needed (e.g., 'A+')
    
    Returns:
        List of compatible donor blood groups
    """
    return BLOOD_COMPATIBILITY.get(requested_blood_group, [requested_blood_group])


def is_staff_user(user):
    """Check if user is staff"""
    return user.is_staff


@login_required
def home_redirect(request):
    """Redirect user to appropriate page based on their role"""
    if request.user.is_staff:
        return redirect('admin_dashboard')
    else:
        return redirect('donor_notifications')


@login_required
@user_passes_test(is_staff_user)
@ensure_csrf_cookie
def admin_dashboard(request):
    """Admin dashboard with statistics, all requests, and master data (hospitals, blood banks, cities)."""
    # Get recent blood requests for dashboard display
    blood_requests_qs = BloodRequest.objects.all()
    blood_requests = blood_requests_qs.prefetch_related(
        'responses', 'notifications', 'delay_reasons', 'delay_reasons__reported_by', 'delay_reasons__reported_by__donor_profile'
    ).order_by('-created_at')[:50]
    
    # Get recent donors for dashboard display
    donors_qs = DonorProfile.objects.select_related('user')
    donors = donors_qs.order_by('-created_at')[:200]
    
    # Master data counts and recent lists (saved backend data)
    total_hospitals = HospitalMaster.objects.count()
    total_blood_banks = BloodBankMaster.objects.count()
    total_cities = DimCity.objects.count()
    recent_hospitals = HospitalMaster.objects.all().order_by('hospital_name')
    recent_blood_banks = BloodBankMaster.objects.all().order_by('name')
    recent_cities = DimCity.objects.all().order_by('state', 'city')
    
    # Calculate statistics
    total_requests = blood_requests_qs.count()
    total_donors = donors_qs.count()
    total_accepted = DonorResponse.objects.filter(response='accepted').count()
    active_requests = blood_requests_qs.filter(is_active=True).count()
    
    # Chart data: requests by urgency (for pie chart)
    urgency_counts = dict(
        BloodRequest.objects.values('urgency').annotate(count=Count('id')).values_list('urgency', 'count')
    )
    chart_urgency = {
        'labels': ['Critical', 'High', 'Medium'],
        'data': [
            urgency_counts.get('critical', 0),
            urgency_counts.get('high', 0),
            urgency_counts.get('medium', 0),
        ],
    }
    
    # Chart data: requests by blood group (for bar chart)
    bg_counts = list(
        BloodRequest.objects.values('blood_group').annotate(count=Count('id')).order_by('blood_group')
    )
    all_bgs = [bg[0] for bg in DonorProfile.BLOOD_GROUP_CHOICES]
    bg_map = {r['blood_group']: r['count'] for r in bg_counts}
    chart_blood_groups = {
        'labels': all_bgs,
        'data': [bg_map.get(bg, 0) for bg in all_bgs],
    }
    
    # Line/curve chart: requests per day (last 14 days)
    start_date = timezone.now().date() - timedelta(days=14)
    daily = (
        BloodRequest.objects.filter(created_at__date__gte=start_date)
        .annotate(day=TruncDate('created_at'))
        .values('day')
        .annotate(count=Count('id'))
        .order_by('day')
    )
    day_map = {r['day'].strftime('%Y-%m-%d'): r['count'] for r in daily}
    days_labels = [(start_date + timedelta(days=i)).strftime('%m/%d') for i in range(15)]
    days_data = [
        day_map.get((start_date + timedelta(days=i)).strftime('%Y-%m-%d'), 0)
        for i in range(15)
    ]
    chart_requests_over_time = {'labels': days_labels, 'data': days_data}
    
    # Scatter: request index vs response count and units needed
    response_counts = dict(
        DonorResponse.objects.values('blood_request_id')
        .annotate(count=Count('id'))
        .values_list('blood_request_id', 'count')
    )
    requests_list = list(blood_requests_qs.order_by('-created_at').values('id', 'units_needed')[:50])
    chart_scatter = {
        'x': list(range(1, len(requests_list) + 1)),
        'y_responses': [response_counts.get(r['id'], 0) for r in requests_list],
        'y_units': [r['units_needed'] for r in requests_list],
    }
    
    # Donors by blood group (2D horizontal bar)
    donor_bg = list(
        DonorProfile.objects.values('blood_group')
        .annotate(count=Count('id'))
        .order_by('blood_group')
    )
    donor_bg_map = {r['blood_group']: r['count'] for r in donor_bg}
    chart_donors_blood = {
        'labels': all_bgs,
        'data': [donor_bg_map.get(bg, 0) for bg in all_bgs],
    }
    
    # If just created a request, show summary for modal (notified donors with name, blood group, phone, status)
    created_request_id = request.GET.get('created_request_id')
    created_notified_count = None
    created_accepted_count = None
    created_accepted_list = []
    created_notified_list = []
    created_request_obj = None
    if created_request_id:
        try:
            created_request_obj = BloodRequest.objects.get(id=int(created_request_id))
            created_notified_count = Notification.objects.filter(blood_request=created_request_obj).count()
            accepted = DonorResponse.objects.filter(
                blood_request=created_request_obj,
                response='accepted'
            ).select_related('donor', 'donor__donor_profile')
            created_accepted_count = accepted.count()
            created_accepted_list = [
                {'username': r.donor.username, 'blood_group': getattr(r.donor.donor_profile, 'blood_group', None)}
                for r in accepted
            ]
            response_by_donor = dict(
                DonorResponse.objects.filter(blood_request=created_request_obj).values_list('donor_id', 'response')
            )
            for notif in Notification.objects.filter(blood_request=created_request_obj).select_related('user', 'user__donor_profile'):
                status_key = response_by_donor.get(notif.user_id)
                status_display = 'Accepted' if status_key == 'accepted' else ('Declined' if status_key == 'rejected' else 'Pending')
                try:
                    profile = notif.user.donor_profile
                    blood_grp = getattr(profile, 'blood_group', None)
                    phone = getattr(profile, 'phone', None) or '—'
                except (DonorProfile.DoesNotExist, AttributeError):
                    blood_grp = None
                    phone = '—'
                created_notified_list.append({
                    'donor_id': notif.user_id,
                    'username': notif.user.username,
                    'blood_group': blood_grp,
                    'phone': phone,
                    'status': status_display,
                    'status_key': status_key or 'pending',
                })
        except (BloodRequest.DoesNotExist, ValueError):
            created_request_id = None

    context = {
        'blood_requests': blood_requests,
        'donors': donors,
        'total_requests': total_requests,
        'total_donors': total_donors,
        'total_accepted': total_accepted,
        'active_requests': active_requests,
        'total_hospitals': total_hospitals,
        'total_blood_banks': total_blood_banks,
        'total_cities': total_cities,
        'recent_hospitals': recent_hospitals,
        'recent_blood_banks': recent_blood_banks,
        'recent_cities': recent_cities,
        'blood_groups': DonorProfile.BLOOD_GROUP_CHOICES,
        'chart_urgency': chart_urgency,
        'chart_blood_groups': chart_blood_groups,
        'chart_requests_over_time': chart_requests_over_time,
        'chart_scatter': chart_scatter,
        'chart_donors_blood': chart_donors_blood,
        'hospitals': recent_hospitals,
        'cities': list(DimCity.objects.all().order_by('state', 'city')),
        'created_request_id': created_request_id,
        'created_request_obj': created_request_obj,
        'created_notified_count': created_notified_count,
        'created_accepted_count': created_accepted_count,
        'created_accepted_list': created_accepted_list,
        'created_notified_list': created_notified_list,
    }
    return render(request, 'admin_dashboard.html', context)


def _parse_float(val, default=None):
    """Parse float from POST/value; return default if empty or invalid. Accepts comma as decimal separator."""
    if val is None:
        return default
    s = str(val).strip()
    if s == '':
        return default
    # Allow comma as decimal separator (e.g. 17,47 -> 17.47)
    if ',' in s and '.' not in s:
        s = s.replace(',', '.', 1)
    try:
        return float(s)
    except (ValueError, TypeError):
        return default


@login_required
@user_passes_test(is_staff_user)
@ensure_csrf_cookie
@transaction.atomic
def admin_create_request(request):
    """Admin page to create a blood request and notify matching donors.
    If location (req_lat, req_lng) is provided, only donors within radius_km are notified.
    Donors receive a notification and can Accept or Decline (e.g. in the mobile app or donor notifications page).
    """
    if request.method == 'POST':
        blood_group = (request.POST.get('blood_group') or '').strip()
        urgency = (request.POST.get('urgency') or '').strip()
        units_needed_raw = request.POST.get('units_needed', 1)
        note = request.POST.get('note', '')
        if blood_group not in dict(DonorProfile.BLOOD_GROUP_CHOICES):
            messages.error(request, 'Please select a valid blood group.')
            return redirect('admin_dashboard')
        if urgency not in dict(BloodRequest.URGENCY_CHOICES):
            messages.error(request, 'Please select a valid urgency level.')
            return redirect('admin_dashboard')
        try:
            units_needed = int(units_needed_raw) if units_needed_raw else 1
        except (TypeError, ValueError):
            messages.error(request, 'Units needed must be a whole number.')
            return redirect('admin_dashboard')
        if units_needed < 1:
            messages.error(request, 'Units needed must be at least 1.')
            return redirect('admin_dashboard')
        use_location = request.POST.get('use_location') == 'on'
        location_name = (request.POST.get('location_name') or '').strip() or None
        req_lat = _parse_float(request.POST.get('req_lat'))
        req_lng = _parse_float(request.POST.get('req_lng'))
        radius_km = _parse_float(request.POST.get('radius_km'), DEFAULT_RADIUS_KM) or DEFAULT_RADIUS_KM

        if use_location and (req_lat is None or req_lng is None):
            messages.error(
                request,
                'Location-based matching is enabled but latitude and/or longitude are missing. '
                'Enter request location (e.g. hospital/camp) or disable "Use location". All compatible donors will be notified.'
            )
        # Use distance-based matching only when BOTH coordinates are present
        use_distance_matching = req_lat is not None and req_lng is not None

        hospital_id = (request.POST.get('hospital_id') or '').strip() or ''
        city = (request.POST.get('city') or '').strip() or ''
        state = (request.POST.get('state') or '').strip() or ''
        source = (request.POST.get('source') or 'app').strip() or 'app'
        sla_minutes = request.POST.get('sla_minutes')
        if sla_minutes and str(sla_minutes).strip():
            try:
                sla_minutes = int(sla_minutes)
                if sla_minutes < 0:
                    raise ValueError('SLA must be >= 0')
            except (TypeError, ValueError):
                messages.error(request, 'SLA minutes must be a non-negative whole number.')
                return redirect('admin_dashboard')
        else:
            sla_minutes = None

        try:
            blood_request = BloodRequest.objects.create(
                blood_group=blood_group,
                units_needed=units_needed,
                units_required=units_needed,
                urgency=urgency,
                urgency_level=urgency and urgency.capitalize() or '',
                status='open',
                source=source,
                hospital_id=hospital_id,
                city=city,
                state=state,
                sla_minutes=sla_minutes,
                note=note or '',
                created_by=request.user,
                location_name=location_name or '',
                req_lat=req_lat,
                req_lng=req_lng,
                radius_km=radius_km,
            )
            RequestTimeline.objects.create(
                request=blood_request,
                event_type='CREATED',
                actor='ADMIN',
                metadata={'created_by': request.user.username},
            )
            AdminNotification.objects.create(
                notification_type=AdminNotification.TYPE_REQUEST_CREATED,
                blood_request=blood_request,
            )
        except Exception:
            logger.exception("admin_create_request: failed to create request")
            messages.error(request, 'Could not create the request. Please try again.')
            return redirect('admin_dashboard')

        compatible_blood_groups = get_compatible_blood_groups(blood_group)
        base_queryset = DonorProfile.objects.filter(
            blood_group__in=compatible_blood_groups,
            is_available=True
        ).select_related('user')

        if use_distance_matching:
            # Coerce to float so Decimal (from DB) vs float comparison is reliable
            req_lat_f = float(req_lat)
            req_lng_f = float(req_lng)
            radius_km_f = max(0.1, float(radius_km))  # ensure radius is at least 0.1 km
            donors_with_loc = [dp for dp in base_queryset if donor_has_location(dp)]
            logger.debug(
                "admin_create_request: req_lat=%.6f req_lng=%.6f radius_km=%.2f donors_with_location=%s",
                req_lat_f, req_lng_f, radius_km_f, len(donors_with_loc)
            )
            for i, dp in enumerate(donors_with_loc[:5]):
                try:
                    d = haversine_km(req_lat_f, req_lng_f, float(dp.last_lat), float(dp.last_lng))
                    logger.debug("  donor id=%s distance_km=%s", dp.user_id, d)
                except (TypeError, ValueError):
                    pass
            matched_with_distance = []
            for donor_profile in base_queryset:
                if not donor_has_location(donor_profile):
                    continue
                try:
                    donor_lat = float(donor_profile.last_lat)
                    donor_lng = float(donor_profile.last_lng)
                except (TypeError, ValueError):
                    continue
                dist = haversine_km(req_lat_f, req_lng_f, donor_lat, donor_lng)
                if dist is not None and dist <= radius_km_f:
                    matched_with_distance.append((donor_profile, round(dist, 2)))
            matching_donors = [dp for dp, _ in matched_with_distance]
            logger.debug("admin_create_request: matched_donor_ids=%s", [dp.user_id for dp in matching_donors])
        else:
            matching_donors = list(base_queryset)

        notifications_created = 0
        for donor_profile in matching_donors:
            try:
                Notification.objects.create(
                    user=donor_profile.user,
                    blood_request=blood_request
                )
                from .whatsapp_integration import trigger_blood_alert_whatsapp
                trigger_blood_alert_whatsapp(donor_profile.user, blood_request)
                notifications_created += 1
            except IntegrityError:
                pass
            except Exception:
                logger.exception("admin_create_request: notify failed for donor_id=%s", donor_profile.user_id)
                continue

        # Optional: when location-based, also populate Active/Standby pool (does not change who got notified)
        if use_distance_matching and matched_with_distance:
            try:
                from .donor_pool_service import create_request_and_assign_donors
                sorted_by_dist = sorted(matched_with_distance, key=lambda x: x[1])
                create_request_and_assign_donors(blood_request, sorted_by_dist, haversine_km)
            except Exception:
                logger.exception("admin_create_request: donor pool assign failed")

        # Stay on dashboard: redirect with created_request_id so dashboard shows summary modal (no message – modal shows notified/accepted counts)
        url = reverse('admin_dashboard') + '?created_request_id=' + str(blood_request.id)
        return redirect(url)

    hospitals = HospitalMaster.objects.all().order_by('hospital_name')
    cities = DimCity.objects.all().order_by('state', 'city')
    context = {
        'blood_groups': DonorProfile.BLOOD_GROUP_CHOICES,
        'urgency_levels': BloodRequest.URGENCY_CHOICES,
        'hospitals': hospitals,
        'cities': cities,
    }
    return render(request, 'demo_admin_create_request.html', context)


@login_required
@user_passes_test(is_staff_user)
@ensure_csrf_cookie
def admin_all_requests(request):
    """List all blood requests with Edit and Delete buttons."""
    blood_requests = BloodRequest.objects.all().prefetch_related(
        'responses', 'notifications', 'delay_reasons', 'delay_reasons__reported_by', 'delay_reasons__reported_by__donor_profile'
    ).order_by('-created_at')
    context = {'blood_requests': blood_requests}
    return render(request, 'admin_all_requests.html', context)


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["POST"])
def admin_delete_request(request, request_id):
    """Delete a blood request after confirmation (confirmation done in frontend)."""
    blood_request = get_object_or_404(BloodRequest, id=request_id)
    blood_request.delete()
    messages.success(request, f'Blood request #{request_id} has been deleted.')
    return redirect('admin_all_requests')


@login_required
@user_passes_test(is_staff_user)
@ensure_csrf_cookie
@transaction.atomic
def admin_edit_request(request, request_id):
    """Edit blood request: show form pre-filled; on save update request, optional radius extension with log."""
    blood_request = get_object_or_404(BloodRequest, id=request_id)
    hospitals = HospitalMaster.objects.all().order_by('hospital_name')
    cities = DimCity.objects.all().order_by('state', 'city')

    if request.method == 'POST':
        blood_group = request.POST.get('blood_group')
        units_needed = request.POST.get('units_needed', 1)
        urgency = request.POST.get('urgency')
        note = request.POST.get('note', '')
        use_location = request.POST.get('use_location') == 'on'
        location_name = (request.POST.get('location_name') or '').strip() or None
        req_lat = _parse_float(request.POST.get('req_lat'))
        req_lng = _parse_float(request.POST.get('req_lng'))
        radius_km = _parse_float(request.POST.get('radius_km'), DEFAULT_RADIUS_KM) or DEFAULT_RADIUS_KM
        radius_extension = _parse_float(request.POST.get('radius_extension'))  # optional new radius if extending

        hospital_id = (request.POST.get('hospital_id') or '').strip() or ''
        city = (request.POST.get('city') or '').strip() or ''
        state = (request.POST.get('state') or '').strip() or ''
        source = (request.POST.get('source') or 'app').strip() or 'app'
        sla_minutes = request.POST.get('sla_minutes')
        sla_minutes = int(sla_minutes) if sla_minutes and str(sla_minutes).strip() else None

        old_radius = float(blood_request.radius_km) if blood_request.radius_km is not None else None
        new_radius = radius_km
        if radius_extension is not None and radius_extension > 0:
            new_radius = max(radius_km, float(radius_extension))

        blood_request.blood_group = blood_group
        blood_request.units_needed = int(units_needed) if units_needed else 1
        blood_request.units_required = blood_request.units_needed
        blood_request.urgency = urgency
        blood_request.urgency_level = (urgency and urgency.capitalize()) or ''
        blood_request.note = note or ''
        blood_request.location_name = location_name or ''
        blood_request.req_lat = req_lat
        blood_request.req_lng = req_lng
        blood_request.radius_km = new_radius
        blood_request.hospital_id = hospital_id
        blood_request.city = city
        blood_request.state = state
        blood_request.source = source
        blood_request.sla_minutes = sla_minutes
        blood_request.save()

        # Log radius expansion when radius was increased (old and new saved in log)
        if (radius_extension is not None and radius_extension > 0) and new_radius > (old_radius or 0):
            RadiusExpansionLog.objects.create(
                request=blood_request,
                old_radius_km=old_radius,
                new_radius_km=new_radius,
                success=True,
            )

        # If radius was extended and we have location, notify additional donors in new radius
        use_distance_matching = req_lat is not None and req_lng is not None
        notified_count = Notification.objects.filter(blood_request=blood_request).count()
        if use_distance_matching and new_radius > (old_radius or 0):
            compatible_blood_groups = get_compatible_blood_groups(blood_request.blood_group)
            already_notified_ids = set(
                Notification.objects.filter(blood_request=blood_request).values_list('user_id', flat=True)
            )
            base_queryset = DonorProfile.objects.filter(
                blood_group__in=compatible_blood_groups,
                is_available=True
            ).select_related('user').exclude(user_id__in=already_notified_ids)
            req_lat_f = float(req_lat)
            req_lng_f = float(req_lng)
            radius_km_f = max(0.1, float(new_radius))
            for donor_profile in base_queryset:
                if not donor_has_location(donor_profile):
                    continue
                try:
                    donor_lat = float(donor_profile.last_lat)
                    donor_lng = float(donor_profile.last_lng)
                except (TypeError, ValueError):
                    continue
                dist = haversine_km(req_lat_f, req_lng_f, donor_lat, donor_lng)
                if dist is not None and dist <= radius_km_f:
                    try:
                        Notification.objects.create(
                            user=donor_profile.user,
                            blood_request=blood_request,
                        )
                        notified_count += 1
                    except IntegrityError:
                        pass

        accepted_count = DonorResponse.objects.filter(
            blood_request=blood_request, response='accepted'
        ).count()
        messages.success(
            request,
            f'Request #{blood_request.id} saved. Notified: {notified_count} | Donors accepted: {accepted_count}.'
        )
        return redirect('admin_all_requests')

    # GET: pre-fill form (full page or modal fragment)
    context = {
        'blood_request': blood_request,
        'blood_groups': DonorProfile.BLOOD_GROUP_CHOICES,
        'urgency_levels': BloodRequest.URGENCY_CHOICES,
        'hospitals': hospitals,
        'cities': cities,
    }
    if request.GET.get('modal'):
        return render(request, 'admin_edit_request_form.html', context)
    return render(request, 'admin_edit_request.html', context)


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["POST"])
def admin_delete_notifications(request):
    """Delete selected admin notifications (bell modal)."""
    ids = request.POST.getlist('notification_ids')
    if ids:
        try:
            ids = [int(x) for x in ids if str(x).isdigit()]
            AdminNotification.objects.filter(id__in=ids).delete()
        except (ValueError, TypeError):
            pass
    redirect_url = request.META.get('HTTP_REFERER') or reverse('admin_dashboard')
    return redirect(redirect_url)


@login_required
@user_passes_test(is_staff_user)
def admin_request_detail(request, request_id):
    """Admin page to view blood request details, timeline, ETA, delays, assignments, notified/accepted donors."""
    blood_request = get_object_or_404(BloodRequest, id=request_id)

    notified_count = Notification.objects.filter(blood_request=blood_request).count()
    accepted_responses = DonorResponse.objects.filter(
        blood_request=blood_request,
        response='accepted'
    ).select_related('donor', 'donor__donor_profile')

    timeline_events = RequestTimeline.objects.filter(request=blood_request).order_by('event_time')
    eta_trackings = EtaTracking.objects.filter(request=blood_request).order_by('-committed_at')
    delay_reasons = DelayReason.objects.filter(request=blood_request).order_by('-identified_at')
    donor_assignments = DonorAssignment.objects.filter(request=blood_request).select_related('donor', 'donor_master').order_by('-assigned_at')
    fallback_actions = FallbackAction.objects.filter(request=blood_request).order_by('-triggered_at')

    accepted_with_distance = []
    for resp in accepted_responses:
        dist_km = None
        if blood_request.req_lat is not None and blood_request.req_lng is not None and hasattr(resp.donor, 'donor_profile'):
            prof = resp.donor.donor_profile
            if prof.last_lat is not None and prof.last_lng is not None:
                d = haversine_km(
                    blood_request.req_lat, blood_request.req_lng,
                    prof.last_lat, prof.last_lng
                )
                dist_km = round(d, 2) if d is not None else None
        accepted_with_distance.append({'response': resp, 'distance_km': dist_km})

    context = {
        'blood_request': blood_request,
        'notified_count': notified_count,
        'accepted_responses': accepted_responses,
        'accepted_with_distance': accepted_with_distance,
        'timeline_events': timeline_events,
        'eta_trackings': eta_trackings,
        'delay_reasons': delay_reasons,
        'donor_assignments': donor_assignments,
        'fallback_actions': fallback_actions,
    }
    return render(request, 'demo_admin_request_detail.html', context)


@login_required
@user_passes_test(is_staff_user)
def admin_request_detail_modal(request, request_id):
    """Returns only the inner HTML for request detail (for dashboard modal)."""
    blood_request = get_object_or_404(BloodRequest, id=request_id)
    notified_count = Notification.objects.filter(blood_request=blood_request).count()
    accepted_responses = DonorResponse.objects.filter(
        blood_request=blood_request,
        response='accepted'
    ).select_related('donor', 'donor__donor_profile')
    timeline_events = RequestTimeline.objects.filter(request=blood_request).order_by('event_time')
    eta_trackings = EtaTracking.objects.filter(request=blood_request).order_by('-committed_at')
    delay_reasons = DelayReason.objects.filter(request=blood_request).order_by('-identified_at')
    donor_assignments = DonorAssignment.objects.filter(request=blood_request).select_related('donor', 'donor_master').order_by('-assigned_at')
    fallback_actions = FallbackAction.objects.filter(request=blood_request).order_by('-triggered_at')
    accepted_with_distance = []
    for resp in accepted_responses:
        dist_km = None
        if blood_request.req_lat is not None and blood_request.req_lng is not None and hasattr(resp.donor, 'donor_profile'):
            prof = resp.donor.donor_profile
            if prof.last_lat is not None and prof.last_lng is not None:
                d = haversine_km(
                    float(blood_request.req_lat), float(blood_request.req_lng),
                    float(prof.last_lat), float(prof.last_lng)
                )
                dist_km = round(d, 2) if d is not None else None
        accepted_with_distance.append({'response': resp, 'distance_km': dist_km})
    # All notified donors with name, blood group, phone, status for admin to track
    response_by_donor = dict(
        DonorResponse.objects.filter(blood_request=blood_request).values_list('donor_id', 'response')
    )
    notified_donors_list = []
    for notif in Notification.objects.filter(blood_request=blood_request).select_related('user', 'user__donor_profile'):
        status_key = response_by_donor.get(notif.user_id)
        status_display = 'Accepted' if status_key == 'accepted' else ('Declined' if status_key == 'rejected' else 'Pending')
        try:
            profile = notif.user.donor_profile
            blood_grp = getattr(profile, 'blood_group', None)
            phone = getattr(profile, 'phone', None) or '—'
        except (DonorProfile.DoesNotExist, AttributeError):
            blood_grp = None
            phone = '—'
        notified_donors_list.append({
            'donor_id': notif.user_id,
            'username': notif.user.username,
            'blood_group': blood_grp,
            'phone': phone,
            'status': status_display,
            'status_key': status_key or 'pending',
        })
    active_assignments = []
    standby_assignments = []
    for a in RequestDonorPoolAssignment.objects.filter(
        request=blood_request
    ).select_related('donor', 'donor__donor_profile').order_by('rank'):
        try:
            phone = a.donor.donor_profile.phone if a.donor.donor_profile else '—'
            blood_grp = a.donor.donor_profile.blood_group if a.donor.donor_profile else None
        except Exception:
            phone = '—'
            blood_grp = None
        item = {'assignment': a, 'username': a.donor.username, 'donor_id': a.donor_id, 'distance_km': a.distance_km, 'state': a.state, 'phone': phone, 'blood_group': blood_grp}
        if a.pool_type == RequestDonorPoolAssignment.POOL_TYPE_ACTIVE:
            active_assignments.append(item)
        else:
            standby_assignments.append(item)
    context = {
        'blood_request': blood_request,
        'notified_count': notified_count,
        'notified_donors_list': notified_donors_list,
        'accepted_responses': accepted_responses,
        'accepted_with_distance': accepted_with_distance,
        'active_assignments': active_assignments,
        'standby_assignments': standby_assignments,
        'timeline_events': timeline_events,
        'eta_trackings': eta_trackings,
        'delay_reasons': delay_reasons,
        'donor_assignments': donor_assignments,
        'fallback_actions': fallback_actions,
    }
    return render(request, 'admin_request_detail_modal.html', context)


@login_required
@user_passes_test(is_staff_user)
def admin_hospitals(request):
    """Admin list of hospitals (HospitalMaster)."""
    hospitals = HospitalMaster.objects.all().order_by('hospital_name')
    context = {'hospitals': hospitals}
    return render(request, 'admin_hospitals.html', context)


@login_required
@user_passes_test(is_staff_user)
def admin_blood_banks(request):
    """Admin list of blood banks (BloodBankMaster)."""
    blood_banks = BloodBankMaster.objects.all().order_by('name')
    context = {'blood_banks': blood_banks}
    return render(request, 'admin_blood_banks.html', context)


@login_required
@user_passes_test(is_staff_user)
def admin_cities(request):
    """Admin list of cities (DimCity)."""
    cities = DimCity.objects.all().order_by('state', 'city')
    context = {'cities': cities}
    return render(request, 'admin_cities.html', context)


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["GET", "POST"])
def admin_add_hospital(request):
    """Add hospital from frontend; data saved to backend and reflected on dashboard."""
    if request.method == 'POST':
        hospital_id = (request.POST.get('hospital_id') or '').strip()
        hospital_name = (request.POST.get('hospital_name') or '').strip()
        city = (request.POST.get('city') or '').strip()
        tier = (request.POST.get('tier') or '').strip()
        if not hospital_id or not hospital_name:
            messages.error(request, 'Hospital ID and Name are required.')
        else:
            try:
                hospital = HospitalMaster.objects.create(
                    hospital_id=hospital_id,
                    hospital_name=hospital_name,
                    city=city,
                    tier=tier,
                )
                # Optional: create first hospital metrics row if any metric field is provided
                m_date = request.POST.get('metrics_date')
                m_total = request.POST.get('metrics_total_requests')
                m_fulfilled = request.POST.get('metrics_fulfilled')
                m_failed = request.POST.get('metrics_failed')
                m_avg_time = request.POST.get('metrics_avg_fulfillment_time')
                m_sla_pct = request.POST.get('metrics_sla_breach_pct')
                if m_date or (m_total and m_total.strip()) or (m_fulfilled and m_fulfilled.strip()) or (m_failed and m_failed.strip()):
                    from django.utils.dateparse import parse_date
                    metrics_date = parse_date(m_date) if m_date and m_date.strip() else timezone.now().date()
                    total_requests = int(m_total) if m_total and str(m_total).strip() else 0
                    fulfilled = int(m_fulfilled) if m_fulfilled and str(m_fulfilled).strip() else 0
                    failed = int(m_failed) if m_failed and str(m_failed).strip() else 0
                    avg_ft = float(m_avg_time) if m_avg_time and str(m_avg_time).strip() else None
                    sla_pct = float(m_sla_pct) if m_sla_pct and str(m_sla_pct).strip() else None
                    HospitalMetrics.objects.update_or_create(
                        hospital=hospital,
                        date=metrics_date,
                        defaults={
                            'total_requests': total_requests,
                            'fulfilled': fulfilled,
                            'failed': failed,
                            'avg_fulfillment_time': avg_ft,
                            'sla_breach_pct': sla_pct,
                        },
                    )
                messages.success(request, f'Hospital "{hospital_name}" added.')
                next_url = request.GET.get('next') or request.POST.get('next') or 'admin_dashboard'
                return redirect(next_url)
            except IntegrityError:
                messages.error(request, f'Hospital ID "{hospital_id}" already exists.')
        # fall through to re-render with errors
    return render(request, 'admin_add_hospital.html', {})


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["GET", "POST"])
def admin_add_blood_bank(request):
    """Add blood bank from frontend; data saved to backend and reflected on dashboard."""
    if request.method == 'POST':
        blood_bank_id = (request.POST.get('blood_bank_id') or '').strip()
        name = (request.POST.get('name') or '').strip()
        city = (request.POST.get('city') or '').strip()
        reliability = request.POST.get('reliability_score')
        reliability = float(reliability) if reliability and str(reliability).strip() else None
        if not blood_bank_id or not name:
            messages.error(request, 'Blood Bank ID and Name are required.')
        else:
            try:
                BloodBankMaster.objects.create(
                    blood_bank_id=blood_bank_id,
                    name=name,
                    city=city,
                    reliability_score=reliability,
                )
                messages.success(request, f'Blood bank "{name}" added.')
                next_url = request.GET.get('next') or request.POST.get('next') or 'admin_dashboard'
                return redirect(next_url)
            except IntegrityError:
                messages.error(request, f'Blood Bank ID "{blood_bank_id}" already exists.')
    return render(request, 'admin_add_blood_bank.html', {})


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["GET", "POST"])
def admin_add_city(request):
    """Add city from frontend; data saved to backend and reflected on dashboard."""
    if request.method == 'POST':
        city = (request.POST.get('city') or '').strip()
        state = (request.POST.get('state') or '').strip()
        region = (request.POST.get('region') or '').strip()
        if not city or not state:
            messages.error(request, 'City and State are required.')
        else:
            try:
                DimCity.objects.create(city=city, state=state, region=region)
                messages.success(request, f'City "{city}, {state}" added.')
                next_url = request.GET.get('next') or request.POST.get('next') or 'admin_dashboard'
                return redirect(next_url)
            except IntegrityError:
                messages.error(request, f'City "{city}" in state "{state}" already exists.')
    return render(request, 'admin_add_city.html', {})


ELIGIBILITY_DAYS = 90


def _donor_dashboard_metrics(request_user):
    """Compute donation-based metrics for donor dashboard (like Flutter)."""
    accepted_responses = DonorResponse.objects.filter(
        donor=request_user, response='accepted'
    ).select_related('blood_request').order_by('responded_at')
    
    now = timezone.now()
    donations = [
        {'date': r.responded_at, 'urgency': r.blood_request.urgency}
        for r in accepted_responses
    ]
    
    this_month = sum(1 for d in donations if d['date'].month == now.month and d['date'].year == now.year)
    last_donation_date = donations[-1]['date'] if donations else None
    lifetime = len(donations)
    
    if last_donation_date:
        days_since = (now - last_donation_date.replace(tzinfo=now.tzinfo)).days
        days_until_eligible = max(0, ELIGIBILITY_DAYS - days_since)
        eligibility_progress = min(1.0, days_since / ELIGIBILITY_DAYS) if days_until_eligible > 0 else 1.0
    else:
        days_until_eligible = 0
        eligibility_progress = 1.0
    
    by_day = [0] * 31
    for d in donations:
        if d['date'].month == now.month and d['date'].year == now.year:
            by_day[d['date'].day - 1] += 1
    
    month_names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    by_month = []
    for i in range(12):
        rel = now.month - 1 - i
        year = now.year + (rel // 12)
        month = (rel % 12) + 1
        count = sum(1 for d in donations if d['date'].month == month and d['date'].year == year)
        label = f"{month_names[month - 1]}\n'{str(year)[2:]}"
        by_month.append({'label': label, 'count': count})
    by_month.reverse()
    
    by_type = {'critical': 0, 'high': 0, 'medium': 0}
    for d in donations:
        by_type[d['urgency']] = by_type.get(d['urgency'], 0) + 1
    
    months_with_donation = set(d['date'].year * 12 + d['date'].month for d in donations)
    sorted_months = sorted(months_with_donation, reverse=True)
    streak = 0
    current = now.year * 12 + now.month
    for m in sorted_months:
        if m == current:
            streak += 1
            current -= 1
        elif m < current:
            break
    
    badges = [lifetime >= 1, lifetime >= 5, lifetime >= 10, lifetime >= 25]
    
    chart_by_type_pie = {
        'labels': ['Emergency', 'Hospital', 'Other'],
        'data': [by_type.get('critical', 0), by_type.get('high', 0), by_type.get('medium', 0)],
    }
    return {
        'this_month_count': this_month,
        'last_donation_date': last_donation_date,
        'lifetime_count': lifetime,
        'days_until_eligible': days_until_eligible,
        'eligibility_progress': eligibility_progress,
        'chart_by_day': by_day,
        'chart_by_month': by_month,
        'chart_by_type': by_type,
        'chart_by_type_pie': chart_by_type_pie,
        'streak': streak,
        'badges': badges,
    }


@login_required
def donor_notifications(request):
    """Donor page to view their notifications and blood requests (dashboard like Flutter)."""
    try:
        donor_profile = DonorProfile.objects.get(user=request.user)
        has_profile = True
    except DonorProfile.DoesNotExist:
        has_profile = False
        donor_profile = None
    
    notifications = Notification.objects.filter(
        user=request.user
    ).select_related('blood_request').order_by('-created_at')[:100]
    
    responses_map = dict(
        DonorResponse.objects.filter(donor=request.user).values_list('blood_request_id', 'response')
    )
    
    notifications_with_status = []
    accepted_count = 0
    rejected_count = 0
    for notification in notifications:
        status = responses_map.get(notification.blood_request_id)
        notification.has_responded = status is not None
        if notification.has_responded:
            notification.response_status = status
            if status == 'accepted':
                accepted_count += 1
            else:
                rejected_count += 1
        notifications_with_status.append(notification)
    
    total_notifications = len(notifications_with_status)
    pending_count = total_notifications - accepted_count - rejected_count
    
    metrics = _donor_dashboard_metrics(request.user)
    
    responded_list = [n for n in notifications_with_status if n.has_responded]
    resolved_delays = DelayReason.objects.filter(
        reported_by=request.user, resolved=True
    ).select_related('request').order_by('-resolved_at')[:20]
    
    context = {
        'notifications': notifications_with_status,
        'responded_list': responded_list,
        'resolved_delays': resolved_delays,
        'user': request.user,
        'has_profile': has_profile,
        'donor_profile': donor_profile,
        'total_notifications': total_notifications,
        'pending_count': pending_count,
        'accepted_count': accepted_count,
        'rejected_count': rejected_count,
        'this_month_count': metrics['this_month_count'],
        'last_donation_date': metrics['last_donation_date'],
        'lifetime_count': metrics['lifetime_count'],
        'days_until_eligible': metrics['days_until_eligible'],
        'eligibility_progress': metrics['eligibility_progress'],
        'chart_by_day': metrics['chart_by_day'],
        'chart_by_month': metrics['chart_by_month'],
        'chart_by_type': metrics['chart_by_type'],
        'chart_by_type_pie': metrics['chart_by_type_pie'],
        'streak': metrics['streak'],
        'badges': metrics['badges'],
    }
    return render(request, 'demo_donor_notifications.html', context)


@login_required
@require_http_methods(["POST"])
def donor_update_location(request):
    """Update donor's last-known location (lat/lng) from web. Enables distance-based matching."""
    try:
        donor_profile = DonorProfile.objects.get(user=request.user)
    except DonorProfile.DoesNotExist:
        return JsonResponse({'status': 'error', 'message': 'Donor profile not found'}, status=404)
    lat = _parse_float(request.POST.get('lat') or request.POST.get('last_lat'))
    lng = _parse_float(request.POST.get('lng') or request.POST.get('last_lng'))
    if lat is None or lng is None:
        return JsonResponse({'status': 'error', 'message': 'Latitude and longitude are required'}, status=400)
    from django.utils import timezone
    donor_profile.last_lat = lat
    donor_profile.last_lng = lng
    donor_profile.location_updated_at = timezone.now()
    donor_profile.save()
    return JsonResponse({
        'status': 'ok',
        'message': f'Location updated. You will be matched for requests within range.',
        'lat': float(donor_profile.last_lat),
        'lng': float(donor_profile.last_lng),
    })


@login_required
@require_http_methods(["POST"])
def donor_respond(request):
    """API endpoint for donor to accept/reject a blood request"""
    try:
        data = json.loads(request.body)
        blood_request_id = data.get('blood_request_id')
        response = data.get('response')
        
        if not blood_request_id or not response:
            return JsonResponse({'status': 'error', 'message': 'Missing required fields'}, status=400)
        
        if response not in ['accepted', 'rejected']:
            return JsonResponse({'status': 'error', 'message': 'Invalid response value'}, status=400)
        
        blood_request = get_object_or_404(BloodRequest, id=blood_request_id)
        
        # First accept closes the request for others; decline does not
        if response == 'accepted':
            already_accepted = DonorResponse.objects.filter(
                blood_request=blood_request,
                response='accepted'
            ).exclude(donor=request.user).exists()
            if already_accepted:
                return JsonResponse({
                    'status': 'error',
                    'message': 'This request has already been accepted by another donor. It is closed for further acceptances.'
                }, status=400)

        # Create or update donor response
        donor_response, created = DonorResponse.objects.update_or_create(
            blood_request=blood_request,
            donor=request.user,
            defaults={'response': response}
        )
        if response == 'accepted':
            AdminNotification.objects.create(
                notification_type=AdminNotification.TYPE_DONOR_ACCEPTED,
                blood_request=blood_request,
                donor=request.user,
            )

        # Update Active/Standby pool state and promote standby on reject
        try:
            from .donor_pool_service import handle_donor_response_for_pool
            handle_donor_response_for_pool(blood_request.id, request.user.id, response == 'accepted')
        except Exception:
            logger.exception("donor_respond: pool update failed")
        
        # Mark notification as read
        Notification.objects.filter(
            user=request.user,
            blood_request=blood_request
        ).update(is_read=True)
        
        return JsonResponse({
            'status': 'ok',
            'message': f'Response recorded: {response}',
            'created': created
        })
        
    except json.JSONDecodeError:
        return JsonResponse({'status': 'error', 'message': 'Invalid JSON'}, status=400)
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)


@login_required
@require_http_methods(["POST"])
def donor_submit_delay(request):
    """Donor reports delay (can't come within time). Creates DelayReason with reported_by=donor."""
    try:
        data = json.loads(request.body)
        blood_request_id = data.get('blood_request_id')
        stage = (data.get('stage') or '').strip() or 'Acceptance'
        delay_reason = (data.get('delay_reason') or '').strip()
        delay_category = (data.get('delay_category') or '').strip() or None
        delay_minutes = data.get('delay_minutes')
        if not blood_request_id or not delay_reason:
            return JsonResponse({'status': 'error', 'message': 'blood_request_id and delay_reason are required'}, status=400)
        if stage not in dict(DelayReason.STAGE_CHOICES):
            stage = 'Acceptance'
        if delay_category and delay_category not in dict(DelayReason.CATEGORY_CHOICES):
            delay_category = None
        delay_minutes = int(delay_minutes) if delay_minutes is not None and str(delay_minutes).strip() else None
        blood_request = get_object_or_404(BloodRequest, id=blood_request_id)
        if not DonorResponse.objects.filter(blood_request=blood_request, donor=request.user, response='accepted').exists():
            return JsonResponse({'status': 'error', 'message': 'You must have accepted this request to report a delay'}, status=400)
        DelayReason.objects.create(
            request=blood_request,
            reported_by=request.user,
            stage=stage,
            delay_reason=delay_reason[:100],
            delay_category=delay_category or '',
            delay_minutes=delay_minutes,
        )
        return JsonResponse({'status': 'ok', 'message': 'Delay reason submitted'})
    except json.JSONDecodeError:
        return JsonResponse({'status': 'error', 'message': 'Invalid JSON'}, status=400)
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)


@login_required
@require_http_methods(["GET"])
def api_donor_poll(request):
    """JSON: notifications list, counts, and resolved delays (for real-time donor dashboard). Donor only."""
    if request.user.is_staff:
        return JsonResponse({'error': 'For donors only'}, status=403)
    notifications = Notification.objects.filter(
        user=request.user
    ).select_related('blood_request').order_by('-created_at')
    responses_map = dict(
        DonorResponse.objects.filter(donor=request.user).values_list('blood_request_id', 'response')
    )
    notifications_data = []
    accepted_count = 0
    rejected_count = 0
    for n in notifications:
        status = responses_map.get(n.blood_request_id)
        has_responded = status is not None
        if has_responded:
            if status == 'accepted':
                accepted_count += 1
            else:
                rejected_count += 1
        notifications_data.append({
            'id': n.blood_request_id,
            'blood_group': n.blood_request.blood_group,
            'urgency': n.blood_request.urgency,
            'urgency_display': n.blood_request.get_urgency_display(),
            'units_needed': n.blood_request.units_needed,
            'note': n.blood_request.note or '',
            'created_at': n.blood_request.created_at.isoformat() if n.blood_request.created_at else None,
            'notification_created_at': n.created_at.isoformat() if n.created_at else None,
            'has_responded': has_responded,
            'response_status': status,
        })
    total = len(notifications_data)
    pending_count = total - accepted_count - rejected_count
    since = request.GET.get('resolved_since')
    resolved_delays = []
    qs = DelayReason.objects.filter(
        reported_by=request.user,
        resolved=True
    ).select_related('request').order_by('-resolved_at')
    if since:
        try:
            from datetime import datetime
            since_dt = timezone.make_aware(datetime.fromisoformat(since.replace('Z', '+00:00')))
            qs = qs.filter(resolved_at__gte=since_dt)
        except Exception:
            pass
    for d in qs[:50]:
        resolved_delays.append({
            'request_id': d.request_id,
            'resolved_at': d.resolved_at.isoformat() if d.resolved_at else None,
        })
    return JsonResponse({
        'notifications': notifications_data,
        'total_notifications': total,
        'pending_count': pending_count,
        'accepted_count': accepted_count,
        'rejected_count': rejected_count,
        'resolved_delays': resolved_delays,
    })


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["GET"])
def api_admin_notifications(request):
    """JSON: admin notifications list + counts for navbar modal."""
    include_list = request.GET.get('list', '1') != '0'
    total_count = AdminNotification.objects.count()
    delay_count = DelayReason.objects.filter(resolved=False).count()
    notifications_data = []
    if include_list:
        qs = AdminNotification.objects.select_related('blood_request', 'donor').order_by('-created_at')[:50]
        for n in qs:
            blood_request = n.blood_request
            notifications_data.append({
                'id': n.id,
                'notification_type': n.notification_type,
                'blood_request_id': blood_request.id if blood_request else None,
                'blood_group': getattr(blood_request, 'blood_group', ''),
                'urgency': getattr(blood_request, 'urgency', ''),
                'donor_username': n.donor.username if n.donor else '',
                'created_at': n.created_at.strftime('%b %d, %Y %H:%M') if n.created_at else '',
            })
    return JsonResponse({
        'count': total_count,
        'delay_count': delay_count,
        'notifications': notifications_data,
    })


@login_required
@require_http_methods(["GET"])
def api_donor_notification_count(request):
    """JSON: pending donor notification count for navbar badge."""
    if request.user.is_staff:
        return JsonResponse({'error': 'For donors only'}, status=403)
    responded_ids = DonorResponse.objects.filter(donor=request.user).values_list('blood_request_id', flat=True)
    pending_count = Notification.objects.filter(user=request.user).exclude(
        blood_request_id__in=responded_ids
    ).count()
    return JsonResponse({'count': pending_count})


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["GET"])
def api_admin_unresolved_delay_count(request):
    """JSON: count of unresolved delay reasons (for admin navbar badge)."""
    count = DelayReason.objects.filter(resolved=False).count()
    return JsonResponse({'count': count})


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["GET"])
def api_admin_request_delays(request, request_id):
    """JSON: list of delay reasons for a blood request (for admin delay modal, live data)."""
    blood_request = get_object_or_404(BloodRequest, id=request_id)
    delays = DelayReason.objects.filter(
        request=blood_request
    ).select_related('reported_by', 'reported_by__donor_profile').order_by('-identified_at')
    out = []
    for d in delays:
        phone = ''
        if d.reported_by and hasattr(d.reported_by, 'donor_profile') and d.reported_by.donor_profile:
            phone = d.reported_by.donor_profile.phone or ''
        out.append({
            'delay_id': str(d.delay_id),
            'stage': d.stage,
            'stage_display': d.get_stage_display(),
            'delay_reason': d.delay_reason,
            'delay_category': d.delay_category or '',
            'delay_category_display': d.get_delay_category_display() if d.delay_category else '—',
            'delay_minutes': d.delay_minutes,
            'resolved': d.resolved,
            'resolved_at': d.resolved_at.isoformat() if d.resolved_at else None,
            'identified_at': d.identified_at.strftime('%b %d, %Y %H:%M') if d.identified_at else '',
            'reported_by_username': d.reported_by.username if d.reported_by else '—',
            'reported_by_phone': phone,
            'resolve_url': reverse('admin_resolve_delay', kwargs={'delay_uuid': d.delay_id}),
        })
    return JsonResponse({'delays': out})


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["POST"])
def admin_resolve_delay(request, delay_uuid):
    """Mark a delay reason as resolved (admin accepted). Sets resolved=True, resolved_at=now. Supports AJAX."""
    from django.utils import timezone
    delay = get_object_or_404(DelayReason, delay_id=delay_uuid)
    delay.resolved = True
    delay.resolved_at = timezone.now()
    delay.save()
    if request.headers.get('X-Requested-With') == 'XMLHttpRequest' or request.accepts('application/json'):
        return JsonResponse({'status': 'ok', 'message': 'Delay marked as resolved.'})
    messages.success(request, f'Delay reason marked as resolved.')
    redirect_url = request.META.get('HTTP_REFERER') or reverse('admin_dashboard')
    return redirect(redirect_url)

from urllib.parse import urlencode
import requests

from django.conf import settings as django_settings
from django.contrib import messages
from django.contrib.auth import login, update_session_auth_hash
from django.contrib.auth.decorators import login_required
from django.contrib.auth.views import LoginView
from django.db import transaction
from django.shortcuts import redirect, render
from django.utils.crypto import get_random_string
from django.views.decorators.http import require_http_methods

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo"


class DonorLoginView(LoginView):
    form_class = DonorLoginForm
    template_name = "registration/login.html"
    redirect_authenticated_user = True

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["google_oauth_configured"] = bool(
            getattr(django_settings, "GOOGLE_OAUTH_CLIENT_ID", None)
        )
        return context

    def get_success_url(self):
        url = super().get_success_url()
        login_url = reverse("login")

        if url:
            url_path = (url.split("?")[0] or "").strip().rstrip("/")
            login_path = login_url.rstrip("/")

            if url_path == login_path or url_path.endswith("/accounts/login"):
                url = None
            elif getattr(self.request.user, "is_authenticated", False) and not self.request.user.is_staff:
                if (
                    url_path in ("/accounts/profile", "/home")
                    or url_path.startswith("/accounts/profile/")
                    or url_path.startswith("/home/")
                ):
                    url = None

        if not url:
            if getattr(self.request.user, "is_authenticated", False) and self.request.user.is_staff:
                return reverse("admin_dashboard")
            return reverse("donor_notifications")

        return url


def _is_profile_complete(user):
    try:
        donor_profile = user.donor_profile
    except DonorProfile.DoesNotExist:
        return False

    return bool(donor_profile.phone and donor_profile.blood_group)


def _google_oauth_redirect_uri(request):
    """
    Stable OAuth callback URL for Google.

    Prefer explicit settings (APP_BASE_URL / GOOGLE_REDIRECT_URI) so Vercel
    preview/deployment hosts do not cause redirect_uri_mismatch.
    """
    configured = (getattr(django_settings, "GOOGLE_REDIRECT_URI", None) or "").strip()
    if configured.startswith(("http://", "https://")):
        return configured if configured.endswith("/") else f"{configured}/"

    base = (getattr(django_settings, "APP_BASE_URL", None) or "").strip().rstrip("/")
    if base.startswith(("http://", "https://")) and "localhost" not in base:
        return f"{base}/register/google/callback/"

    uri = request.build_absolute_uri("/register/google/callback/")
    if uri.startswith("http://") and (
        os.environ.get("VERCEL")
        or request.META.get("HTTP_X_FORWARDED_PROTO") == "https"
    ):
        uri = "https://" + uri[len("http://") :]
    if not uri.endswith("/"):
        uri = f"{uri}/"
    return uri


def google_login(request):
    try:
        client_id = getattr(django_settings, "GOOGLE_OAUTH_CLIENT_ID", None)
        redirect_uri = _google_oauth_redirect_uri(request)

        logger.info(
            "Google login config: client_id=%s redirect_uri=%s",
            bool(client_id),
            redirect_uri,
        )

        if not client_id or not redirect_uri:
            try:
                messages.error(request, "Google Sign-In is not configured.")
            except Exception:
                pass
            return redirect("login")

        state = get_random_string(32)
        request.session["google_oauth_state"] = state
        # Must match token exchange on callback (same host).
        request.session["google_oauth_redirect_uri"] = redirect_uri
        request.session.modified = True
        request.session.save()

        params = {
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": "openid email profile",
            "state": state,
            "access_type": "offline",
            "prompt": "select_account",
        }

        return redirect(f"{GOOGLE_AUTH_URL}?{urlencode(params)}")

    except Exception as e:
        logger.exception("Google login redirect failed: %s", e)
        try:
            messages.error(request, "Google Sign-In could not start. Please try again.")
        except Exception:
            pass
        return redirect("login")


def google_callback(request):
    try:
        state = request.GET.get("state")
        code = request.GET.get("code")

        if not state or state != request.session.get("google_oauth_state"):
            messages.error(request, "Invalid or expired Google sign-in. Please try again.")
            return redirect("login")

        request.session.pop("google_oauth_state", None)

        if not code:
            messages.error(request, "Google sign-in was cancelled or failed.")
            return redirect("login")

        client_id = getattr(django_settings, "GOOGLE_OAUTH_CLIENT_ID", None)
        client_secret = getattr(django_settings, "GOOGLE_OAUTH_CLIENT_SECRET", None)
        # Must be identical to the redirect_uri used in google_login.
        redirect_uri = (
            request.session.pop("google_oauth_redirect_uri", None)
            or _google_oauth_redirect_uri(request)
        )

        logger.info(
            "Google callback config: client_id_exists=%s client_secret_exists=%s redirect_uri=%s",
            bool(client_id),
            bool(client_secret),
            redirect_uri,
        )

        if not client_id or not client_secret or not redirect_uri:
            messages.error(request, "Google Sign-In is not configured.")
            return redirect("login")

        token_resp = requests.post(
            GOOGLE_TOKEN_URL,
            data={
                "code": code,
                "client_id": client_id,
                "client_secret": client_secret,
                "redirect_uri": redirect_uri,
                "grant_type": "authorization_code",
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=10,
        )

        logger.info(
            "Google token request status=%s redirect_uri=%s",
            token_resp.status_code,
            redirect_uri,
        )

        if not token_resp.ok:
            logger.error("Google token error response: %s", token_resp.text)
            messages.error(request, f"Google token error: {token_resp.text}")
            return redirect("donor_register")

        token_json = token_resp.json()
        access_token = token_json.get("access_token")

        if not access_token:
            logger.error("Google token missing. Response: %s", token_json)
            messages.error(request, "Google sign-in failed (no token).")
            return redirect("donor_register")

        userinfo_resp = requests.get(
            GOOGLE_USERINFO_URL,
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=10,
        )

        logger.info("Google userinfo status: %s", userinfo_resp.status_code)

        if not userinfo_resp.ok:
            logger.error("Google userinfo error response: %s", userinfo_resp.text)
            messages.error(request, f"Google userinfo error: {userinfo_resp.text}")
            return redirect("donor_register")

        userinfo = userinfo_resp.json()

        email = (userinfo.get("email") or "").strip().lower()
        name = (userinfo.get("name") or email or "User").strip()

        if not email:
            logger.error("Google userinfo missing email: %s", userinfo)
            messages.error(request, "Google account did not provide an email.")
            return redirect("donor_register")

        user = User.objects.filter(email__iexact=email).first()

        if not user:
            username = email.split("@")[0].replace(".", "_")[:30]
            base_username = username
            n = 0

            while User.objects.filter(username__iexact=username).exists():
                n += 1
                username = f"{base_username}{n}"[:30]

            with transaction.atomic():
                user = User.objects.create(
                    username=username,
                    email=email,
                    first_name=name[:30],
                    is_active=True,
                    is_staff=False,
                )
                user.set_unusable_password()
                user.save()

                UserProfile.objects.get_or_create(user=user)
                DonorProfile.objects.get_or_create(
                    user=user,
                    defaults={"phone": "", "phone_verified": False},
                )
        else:
            UserProfile.objects.get_or_create(user=user)
            DonorProfile.objects.get_or_create(
                user=user,
                defaults={"phone": "", "phone_verified": False},
            )

        login(request, user, backend="django.contrib.auth.backends.ModelBackend")

        if _is_profile_complete(user):
            return redirect("donor_notifications")
        return redirect("google_complete_profile")

    except Exception as e:
        logger.exception("Google callback crashed: %s", e)
        messages.error(request, f"Google callback crashed: {str(e)}")
        return redirect("donor_register")


@login_required
@require_http_methods(["GET", "POST"])
def google_complete_profile(request):
    user = request.user
    donor_profile, _ = DonorProfile.objects.get_or_create(
        user=user,
        defaults={"phone": "", "phone_verified": False},
    )
    user_profile, _ = UserProfile.objects.get_or_create(user=user)

    from .forms import GoogleProfileCompletionForm

    if request.method == "GET":
        initial = {
            "mobile": donor_profile.phone or "",
            "gender": user_profile.gender or "",
            "date_of_birth": user_profile.date_of_birth,
            "alternate_mobile": user_profile.alternate_mobile or "",
            "preferred_language": user_profile.preferred_language or "",
            "preferred_contact_time": user_profile.preferred_contact_time or "",
            "occupation": user_profile.occupation or "",
            "emergency_contact_name": user_profile.emergency_contact_name or "",
            "emergency_contact_number": user_profile.emergency_contact_number or "",
            "state": user_profile.state or "",
            "city": user_profile.city or "",
            "area": user_profile.area or "",
            "pincode": user_profile.pincode or "",
            "last_lat": donor_profile.last_lat,
            "last_lng": donor_profile.last_lng,
            "weight_kg": user_profile.weight_kg,
            "donated_before": "yes" if user_profile.donated_before is True else ("no" if user_profile.donated_before is False else ""),
            "last_donation_date": user_profile.last_donation_date,
            "medical_conditions": "yes" if user_profile.medical_conditions is True else ("no" if user_profile.medical_conditions is False else ""),
            "currently_healthy": "yes" if user_profile.currently_healthy is True else ("no" if user_profile.currently_healthy is False else ""),
            "emergency_available": "yes" if user_profile.emergency_available else "no",
            "preferred_contact": user_profile.preferred_contact or "call",
            "consent_contact": user_profile.consent_contact,
            "consent_terms": user_profile.consent_terms,
            "blood_group": donor_profile.blood_group or "",
        }
        form = GoogleProfileCompletionForm(initial=initial)
        return render(
            request,
            "registration/google_complete_profile.html",
            {
                "form": form,
                "google_email": user.email,
                "google_name": user.first_name or user.username,
            },
        )

    form = GoogleProfileCompletionForm(request.POST, request.FILES)
    if not form.is_valid():
        return render(
            request,
            "registration/google_complete_profile.html",
            {
                "form": form,
                "google_email": user.email,
                "google_name": user.first_name or user.username,
            },
            status=400,
        )

    data = form.cleaned_data

    password = data.get("password")
    if password:
        user.set_password(password)
        user.save(update_fields=["password"])
        update_session_auth_hash(request, user)

    user_profile.gender = data.get("gender") or None
    user_profile.date_of_birth = data.get("date_of_birth")
    user_profile.state = data.get("state") or ""
    user_profile.city = data.get("city") or ""
    user_profile.area = data.get("area") or ""
    user_profile.pincode = data.get("pincode") or ""
    user_profile.weight_kg = data.get("weight_kg")

    def _bool_choice_local(val):
        if not val or val == "":
            return None
        return val.lower() == "yes"

    user_profile.donated_before = _bool_choice_local(data.get("donated_before"))
    user_profile.last_donation_date = data.get("last_donation_date")
    user_profile.medical_conditions = _bool_choice_local(data.get("medical_conditions"))
    user_profile.currently_healthy = _bool_choice_local(data.get("currently_healthy"))
    user_profile.emergency_available = (
        _bool_choice_local(data.get("emergency_available"))
        if data.get("emergency_available")
        else True
    )
    user_profile.preferred_contact = data.get("preferred_contact") or "call"
    user_profile.consent_contact = bool(data.get("consent_contact"))
    user_profile.consent_terms = bool(data.get("consent_terms"))
    user_profile.alternate_mobile = data.get("alternate_mobile") or ""
    user_profile.preferred_language = data.get("preferred_language") or ""
    user_profile.preferred_contact_time = data.get("preferred_contact_time") or ""
    user_profile.occupation = data.get("occupation") or ""
    user_profile.emergency_contact_name = data.get("emergency_contact_name") or ""
    user_profile.emergency_contact_number = data.get("emergency_contact_number") or ""

    if data.get("profile_photo"):
        user_profile.profile_photo = data["profile_photo"]

    user_profile.save()

    donor_profile.phone = data.get("mobile")
    donor_profile.blood_group = data.get("blood_group") or None
    update_fields = ["phone", "blood_group"]

    lat, lng = data.get("last_lat"), data.get("last_lng")
    if lat is not None and lng is not None:
        donor_profile.last_lat = lat
        donor_profile.last_lng = lng
        donor_profile.location_updated_at = timezone.now()
        update_fields.extend(["last_lat", "last_lng", "location_updated_at"])

    if data.get("city"):
        donor_profile.city = data.get("city") or ""
        update_fields.append("city")

    donor_profile.save(update_fields=update_fields)

    return redirect("donor_notifications")

# ----- Donor registration (web): form -> OTP verification -> blood group modal -> auto login -----

OTP_EXPIRY_MINUTES = 15


def _normalize_phone_for_sms(phone):
    """Normalize phone for SMS: Indian 10-digit -> keep as-is for Fast2SMS; add +91 for Twilio (in otp_service)."""
    p = (phone or '').strip().replace(' ', '').replace('-', '')
    if len(p) == 10 and p.isdigit() and p[0] in '6789':
        return p  # 10-digit Indian: Fast2SMS uses as-is; otp_service will add +91 for Twilio
    if p.startswith('+91') and len(p) == 13 and p[3:].isdigit():
        return p[3:]  # +919618394701 -> 9618394701
    if p.startswith('91') and len(p) == 12 and p[2:].isdigit():
        return p[2:]
    return p


def _send_otp_to_phone(phone):
    """Generate 6-digit OTP (or use Twilio Verify), save to DonorOTP, and send via SMS. Returns OTP code or sentinel."""
    phone_clean = (phone or '').strip()
    backend = getattr(django_settings, 'OTP_SMS_BACKEND', 'console')
    logger.info('OTP send: backend=%s, phone=%s', backend, phone_clean)

    if backend == 'twilio_verify':
        # Twilio Verify sends its own OTP; we store a sentinel and verify via API later
        try:
            from .otp_service import send_otp_sms
            send_phone = _normalize_phone_for_sms(phone_clean)
            send_otp_sms(send_phone, None)
        except Exception as e:
            logger.warning('Twilio Verify send failed: %s', e)
        DonorOTP.objects.update_or_create(
            phone=phone_clean,
            defaults={'otp_code': 'TWILIO_VERIFY'}
        )
        return 'TWILIO_VERIFY'
    # Default: generate OTP, store, send via fast2sms/twilio/msg91/console
    code = ''.join([str(random.randint(0, 9)) for _ in range(6)])
    DonorOTP.objects.update_or_create(
        phone=phone_clean,
        defaults={'otp_code': code}
    )
    try:
        from .otp_service import send_otp_sms
        send_phone = _normalize_phone_for_sms(phone_clean)
        send_otp_sms(send_phone, code)
    except Exception as e:
        logger.warning('OTP SMS send failed: %s', e)
    return code


def _bool_choice(val):
    if not val or val == '':
        return None
    return val.lower() == 'yes'


@require_http_methods(["GET", "POST"])
def donor_register(request):
    """Step 1: Show registration form. POST creates donor User + profiles, then blood group."""
    if request.method == 'GET':
        form = DonorRegistrationForm()
        err = request.GET.get('err')
        err_message = {'session_expired': 'Session expired. Please complete registration again.', 'invalid_blood_group': 'Invalid blood group. Please try again.'}.get(err, '')
        google_oauth_configured = bool(getattr(django_settings, 'GOOGLE_OAUTH_CLIENT_ID', None))
        return render(request, 'registration/register.html', {
            'form': form,
            'register_error': err_message,
            'google_oauth_configured': google_oauth_configured,
        })
    # POST (include FILES for profile_photo)
    form = DonorRegistrationForm(request.POST, request.FILES)
    if not form.is_valid():
        return JsonResponse({'success': False, 'errors': form.errors}, status=400)
    data = form.cleaned_data
    username = data['username'].strip().lower()
    # Donor: create User, UserProfile, DonorProfile; frontend shows Blood Donation popup -> Thank You popup -> blood group
    mobile = (data.get('mobile') or '').strip()
    with transaction.atomic():
        user = User.objects.create_user(
            username=username,
            email='',
            password=data['password'],
            first_name=username,
            is_active=True,
        )
        UserProfile.objects.create(
            user=user,
            gender=data.get('gender') or None,
            date_of_birth=data.get('date_of_birth'),
            state=data.get('state') or '',
            city=data.get('city') or '',
            area=data.get('area') or '',
            pincode=data.get('pincode') or '',
            weight_kg=data.get('weight_kg'),
            donated_before=_bool_choice(data.get('donated_before')),
            last_donation_date=data.get('last_donation_date'),
            medical_conditions=_bool_choice(data.get('medical_conditions')),
            currently_healthy=_bool_choice(data.get('currently_healthy')),
            emergency_available=_bool_choice(data.get('emergency_available')) if data.get('emergency_available') else True,
            preferred_contact=data.get('preferred_contact') or 'call',
            consent_contact=bool(data.get('consent_contact')),
            consent_terms=bool(data.get('consent_terms')),
            alternate_mobile=data.get('alternate_mobile') or '',
            preferred_language=data.get('preferred_language') or '',
            preferred_contact_time=data.get('preferred_contact_time') or '',
            occupation=data.get('occupation') or '',
            emergency_contact_name=data.get('emergency_contact_name') or '',
            emergency_contact_number=data.get('emergency_contact_number') or '',
            profile_photo=data.get('profile_photo'),
        )
        last_lat = request.POST.get('last_lat')
        last_lng = request.POST.get('last_lng')
        try:
            last_lat = Decimal(str(last_lat).strip()) if last_lat and str(last_lat).strip() else None
            last_lng = Decimal(str(last_lng).strip()) if last_lng and str(last_lng).strip() else None
        except Exception:
            last_lat = last_lng = None
        DonorProfile.objects.create(
            user=user,
            phone=mobile,
            blood_group=None,
            phone_verified=False,
            last_lat=last_lat,
            last_lng=last_lng,
            location_updated_at=timezone.now() if (last_lat and last_lng) else None,
        )
    request.session['pending_verification_user_id'] = user.pk
    request.session['pending_verification_phone'] = mobile
    _send_otp_to_phone(mobile)
    return JsonResponse({
        'success': True,
        'step': 'otp',
        'role': 'donor',
        'message': 'OTP sent to your registered mobile number. Enter it below to verify.',
    })


@require_http_methods(["POST"])
def donor_verify_otp(request):
    """Verify OTP sent to registered mobile; on success set phone_verified=True and return step blood_group."""
    user_id = request.session.get('pending_verification_user_id')
    phone = request.session.get('pending_verification_phone')
    if not user_id or not phone:
        return JsonResponse({'success': False, 'message': 'Session expired. Please complete registration again.'}, status=400)
    if request.content_type and 'application/json' in request.content_type and request.body:
        try:
            data = json.loads(request.body)
        except json.JSONDecodeError:
            data = {}
    else:
        data = request.POST
    otp_entered = (data.get('otp') or '').strip()
    if not otp_entered:
        return JsonResponse({'success': False, 'message': 'Please enter the OTP.'}, status=400)
    try:
        donor_otp = DonorOTP.objects.get(phone=phone)
    except DonorOTP.DoesNotExist:
        return JsonResponse({'success': False, 'message': 'Invalid or expired OTP. Request a new one.'}, status=400)
    from datetime import timedelta
    if timezone.now() - donor_otp.created_at > timedelta(minutes=OTP_EXPIRY_MINUTES):
        return JsonResponse({'success': False, 'message': 'OTP expired. Please request a new one.'}, status=400)

    # Twilio Verify: check via API instead of comparing to stored code
    if donor_otp.otp_code == 'TWILIO_VERIFY':
        from .otp_service import check_otp_twilio_verify
        ok, err_msg = check_otp_twilio_verify(phone, otp_entered)
        if not ok:
            return JsonResponse({'success': False, 'message': err_msg or 'Invalid OTP.'}, status=400)
    elif donor_otp.otp_code != otp_entered:
        return JsonResponse({'success': False, 'message': 'Invalid OTP. Please try again.'}, status=400)

    user = get_object_or_404(User, pk=user_id)
    profile = get_object_or_404(DonorProfile, user=user)
    profile.phone_verified = True
    profile.save(update_fields=['phone_verified'])
    donor_otp.delete()
    return JsonResponse({
        'success': True,
        'step': 'blood_group',
        'message': 'Mobile verified. Please select your blood group.',
    })


@require_http_methods(["POST"])
def donor_resend_otp(request):
    """Resend OTP to pending_verification_phone."""
    phone = request.session.get('pending_verification_phone')
    if not phone:
        return JsonResponse({'success': False, 'message': 'Session expired.'}, status=400)
    _send_otp_to_phone(phone)
    return JsonResponse({'success': True, 'message': 'OTP sent again to your mobile.'})


@require_http_methods(["POST"])
def donor_register_select_blood_group(request):
    """Step 3: Save blood group, then redirect to login so user signs in and gets a proper session."""
    user_id = request.session.get('pending_verification_user_id')
    if not user_id:
        return HttpResponseRedirect('/register/?err=session_expired')
    if request.content_type and 'application/json' in request.content_type and request.body:
        try:
            data = json.loads(request.body)
        except json.JSONDecodeError:
            data = {}
    else:
        data = request.POST
    blood_group = (data.get('blood_group') or '').strip()
    if blood_group not in dict(DonorProfile.BLOOD_GROUP_CHOICES):
        return HttpResponseRedirect('/register/?err=invalid_blood_group')
    user = get_object_or_404(User, pk=user_id)
    profile = get_object_or_404(DonorProfile, user=user)
    profile.blood_group = blood_group
    profile.save(update_fields=['blood_group'])
    request.session.pop('pending_verification_user_id', None)
    pending_phone = request.session.pop('pending_verification_phone', None) or profile.phone
    if pending_phone:
        try:
            from careapp.services.whatsapp_messaging import send_whatsapp_welcome_on_register
            send_whatsapp_welcome_on_register(user, pending_phone)
        except Exception:
            logger.exception('WhatsApp welcome on register failed')
    # Redirect to login with next=/notifications/ so user signs in and is then redirected to dashboard
    return HttpResponseRedirect('/accounts/login/?next=/notifications/&registered=1')


# ---------------------------------------------------------------------------
# Excel Analytics (Power BI-style dashboard)
# ---------------------------------------------------------------------------

def _excel_upload_dir():
    """Directory for temporary Excel uploads (per-session)."""
    d = os.path.join(django_settings.MEDIA_ROOT, 'excel_uploads')
    os.makedirs(d, exist_ok=True)
    return d


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["GET", "POST"])
def excel_analytics_upload(request):
    """Upload Excel file; save to disk and redirect to dashboard. GET redirects to live dashboard (default)."""
    if request.method == 'GET':
        return redirect('excel_analytics_live')
    file = request.FILES.get('excel_file')
    if not file:
        messages.error(request, 'Please select an Excel file (.xlsx or .xls).')
        return redirect('excel_analytics_upload')
    name = (file.name or '').strip().lower()
    if not name.endswith(('.xlsx', '.xls')):
        messages.error(request, 'Only .xlsx and .xls files are allowed.')
        return redirect('excel_analytics_upload')
    upload_dir = _excel_upload_dir()
    ext = '.xlsx' if name.endswith('.xlsx') else '.xls'
    safe_name = f"{uuid.uuid4().hex}{ext}"
    path = os.path.join(upload_dir, safe_name)
    try:
        with open(path, 'wb') as f:
            for chunk in file.chunks():
                f.write(chunk)
        request.session['excel_analytics_path'] = path
        messages.success(request, 'File uploaded. View your analytics dashboard below.')
        return redirect('excel_analytics_dashboard')
    except Exception as e:
        logger.exception('Excel upload failed')
        messages.error(request, f'Upload failed: {e}')
        return redirect('excel_analytics_upload')


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["GET"])
def excel_analytics_dashboard(request):
    """Power BI-style dashboard: charts and summary from last uploaded Excel."""
    path = request.session.get('excel_analytics_path')
    if not path or not os.path.isfile(path):
        messages.info(request, 'Upload an Excel file to see analytics and charts.')
        return redirect('excel_analytics_upload')
    try:
        df = read_excel_to_dataframe(path)
        if df.empty:
            messages.warning(request, 'The uploaded file has no data in the first sheet.')
            return redirect('excel_analytics_upload')
        result = build_charts_and_summary(df)
    except Exception as e:
        logger.exception('Excel dashboard failed')
        messages.error(request, f'Could not read file: {e}')
        return redirect('excel_analytics_upload')
    context = {
        'charts': result.get('charts', []),
        'summary_table': result.get('summary_table', []),
        'row_count': result.get('row_count', 0),
        'column_count': result.get('column_count', 0),
        'error': result.get('error'),
        'sheet_name': (getattr(df.columns, 'name', None) or 'Sheet1') if hasattr(df, 'columns') else 'Sheet1',
        'data_source': 'upload',
    }
    return render(request, 'excel_analytics_dashboard.html', context)


@login_required
@user_passes_test(is_staff_user)
@require_http_methods(["GET"])
def excel_analytics_live(request):
    """Power BI-style dashboard with data from backend (BloodRequest + DonorProfile). No file upload."""
    import pandas as pd
    from django.utils import timezone

    # Build DataFrame from Django models (same shape as export)
    requests_qs = BloodRequest.objects.all().order_by('-created_at')[:5000]
    if requests_qs.exists():
        rows = []
        for r in requests_qs:
            rows.append({
                'request_id': str(r.request_id) if r.request_id else '',
                'created_at': r.created_at.date() if r.created_at else None,
                'blood_group': r.blood_group or '',
                'urgency': r.urgency or '',
                'status': r.status or '',
                'city': r.city or '',
                'state': r.state or '',
                'source': r.source or '',
                'units_needed': r.units_needed,
                'patient_age': r.patient_age,
                'sla_minutes': r.sla_minutes,
                'closure_type': r.closure_type or '',
                'closure_reason': r.closure_reason or '',
            })
        df = pd.DataFrame(rows)
    else:
        # Sample data from model choices so charts always render
        blood_groups = [c[0] for c in BloodRequest.BLOOD_GROUP_CHOICES]
        urgencies = [c[0] for c in BloodRequest.URGENCY_CHOICES]
        statuses = [c[0] for c in BloodRequest.STATUS_CHOICES]
        sources = [c[0] for c in BloodRequest.SOURCE_CHOICES]
        closure_types = [c[0] for c in BloodRequest.CLOSURE_TYPE_CHOICES]
        closure_reasons = [c[0] for c in BloodRequest.CLOSURE_REASON_CHOICES]
        cities = ['Bhubaneswar', 'Cuttack', 'Puri', 'Berhampur', 'Rourkela', 'Bangalore', 'Mumbai', 'Delhi']
        states = ['Odisha', 'Karnataka', 'Maharashtra', 'Delhi', 'Tamil Nadu']
        base_date = timezone.now().date()
        rows = []
        for i in range(200):
            rows.append({
                'request_id': f'req-{1000 + i}',
                'created_at': base_date - timedelta(days=random.randint(0, 365)),
                'blood_group': random.choice(blood_groups),
                'urgency': random.choice(urgencies),
                'status': random.choice(statuses),
                'city': random.choice(cities),
                'state': random.choice(states),
                'source': random.choice(sources),
                'units_needed': random.randint(1, 4),
                'patient_age': random.randint(1, 80) if random.random() < 0.8 else None,
                'sla_minutes': random.choice([60, 90, 120, 180]) if random.random() < 0.7 else None,
                'closure_type': random.choice(closure_types + ['']),
                'closure_reason': random.choice(closure_reasons + ['']),
            })
        df = pd.DataFrame(rows)

    result = build_charts_and_summary(df)
    context = {
        'charts': result.get('charts', []),
        'summary_table': result.get('summary_table', []),
        'row_count': result.get('row_count', 0),
        'column_count': result.get('column_count', 0),
        'error': result.get('error'),
        'sheet_name': 'Live (Blood Requests)',
        'data_source': 'live',
    }
    return render(request, 'excel_analytics_dashboard.html', context)
