#!/bin/bash
set -euo pipefail

# kimi-backend: FastAPI + Python + PostgreSQL + Docker scaffold
# Usage: bash init-fastapi-api.sh my-project

PROJECT_NAME="${1:-fastapi-api}"
DIR="$PWD/$PROJECT_NAME"

echo "🔧 Scaffolding FastAPI API: $PROJECT_NAME"
mkdir -p "$DIR" && cd "$DIR"

# ─── pyproject.toml ───
cat > pyproject.toml << 'PYPROJECT'
[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"

[tool.poetry]
name = "PROJECT_NAME"
version = "1.0.0"
description = "FastAPI + Python + PostgreSQL API"
authors = ["Your Name <your@email.com>"]
readme = "README.md"

[tool.poetry.dependencies]
python = "^3.11"
fastapi = {extras = ["standard"], version = "^0.115.0"}
uvicorn = {extras = ["standard"], version = "^0.32.0"}
pydantic = {extras = ["email"], version = "^2.10.0"}
pydantic-settings = "^2.7.0"
sqlalchemy = {extras = ["asyncpg"], version = "^2.0.0"}
alembic = "^1.14.0"
asyncpg = "^0.30.0"
redis = {extras = ["hiredis"], version = "^5.2.0"}
python-jose = {extras = ["cryptography"], version = "^3.3.0"}
passlib = {extras = ["bcrypt"], version = "^1.7.0"}
python-multipart = "^0.0.20"
httpx = "^0.28.0"
tenacity = "^9.0.0"
structlog = "^24.4.0"

[tool.poetry.group.dev.dependencies]
pytest = "^8.3.0"
pytest-asyncio = "^0.24.0"
pytest-cov = "^6.0.0"
httpx = "^0.28.0"
black = "^24.10.0"
isort = "^5.13.0"
flake8 = "^7.1.0"
mypy = "^1.14.0"
pre-commit = "^4.0.0"

[tool.poetry.scripts]
start = "app.main:start"

[tool.black]
line-length = 100
target-version = ['py311']

[tool.isort]
profile = "black"
line_length = 100

[tool.mypy]
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
ignore_missing_imports = true

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = "-v --tb=short"
PYPROJECT
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" pyproject.toml && rm pyproject.toml.bak

# ─── .env.example ───
cat > .env.example << 'ENV'
# Application
APP_NAME=PROJECT_NAME
APP_ENV=development
DEBUG=true

# Server
HOST=0.0.0.0
PORT=8000

# Database
DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/PROJECT_NAME
DATABASE_POOL_SIZE=20
DATABASE_MAX_OVERFLOW=10

# Redis
REDIS_URL=redis://localhost:6379
REDIS_PASSWORD=

# Auth
SECRET_KEY=change-me-in-production-min-32-characters-long
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# Cors
CORS_ORIGINS=http://localhost:3000,http://localhost:5173

# Logging
LOG_LEVEL=INFO
ENV
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" .env.example && rm .env.example.bak

# ─── .env ───
cp .env.example .env

# ─── app/__init__.py ───
mkdir -p app/{api,core,db,models,schemas,services,utils}
cat > app/__init__.py << 'INIT'
__version__ = "1.0.0"
INIT

# ─── app/main.py ───
cat > app/main.py << 'MAIN'
import sys
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

from app.core.config import settings
from app.core.logging import setup_logging
from app.api.router import api_router
from app.db.session import engine, Base
from app.utils.redis import redis_client

# ── Setup logging before anything else ──────────────────────────────────────
setup_logging()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await redis_client.connect()
    yield
    # Shutdown
    await redis_client.disconnect()
    await engine.dispose()


app = FastAPI(
    title=settings.APP_NAME,
    description="API documentation",
    version="1.0.0",
    docs_url="/api/docs" if settings.DEBUG else None,
    redoc_url="/api/redoc" if settings.DEBUG else None,
    openapi_url="/api/openapi.json" if settings.DEBUG else None,
    lifespan=lifespan,
)

# ── Middleware ──────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(TrustedHostMiddleware, allowed_hosts=["*"])

# ── Router ────────────────────────────────────────────────────────────────────
app.include_router(api_router, prefix="/api/v1")


@app.get("/", tags=["health"])
async def root():
    return {"message": f"{settings.APP_NAME} API", "version": "1.0.0"}


@app.get("/health/live", tags=["health"])
async def liveness():
    return {"status": "alive"}


@app.get("/health/ready", tags=["health"])
async def readiness():
    try:
        await redis_client.ping()
        return {"status": "ready"}
    except Exception:
        return {"status": "not_ready"}, 503
MAIN

# ─── app/core/__init__.py ───
cat > app/core/__init__.py << 'INIT'
INIT

# ─── app/core/config.py ───
cat > app/core/config.py << 'CONFIG'
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field, validator
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    APP_NAME: str = "FastAPI App"
    APP_ENV: str = "development"
    DEBUG: bool = False

    HOST: str = "0.0.0.0"
    PORT: int = 8000

    DATABASE_URL: str = Field(..., description="PostgreSQL connection string")
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 10

    REDIS_URL: str = "redis://localhost:6379"
    REDIS_PASSWORD: str = ""

    SECRET_KEY: str = Field(..., min_length=32, description="JWT signing secret")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    CORS_ORIGINS: str = "http://localhost:3000"

    LOG_LEVEL: str = "INFO"

    @validator("CORS_ORIGINS", pre=True)
    def parse_cors_origins(cls, v: str) -> str:
        return v

    def get_cors_origins(self) -> List[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",")]


