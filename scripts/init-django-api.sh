#!/bin/bash
set -euo pipefail

# kimi-backend: Django + DRF + PostgreSQL + Docker scaffold
# Usage: bash init-django-api.sh my-project

PROJECT_NAME="${1:-django-api}"
DIR="$PWD/$PROJECT_NAME"

echo "🔧 Scaffolding Django API: $PROJECT_NAME"
mkdir -p "$DIR" && cd "$DIR"

# ─── requirements.txt ───
cat > requirements.txt << 'REQ'
# ─── Django & DRF ───────────────────────────────────────────────
Django>=5.1,<5.2
djangorestframework>=3.15.0
django-cors-headers>=4.4.0
django-filter>=24.0
django-extensions>=3.2.0

# ─── Database ─────────────────────────────────────────────────
psycopg[binary]>=3.2.0

# ─── Auth ───────────────────────────────────────────────────────
dj-rest-auth>=6.0.0
django-allauth>=64.0.0
PyJWT>=2.9.0
cryptography>=43.0.0

# ─── Async & Caching ────────────────────────────────────────────
channels>=4.0.0
channels-redis>=4.2.0
redis>=5.0.0

# ─── Utilities ───────────────────────────────────────────────────
celery>=5.4.0
gunicorn>=23.0.0
whitenoise>=6.7.0
python-dotenv>=1.0.0
Pillow>=10.4.0
requests>=2.32.0

# ─── Testing ───────────────────────────────────────────────────
pytest>=8.3.0
pytest-django>=4.8.0
pytest-cov>=5.0.0
factory-boy>=3.3.0
faker>=28.0.0

# ─── Dev Tools ───────────────────────────────────────────────────
black>=24.8.0
isort>=5.13.0
flake8>=7.1.0
mypy>=1.11.0
django-stubs>=5.0.0
djangorestframework-stubs>=3.15.0
pre-commit>=3.8.0
REQ

# ─── requirements-dev.txt ───
cat > requirements-dev.txt << 'REQDEV'
-r requirements.txt
ipython>=8.26.0
django-debug-toolbar>=4.4.0
django-silk>=5.1.0
REQDEV

# ─── pyproject.toml ───
cat > pyproject.toml << 'PYPROJECT'
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "PROJECT_NAME"
version = "1.0.0"
description = "Django + DRF + PostgreSQL API"
requires-python = ">=3.11"

[tool.setuptools]
packages = ["PROJECT_NAME"]

[tool.black]
line-length = 100
target-version = ['py311']
include = '\.pyi?$'

[tool.isort]
profile = "black"
line_length = 100

[tool.mypy]
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
ignore_missing_imports = true
plugins = ["mypy_django_plugin.main", "mypy_drf_plugin.main"]

[tool.django-stubs]
django_settings_module = "PROJECT_NAME.settings"

[tool.pytest.ini_options]
DJANGO_SETTINGS_MODULE = "PROJECT_NAME.settings"
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = "-v --tb=short"
PYPROJECT
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" pyproject.toml && rm pyproject.toml.bak

# ─── .env.example ───
cat > .env.example << 'ENV'
# Django
DJANGO_SECRET_KEY=change-me-in-production-min-50-characters-long
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
DJANGO_SETTINGS_MODULE=PROJECT_NAME.settings

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/PROJECT_NAME
DATABASE_POOL_SIZE=20

# Redis
REDIS_URL=redis://localhost:6379/0

# Email
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
EMAIL_HOST=
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=

# Cors
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173

# Celery
CELERY_BROKER_URL=redis://localhost:6379/1
CELERY_RESULT_BACKEND=redis://localhost:6379/2
ENV
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" .env.example && rm .env.example.bak

# ─── .env ───
cp .env.example .env

# ─── manage.py ───
cat > manage.py << 'MANAGE'
#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys


def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'PROJECT_NAME.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
MANAGE
chmod +x manage.py
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" manage.py && rm manage.py.bak

# ─── Project package ───
mkdir -p "$PROJECT_NAME"

# ─── __init__.py ───
cat > "$PROJECT_NAME/__init__.py" << 'INIT'
__version__ = "1.0.0"
INIT

# ─── settings.py ───
cat > "$PROJECT_NAME/settings.py" << 'SETTINGS'
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'change-me-in-production')
DEBUG = os.getenv('DJANGO_DEBUG', 'True').lower() == 'true'
ALLOWED_HOSTS = os.getenv('DJANGO_ALLOWED_HOSTS', 'localhost').split(',')

# ─── Apps ────────────────────────────────────────────────────────────────────
DJANGO_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
]

