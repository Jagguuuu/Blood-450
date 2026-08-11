"""JWT query-string auth for Flutter WebSocket connections."""
from urllib.parse import parse_qs

from channels.auth import AuthMiddlewareStack
from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.contrib.auth.models import AnonymousUser


@database_sync_to_async
def _user_from_jwt(token: str):
    try:
        from django.contrib.auth import get_user_model
        from rest_framework_simplejwt.tokens import AccessToken
        access = AccessToken(token)
        return get_user_model().objects.get(pk=access['user_id'])
    except Exception:
        return AnonymousUser()


class JWTQueryAuthMiddleware(BaseMiddleware):
    async def __call__(self, scope, receive, send):
        if scope.get('type') == 'websocket':
            query = parse_qs(scope.get('query_string', b'').decode())
            token = (query.get('token') or [None])[0]
            if token and (not scope.get('user') or not scope['user'].is_authenticated):
                scope['user'] = await _user_from_jwt(token)
        return await super().__call__(scope, receive, send)


def JWTAuthMiddlewareStack(inner):
    return JWTQueryAuthMiddleware(AuthMiddlewareStack(inner))