settings = Settings()
CONFIG

# ─── app/core/logging.py ───
cat > app/core/logging.py << 'LOGGING'
import logging
import sys
from typing import Any

import structlog


def setup_logging():
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.stdlib.ExtraAdder(),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )

    # Configure standard library logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO),
    )

    # Redirect standard library loggers to structlog
    stdlib_logger = logging.getLogger()
    stdlib_logger.handlers = [structlog.stdlib.ProcessorFormatter.wrap_for_formatter(
        structlog.stdlib.ProcessorFormatter(
            processor=structlog.dev.ConsoleRenderer(),
            foreign_pre_chain=[
                structlog.processors.TimeStamper(fmt="iso"),
                structlog.stdlib.add_log_level,
            ],
        )
    )]


from app.core.config import settings  # noqa: E402
LOGGING

# ─── app/core/security.py ───
cat > app/core/security.py << 'SECURITY'
from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import jwt, JWTError
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def verify_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        return None
SECURITY

# ─── app/db/__init__.py ───
cat > app/db/__init__.py << 'INIT'
INIT

# ─── app/db/session.py ───
cat > app/db/session.py << 'SESSION'
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base

from app.core.config import settings

engine = create_async_engine(
    settings.DATABASE_URL,
    pool_size=settings.DATABASE_POOL_SIZE,
    max_overflow=settings.DATABASE_MAX_OVERFLOW,
    echo=settings.DEBUG,
    future=True,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

Base = declarative_base()


async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
SESSION

# ─── app/models/__init__.py ───
cat > app/models/__init__.py << 'INIT'
from app.models.user import User
from app.models.audit_log import AuditLog

__all__ = ["User", "AuditLog"]
INIT

# ─── app/models/base.py ───
cat > app/models/base.py << 'BASE'
from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, DateTime, String
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class BaseModel(Base):
    __abstract__ = True

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
BASE

# ─── app/models/user.py ───
cat > app/models/user.py << 'USER_MODEL'
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.session import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(50), default="user", nullable=False, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
USER_MODEL

# ─── app/models/audit_log.py ───
cat > app/models/audit_log.py << 'AUDIT_MODEL'
from sqlalchemy import Column, String, JSON, DateTime, Integer
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.session import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    action: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String(36), nullable=True, index=True)
    metadata: Mapped[dict] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
AUDIT_MODEL