THIRD_PARTY_APPS = [
    'rest_framework',
    'corsheaders',
    'django_filters',
    'drf_spectacular',
]

LOCAL_APPS = [
    'apps.users',
    'apps.core',
]

INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

# ─── Middleware ──────────────────────────────────────────────────────────────
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# ─── URLs ────────────────────────────────────────────────────────────────────
ROOT_URLCONF = 'PROJECT_NAME.urls'

# ─── Templates ─────────────────────────────────────────────────────────────────
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'PROJECT_NAME.wsgi.application'
ASGI_APPLICATION = 'PROJECT_NAME.asgi.application'

# ─── Database ────────────────────────────────────────────────────────────────
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME', 'PROJECT_NAME'),
        'USER': os.getenv('DB_USER', 'postgres'),
        'PASSWORD': os.getenv('DB_PASSWORD', 'postgres'),
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
    }
}

# ─── Cache ───────────────────────────────────────────────────────────────────
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': os.getenv('REDIS_URL', 'redis://localhost:6379/0'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}

# ─── Channels ─────────────────────────────────────────────────────────────────
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [os.getenv('REDIS_URL', 'redis://localhost:6379/0')],
        },
    },
}

# ─── Celery ──────────────────────────────────────────────────────────────────
CELERY_BROKER_URL = os.getenv('CELERY_BROKER_URL', 'redis://localhost:6379/1')
CELERY_RESULT_BACKEND = os.getenv('CELERY_RESULT_BACKEND', 'redis://localhost:6379/2')
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'

# ─── Auth ────────────────────────────────────────────────────────────────────
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# ─── DRF ─────────────────────────────────────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.SessionAuthentication',
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ],
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/minute',
        'user': '1000/minute',
    },
}

# ─── JWT ─────────────────────────────────────────────────────────────────────
from datetime import timedelta
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=15),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
}

# ─── CORS ────────────────────────────────────────────────────────────────────
CORS_ALLOWED_ORIGINS = [
    origin.strip() for origin in os.getenv('CORS_ALLOWED_ORIGINS', 'http://localhost:3000').split(',')
]

# ─── Static & Media ──────────────────────────────────────────────────────────
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# ─── Internationalization ──────────────────────────────────────────────────
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# ─── Default primary key ─────────────────────────────────────────────────────
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ─── Logging ───────────────────────────────────────────────────────────────────
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {'class': 'logging.StreamHandler'},
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': 'logs/django.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 10,
        },
    },
    'root': {
        'handlers': ['console', 'file'],
        'level': 'INFO',
    },
}
SETTINGS
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" "$PROJECT_NAME/settings.py" && rm "$PROJECT_NAME/settings.py.bak"

