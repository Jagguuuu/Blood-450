"""
URL configuration for AYH project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.contrib.auth import views as auth_views
from django.urls import path, include, re_path
from django.views.generic import RedirectView
from careapp.views import DonorLoginView
from careapp import api_views as careapp_api_views

urlpatterns = [
    # Django Admin
    path('admin/', admin.site.urls),
    
    # Web Authentication (Django Templates) – custom login so email/username is case-insensitive
    path('accounts/login/', DonorLoginView.as_view(), name='login'),
    # Mobile-friendly password reset confirm (before auth.urls include)
    path(
        'accounts/reset/<uidb64>/<token>/',
        auth_views.PasswordResetConfirmView.as_view(
            template_name='registration/password_reset_confirm.html',
            success_url='/accounts/reset/done/',
        ),
        name='password_reset_confirm',
    ),
    path(
        'accounts/reset/done/',
        auth_views.PasswordResetCompleteView.as_view(
            template_name='registration/password_reset_complete.html',
        ),
        name='password_reset_complete',
    ),
    path('accounts/', include('django.contrib.auth.urls')),
    path('login/', RedirectView.as_view(url='/accounts/login/', permanent=False), name='login_alias'),
    
    # Public API root: GET /api/ or GET /api returns 200 (no auth). Must be before path('api/', include(...)).
    re_path(r'^api/?$', careapp_api_views.public_api_root, name='api-root-public'),
    # REST API Endpoints (for Flutter)
    path('api/', include('careapp.api_urls')),
    
    # Web Interface (Django Templates) - careapp first so /register/google/ etc. are not caught by home redirect
    path('', include('careapp.urls')),
    path('', RedirectView.as_view(url='/accounts/login/', permanent=False), name='home'),
]
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