# ─── app/schemas/__init__.py ───
cat > app/schemas/__init__.py << 'INIT'
INIT

# ─── app/schemas/user.py ───
cat > app/schemas/user.py << 'USER_SCHEMA'
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional


class UserBase(BaseModel):
    email: EmailStr
    name: Optional[str] = None


class UserCreate(UserBase):
    password: str = Field(..., min_length=8)


class UserResponse(UserBase):
    id: str
    role: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UserInDB(UserBase):
    password_hash: str
USER_SCHEMA

# ─── app/schemas/token.py ───
cat > app/schemas/token.py << 'TOKEN_SCHEMA'
from pydantic import BaseModel
from datetime import datetime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class TokenPayload(BaseModel):
    sub: str
    email: str
    role: str
    exp: datetime
TOKEN_SCHEMA

# ─── app/services/__init__.py ───
cat > app/services/__init__.py << 'INIT'
INIT

# ─── app/services/user_service.py ───
cat > app/services/user_service.py << 'USER_SVC'
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.user import User
from app.schemas.user import UserCreate, UserResponse
from app.core.security import get_password_hash, verify_password


class UserService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(self, user_data: UserCreate) -> UserResponse:
        existing = await self.db.execute(select(User).where(User.email == user_data.email))
        if existing.scalar_one_or_none():
            raise ValueError("Email already registered")

        user = User(
            email=user_data.email,
            name=user_data.name,
            password_hash=get_password_hash(user_data.password),
        )
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        return UserResponse.model_validate(user)

    async def authenticate(self, email: str, password: str) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if not user or not verify_password(password, user.password_hash):
            return None
        return user

    async def get_by_id(self, user_id: str) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()
USER_SVC

# ─── app/utils/__init__.py ───
cat > app/utils/__init__.py << 'INIT'
INIT

# ─── app/utils/redis.py ───
cat > app/utils/redis.py << 'REDIS'
import redis.asyncio as aioredis
from app.core.config import settings


class RedisClient:
    _instance: aioredis.Redis = None

    async def connect(self):
        self._instance = aioredis.from_url(
            settings.REDIS_URL,
            password=settings.REDIS_PASSWORD or None,
            decode_responses=True,
        )

    async def disconnect(self):
        if self._instance:
            await self._instance.close()

    async def get(self, key: str) -> str:
        return await self._instance.get(key)

    async def set(self, key: str, value: str, ttl: int = None):
        if ttl:
            await self._instance.setex(key, ttl, value)
        else:
            await self._instance.set(key, value)

    async def delete(self, key: str):
        await self._instance.delete(key)

    async def ping(self):
        return await self._instance.ping()


redis_client = RedisClient()
REDIS

# ─── app/api/__init__.py ───
cat > app/api/__init__.py << 'INIT'
INIT

# ─── app/api/router.py ───
cat > app/api/router.py << 'ROUTER'
from fastapi import APIRouter
from app.api.routes import auth, users, health

api_router = APIRouter()
api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
ROUTER

# ─── app/api/routes/__init__.py ───
mkdir -p app/api/routes
cat > app/api/routes/__init__.py << 'INIT'
INIT

# ─── app/api/routes/health.py ───
cat > app/api/routes/health.py << 'HEALTH'
from fastapi import APIRouter, Depends
from app.utils.redis import redis_client
from app.db.session import get_db
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter()


@router.get("/live")
async def liveness():
    return {"status": "alive"}


@router.get("/ready")
async def readiness(db: AsyncSession = Depends(get_db)):
    try:
        await db.execute("SELECT 1")
        await redis_client.ping()
        return {"status": "ready"}
    except Exception:
        return {"status": "not_ready"}, 503
HEALTH

# ─── app/api/routes/auth.py ───
cat > app/api/routes/auth.py << 'AUTH'
from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.user import UserCreate, UserResponse
from app.schemas.token import Token
from app.services.user_service import UserService
from app.core.security import create_access_token, verify_password
from app.core.config import settings