# ─── urls.py ───
cat > "$PROJECT_NAME/urls.py" << 'URLS'
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/auth/', include('apps.users.urls')),
    path('api/v1/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/v1/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='docs'),
    path('api/v1/health/', include('apps.core.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
URLS

# ─── wsgi.py ───
cat > "$PROJECT_NAME/wsgi.py" << 'WSGI'
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'PROJECT_NAME.settings')
application = get_wsgi_application()
WSGI
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" "$PROJECT_NAME/wsgi.py" && rm "$PROJECT_NAME/wsgi.py.bak"

# ─── asgi.py ───
cat > "$PROJECT_NAME/asgi.py" << 'ASGI'
import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'PROJECT_NAME.settings')

application = ProtocolTypeRouter({
    'http': get_asgi_application(),
    # 'websocket': AuthMiddlewareStack(URLRouter(websocket_urlpatterns)),
})
ASGI
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" "$PROJECT_NAME/asgi.py" && rm "$PROJECT_NAME/asgi.py.bak"

# ─── apps/__init__.py ───
mkdir -p apps/{users,core}
touch apps/__init__.py

# ─── apps/users/__init__.py ───
cat > apps/users/__init__.py << 'INIT'
default_app_config = 'apps.users.apps.UsersConfig'
INIT

# ─── apps/users/apps.py ───
cat > apps/users/apps.py << 'APPS'
from django.apps import AppConfig

class UsersConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.users'
    verbose_name = 'Users'
APPS

# ─── apps/users/models.py ───
cat > apps/users/models.py << 'MODELS'
import uuid
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models
from django.utils import timezone

from apps.core.models import BaseModel


class User(AbstractBaseUser, PermissionsMixin, BaseModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True, db_index=True)
    name = models.CharField(max_length=255, blank=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    role = models.CharField(max_length=50, default='user', db_index=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['name']

    class Meta:
        db_table = 'users'
        ordering = ['-created_at']

    def __str__(self):
        return self.email
MODELS

# ─── apps/users/serializers.py ───
cat > apps/users/serializers.py << 'SERIALIZERS'
from rest_framework import serializers
from .models import User


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'name', 'role', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_at']


class UserCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ['email', 'name', 'password']

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)
SERIALIZERS

# ─── apps/users/views.py ───
cat > apps/users/views.py << 'VIEWS'
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenObtainPairView
from .models import User
from .serializers import UserSerializer, UserCreateSerializer


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserCreateSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


class MeView(generics.RetrieveAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


class UserDetailView(generics.RetrieveAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'id'

    def get_object(self):
        obj = super().get_object()
        # BOLA prevention: only allow access to own data
        if self.request.user.id != obj.id:
            raise generics.NotFound('User not found')
        return obj
VIEWS

# ─── apps/users/urls.py ───
cat > apps/users/urls.py << 'URLS'
from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import RegisterView, MeView, UserDetailView

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', TokenObtainPairView.as_view(), name='login'),
    path('refresh/', TokenRefreshView.as_view(), name='refresh'),
    path('me/', MeView.as_view(), name='me'),
    path('<uuid:id>/', UserDetailView.as_view(), name='user-detail'),
]
URLS

# ─── apps/users/admin.py ───
cat > apps/users/admin.py << 'ADMIN'
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['email', 'name', 'role', 'is_active', 'created_at']
    list_filter = ['role', 'is_active', 'is_staff']
    search_fields = ['email', 'name']
    ordering = ['-created_at']
    fieldsets = [
        (None, {'fields': ['email', 'password']}),
        ('Personal info', {'fields': ['name']}),
        ('Permissions', {'fields': ['is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions']}),
        ('Important dates', {'fields': ['last_login', 'created_at']}),
    ]
    add_fieldsets = [
        (None, {
            'classes': ['wide'],
            'fields': ['email', 'name', 'password1', 'password2', 'role'],
        }),
    ]
ADMIN

# ─── apps/users/tests.py ───
cat > apps/users/tests.py << 'TESTS'
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APITestCase
from rest_framework import status
from .models import User


class UserModelTests(TestCase):
    def test_create_user(self):
        user = User.objects.create_user(email='test@example.com', password='testpass123')
        self.assertEqual(user.email, 'test@example.com')
        self.assertTrue(user.check_password('testpass123'))
        self.assertFalse(user.is_staff)


class AuthAPITests(APITestCase):
    def test_register(self):
        url = reverse('register')
        data = {'email': 'new@example.com', 'password': 'newpass123', 'name': 'New User'}
        response = self.client.post(url, data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_login(self):
        User.objects.create_user(email='login@example.com', password='loginpass123')
        url = reverse('login')
        data = {'email': 'login@example.com', 'password': 'loginpass123'}
        response = self.client.post(url, data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
TESTS

# ─── apps/core/__init__.py ───
cat > apps/core/__init__.py << 'INIT'
INIT

# ─── apps/core/models.py ───
cat > apps/core/models.py << 'MODELS'
import uuid
from django.db import models


class BaseModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True
        ordering = ['-created_at']
MODELS

# ─── apps/core/views.py ───
cat > apps/core/views.py << 'VIEWS'
from django.http import JsonResponse
from django.db import connection
from django.views import View


class HealthView(View):
    def get(self, request):
        return JsonResponse({'status': 'alive'})


class ReadyView(View):
    def get(self, request):
        try:
            with connection.cursor() as cursor:
                cursor.execute('SELECT 1')
            return JsonResponse({'status': 'ready'})
        except Exception as e:
            return JsonResponse({'status': 'not_ready', 'detail': str(e)}, status=503)
VIEWS

# ─── apps/core/urls.py ───
cat > apps/core/urls.py << 'URLS'
from django.urls import path
from .views import HealthView, ReadyView

urlpatterns = [
    path('live/', HealthView.as_view(), name='health-live'),
    path('ready/', ReadyView.as_view(), name='health-ready'),
]
URLS

# ─── apps/core/middleware.py ───
cat > apps/core/middleware.py << 'MIDDLEWARE'
import uuid
import logging
import time

logger = logging.getLogger(__name__)


class RequestIDMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request_id = str(uuid.uuid4())
        request.request_id = request_id
        start_time = time.time()
        
        response = self.get_response(request)
        
        duration = time.time() - start_time
        logger.info(
            f"{request.method} {request.path} {response.status_code} {duration:.3f}s",
            extra={'request_id': request_id}
        )
        response['X-Request-ID'] = request_id
        return response
MIDDLEWARE

# ─── apps/core/admin.py ───
cat > apps/core/admin.py << 'ADMIN'
from django.contrib import admin
ADMIN

# ─── apps/core/apps.py ───
cat > apps/core/apps.py << 'APPS'
from django.apps import AppConfig

class CoreConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.core'
    verbose_name = 'Core'
APPS

# ─── docker-compose.yml ───
cat > docker-compose.yml << 'DOCKER'
version: '3.8'

services:
  app:
    build: .
    container_name: PROJECT_NAME-app
    ports:
      - "8000:8000"
    environment:
      - DJANGO_SETTINGS_MODULE=PROJECT_NAME.settings
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/PROJECT_NAME
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/1
      - CELERY_RESULT_BACKEND=redis://redis:6379/2
    depends_on:
      - db
      - redis
    volumes:
      - .:/app
    networks:
      - PROJECT_NAME-network

  db:
    image: postgres:16-alpine
    container_name: PROJECT_NAME-db
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: PROJECT_NAME
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - PROJECT_NAME-network

  redis:
    image: redis:7-alpine
    container_name: PROJECT_NAME-redis
    ports:
      - "6379:6379"
    networks:
      - PROJECT_NAME-network

  celery:
    build: .
    container_name: PROJECT_NAME-celery
    command: celery -A PROJECT_NAME worker -l info
    environment:
      - DJANGO_SETTINGS_MODULE=PROJECT_NAME.settings
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/PROJECT_NAME
      - CELERY_BROKER_URL=redis://redis:6379/1
      - CELERY_RESULT_BACKEND=redis://redis:6379/2
    depends_on:
      - db
      - redis
    volumes:
      - .:/app
    networks:
      - PROJECT_NAME-network

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: PROJECT_NAME-pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@admin.com
      PGADMIN_DEFAULT_PASSWORD: admin
    ports:
      - "5050:80"
    depends_on:
      - db
    networks:
      - PROJECT_NAME-network

volumes:
  postgres_data:

networks:
  PROJECT_NAME-network:
    driver: bridge
DOCKER
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" docker-compose.yml && rm docker-compose.yml.bak

# ─── Dockerfile ───
cat > Dockerfile << 'DOCKERFILE'
# ─── Build Stage ───
FROM python:3.11-slim AS builder

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# ─── Production Stage ───
FROM python:3.11-slim

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl libpq5 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /app /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=PROJECT_NAME.settings

RUN mkdir -p logs staticfiles media
RUN python manage.py collectstatic --noinput

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/api/v1/health/live/ || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "--timeout", "120", "PROJECT_NAME.wsgi:application"]
DOCKERFILE
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" Dockerfile && rm Dockerfile.bak

# ─── .gitignore ───
cat > .gitignore << 'GITIGNORE'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
*.egg-info/
.eggs/

# Environment
.env
.env.local
.venv/
venv/
ENV/

# Database
*.db
*.sqlite

# Static & Media
staticfiles/
media/

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Test coverage
.coverage
htmlcov/

# Logs
*.log
logs/

# Celery
celerybeat-schedule
GITIGNORE

# ─── .dockerignore ───
cat > .dockerignore << 'DOCKERIGNORE'
__pycache__/
*.pyc
.env
.venv
.git
.gitignore
Dockerfile
docker-compose.yml
README.md
*.md
staticfiles/
media/
logs/
DOCKERIGNORE

# ─── setup.cfg ───
cat > setup.cfg << 'SETUP'
[flake8]
max-line-length = 100
exclude = .git,__pycache__,venv,.venv,migrations
ignore = E203,W503

[tool:pytest]
DJANGO_SETTINGS_MODULE = PROJECT_NAME.settings
python_files = test_*.py
python_classes = Test*
python_functions = test_*
SETUP
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" setup.cfg && rm setup.cfg.bak

# ─── Makefile ───
cat > Makefile << 'MAKEFILE'
.PHONY: install migrate run test lint format shell

install:
	pip install -r requirements.txt

migrate:
	python manage.py migrate

migrations:
	python manage.py makemigrations

run:
	python manage.py runserver 0.0.0.0:8000

test:
	pytest --cov=apps --cov-report=term-missing

lint:
	flake8 apps
	mypy apps

format:
	black apps
	isort apps

shell:
	python manage.py shell

superuser:
	python manage.py createsuperuser

static:
	python manage.py collectstatic --noinput

requirements:
	pip freeze > requirements.txt
MAKEFILE

echo ""
echo "✅ Django scaffold complete: $PROJECT_NAME"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_NAME"
echo "  python -m venv venv && source venv/bin/activate"
echo "  pip install -r requirements.txt"
echo "  # Update .env with your database credentials"
echo "  python manage.py migrate"
echo "  python manage.py runserver"
echo ""
echo "API docs: http://localhost:8000/api/v1/docs/"
