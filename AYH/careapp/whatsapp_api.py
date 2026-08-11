"""
REST API for WhatsApp chat (admin + donor) and outbound send.
"""
from django.db.models import Q, Sum
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle

from careapp.models import BloodRequest, DonorProfile
from careapp.serializers_whatsapp import (
    WhatsAppConversationSerializer,
    WhatsAppMessageLogSerializer,
    WhatsAppMessageSerializer,
)
from careapp.services.whatsapp_service import whatsapp_service
from careapp.tasks.whatsapp_tasks import retry_failed_whatsapp_log, send_whatsapp_text_task
from careapp.whatsapp_models import WhatsAppConversation, WhatsAppMessage, WhatsAppMessageLog


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def whatsapp_unread_count(request):
    if not request.user.is_staff:
        total = WhatsAppConversation.objects.filter(
            donor_user=request.user,
        ).aggregate(t=Sum('unread_donor_count'))['t'] or 0
        return Response({'unread': total})
    total = WhatsAppConversation.objects.aggregate(t=Sum('unread_admin_count'))['t'] or 0
    return Response({'unread': total})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def whatsapp_conversations_list(request):
    if not request.user.is_staff:
        qs = WhatsAppConversation.objects.filter(donor_user=request.user)
        if not qs.exists():
            dp = getattr(request.user, 'donor_profile', None)
            if dp and dp.phone:
                whatsapp_service.get_or_create_conversation(
                    dp.phone,
                    donor_profile=dp,
                    donor_user=request.user,
                )
                qs = WhatsAppConversation.objects.filter(donor_user=request.user)
    else:
        qs = WhatsAppConversation.objects.select_related(
            'donor_profile', 'donor_user', 'active_blood_request',
        )
        search = request.GET.get('q', '').strip()
        if search:
            qs = qs.filter(
                Q(phone__icontains=search)
                | Q(display_name__icontains=search)
                | Q(donor_user__username__icontains=search)
            )
    page_size = min(int(request.GET.get('page_size', 30)), 100)
    qs = qs.order_by('-last_message_at', '-updated_at')[:page_size]
    return Response(WhatsAppConversationSerializer(qs, many=True).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def whatsapp_conversation_messages(request, conversation_id):
    conv = get_object_or_404(WhatsAppConversation, pk=conversation_id)
    if not request.user.is_staff and conv.donor_user_id != request.user.id:
        return Response({'error': 'Forbidden'}, status=status.HTTP_403_FORBIDDEN)

    page = max(int(request.GET.get('page', 1)), 1)
    page_size = min(int(request.GET.get('page_size', 50)), 100)
    offset = (page - 1) * page_size
    msgs = WhatsAppMessage.objects.filter(conversation=conv).order_by('-created_at')
    total = msgs.count()
    batch = list(msgs[offset:offset + page_size])[::-1]

    if request.user.is_staff:
        whatsapp_service.mark_conversation_read(conv.id, by_admin=True)
    else:
        whatsapp_service.mark_conversation_read(conv.id, by_admin=False)

    return Response({
        'conversation': WhatsAppConversationSerializer(conv).data,
        'messages': WhatsAppMessageSerializer(batch, many=True).data,
        'page': page,
        'page_size': page_size,
        'total': total,
        'has_more': offset + page_size < total,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def whatsapp_send_message(request, conversation_id):
    conv = get_object_or_404(WhatsAppConversation, pk=conversation_id)
    body = (request.data.get('body') or request.data.get('message') or '').strip()
    if not body:
        return Response({'error': 'body is required'}, status=status.HTTP_400_BAD_REQUEST)

    if request.user.is_staff:
        result = whatsapp_service.send_admin_reply(conv, body, request.user)
    elif conv.donor_user_id == request.user.id:
        result = whatsapp_service.send_text_message(
            conv.phone,
            body,
            conversation=conv,
            sender_type=WhatsAppMessage.SENDER_DONOR,
        )
    else:
        return Response({'error': 'Forbidden'}, status=status.HTTP_403_FORBIDDEN)

    if not result.get('ok'):
        return Response({'error': result.get('error')}, status=status.HTTP_502_BAD_GATEWAY)
    return Response(result)


@api_view(['POST'])
@permission_classes([IsAdminUser])
def whatsapp_send_generic(request):
    phone = request.data.get('phone', '')
    message = request.data.get('message', '')
    if not phone or not message:
        return Response({'error': 'phone and message required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        send_whatsapp_text_task.delay(phone, message)
        queued = True
    except Exception:
        result = whatsapp_service.send_text_message(phone, message)
        return Response({**result, 'queued': False})
    return Response({'ok': True, 'queued': queued})


@api_view(['POST'])
@permission_classes([IsAdminUser])
def whatsapp_blood_alert(request):
    blood_request_id = request.data.get('blood_request_id')
    donor_profile_id = request.data.get('donor_profile_id')
    if not blood_request_id or not donor_profile_id:
        return Response({'error': 'blood_request_id and donor_profile_id required'}, status=400)
    br = get_object_or_404(BloodRequest, pk=blood_request_id)
    dp = get_object_or_404(DonorProfile, pk=donor_profile_id)
    result = whatsapp_service.send_blood_request_alert(br, dp)
    status_code = status.HTTP_200_OK if result.get('ok') else status.HTTP_502_BAD_GATEWAY
    return Response(result, status=status_code)


@api_view(['GET'])
@permission_classes([IsAdminUser])
def whatsapp_logs_list(request):
    qs = WhatsAppMessageLog.objects.all().order_by('-sent_at')[:100]
    return Response(WhatsAppMessageLogSerializer(qs, many=True).data)


@api_view(['POST'])
@permission_classes([IsAdminUser])
def whatsapp_retry_log(request, log_id):
    try:
        retry_failed_whatsapp_log.delay(log_id)
        return Response({'ok': True, 'queued': True})
    except Exception:
        result = retry_failed_whatsapp_log(log_id)
        return Response(result or {'ok': False})