router = APIRouter()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    service = UserService(db)
    try:
        return await service.create(user_data)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    service = UserService(db)
    user = await service.authenticate(form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token(
        data={"sub": user.id, "email": user.email, "role": user.role},
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
    )
    return {"access_token": access_token, "token_type": "bearer", "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60}
AUTH

# ─── app/api/routes/users.py ───
cat > app/api/routes/users.py << 'USERS'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.user import UserResponse
from app.services.user_service import UserService
from app.api.deps import get_current_user

router = APIRouter()


@router.get("/me", response_model=UserResponse)
async def get_me(current_user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = UserService(db)
    user = await service.get_by_id(current_user.id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: str, current_user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    # BOLA prevention: only allow access to own data
    if current_user.id != user_id:
        raise HTTPException(status_code=404, detail="User not found")
    service = UserService(db)
    user = await service.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
USERS

# ─── app/api/deps.py ───
cat > app/api/deps.py << 'DEPS'
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.services.user_service import UserService
from app.core.security import verify_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)):
    payload = verify_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    service = UserService(db)
    user = await service.get_by_id(payload["sub"])
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user
DEPS

# ─── alembic.ini ───
cat > alembic.ini << 'ALEMBIC'
[alembic]
script_location = alembic
prepend_sys_path = .
version_path_separator = os

[post_write_hooks]

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
ALEMBIC

# ─── alembic/env.py ───
mkdir -p alembic/versions
cat > alembic/env.py << 'ALEMBIC_ENV'
import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context
from app.core.config import settings
from app.db.session import Base
from app.models import *  # noqa: F401, F403

config = context.config
if config.config_file_name:
    fileConfig(config.config_file_name)

config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
ALEMBIC_ENV

# ─── alembic/script.py.mako ───
cat > alembic/script.py.mako << 'MAKO'
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}

"""
from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

# revision identifiers, used by Alembic.
revision = ${repr(up_revision)}
down_revision = ${repr(down_revision)}
branch_labels = ${repr(branch_labels)}
depends_on = ${repr(depends_on)}


def upgrade() -> None:
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    ${downgrades if downgrades else "pass"}
MAKO

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
      - APP_ENV=production
      - DATABASE_URL=postgresql+asyncpg://postgres:postgres@db:5432/PROJECT_NAME
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
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
RUN apt-get update && apt-get install -y --no-install-recommends gcc

COPY pyproject.toml poetry.lock* ./
RUN pip install poetry && poetry config virtualenvs.create false
RUN poetry install --no-dev

COPY . .

# ─── Production Stage ───
FROM python:3.11-slim

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /app /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV APP_ENV=production

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health/live || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKERFILE

# ─── .gitignore ───
cat > .gitignore << 'GITIGNORE'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Environment
.env
.env.local
.venv
venv/
ENV/

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

# Database
*.db
*.sqlite

# Alembic
alembic/versions/*.py
!alembic/versions/__init__.py
GITIGNORE

# ─── tests/__init__.py ───
mkdir -p tests
cat > tests/__init__.py << 'INIT'
INIT

# ─── tests/test_main.py ───
cat > tests/test_main.py << 'TEST'
import pytest
from httpx import AsyncClient
from app.main import app


@pytest.mark.asyncio
async def test_read_root():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get("/")
    assert response.status_code == 200
    assert "API" in response.json()["message"]


@pytest.mark.asyncio
async def test_health_live():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get("/health/live")
    assert response.status_code == 200
    assert response.json()["status"] == "alive"
TEST

echo ""
echo "✅ FastAPI scaffold complete: $PROJECT_NAME"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_NAME"
echo "  pip install poetry"
echo "  poetry install"
echo "  # Update .env with your DATABASE_URL"
echo "  alembic revision --autogenerate -m 'init'"
echo "  alembic upgrade head"
echo "  uvicorn app.main:app --reload"
echo ""
echo "API docs: http://localhost:8000/api/docs"
