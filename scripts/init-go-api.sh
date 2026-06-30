#!/usr/bin/env bash
# =============================================================================
# init-go-api.sh — Scaffolds a production-ready Go + Gin + GORM API project
#
# Usage: ./init-go-api.sh <module_name> [output_directory]
#
# Example: ./init-go-api.sh github.com/myorg/myapi
#
# Creates a complete Go API with:
#   - Gin web framework
#   - GORM + PostgreSQL (pgx)
#   - JWT middleware (jwt-go)
#   - Structured logging with Zap
#   - Graceful shutdown
#   - Docker multi-stage build
#   - GitHub Actions CI
#   - Makefile with build/test/run/migrate
# =============================================================================

set -euo pipefail

# ── Arguments ─────────────────────────────────────────────────────────────
MODULE_NAME="${1:-}"
OUTPUT_DIR="${2:-.}"

if [[ -z "$MODULE_NAME" ]]; then
    echo "Usage: $0 <module_name> [output_directory]" >&2
    echo "  Example: $0 github.com/myorg/myapi" >&2
    exit 1
fi

PROJECT_NAME=$(basename "$MODULE_NAME")
PROJECT_ROOT="$(cd "$OUTPUT_DIR" && pwd)/${PROJECT_NAME}"

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Create directory and init go module ─────────────────────────────────────
info "Creating Go module '${MODULE_NAME}'…"
mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"
go mod init "$MODULE_NAME"

info "Installing dependencies…"
# Core framework & database
go get github.com/gin-gonic/gin
go get gorm.io/gorm
go get gorm.io/driver/postgres
# Configuration & auth
go get github.com/joho/godotenv
go get github.com/golang-jwt/jwt/v5
# Logging
go get go.uber.org/zap
# Testing
go get github.com/stretchr/testify
go get github.com/stretchr/testify/mock
# Utilities
go get github.com/google/uuid

info "Tidying go.mod…"
go mod tidy

# ── Directory structure ─────────────────────────────────────────────────────
mkdir -p \
    "${PROJECT_ROOT}/cmd/api" \
    "${PROJECT_ROOT}/internal/config" \
    "${PROJECT_ROOT}/internal/handlers" \
    "${PROJECT_ROOT}/internal/middleware" \
    "${PROJECT_ROOT}/internal/models" \
    "${PROJECT_ROOT}/internal/repository" \
    "${PROJECT_ROOT}/internal/routes" \
    "${PROJECT_ROOT}/internal/logger" \
    "${PROJECT_ROOT}/pkg/utils" \
    "${PROJECT_ROOT}/tests" \
    "${PROJECT_ROOT}/migrations"

# ── internal/config/config.go ───────────────────────────────────────────────
cat > "${PROJECT_ROOT}/internal/config/config.go" << 'EOF'
// Package config loads environment variables and exposes application settings.
package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

// Config holds all application configuration.
type Config struct {
	Port        string
	DatabaseURL string
	JWTSecret   string
	LogLevel    string
	Env         string
}

// Load reads .env and returns a Config struct.
func Load() *Config {
	_ = godotenv.Load() // ignore error if .env missing

	return &Config{
		Port:        getEnv("PORT", "8080"),
		DatabaseURL: getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/postgres?sslmode=disable"),
		JWTSecret:   getEnv("JWT_SECRET", "change-me-in-production"),
		LogLevel:    getEnv("LOG_LEVEL", "info"),
		Env:         getEnv("ENV", "development"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// IsDevelopment returns true if running in development mode.
func (c *Config) IsDevelopment() bool { return c.Env == "development" }
EOF

# ── internal/logger/logger.go ───────────────────────────────────────────────
cat > "${PROJECT_ROOT}/internal/logger/logger.go" << 'EOF'
// Package logger provides structured logging with Zap.
package logger

import (
	"os"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// Logger is the global application logger.
var Logger *zap.Logger

// Init initializes the Zap logger based on environment.
func Init(level string) {
	l := zapcore.InfoLevel
	_ = l.UnmarshalText([]byte(level))

	encoder := zapcore.NewJSONEncoder(zapcore.ProductionEncoderConfig())
	if os.Getenv("ENV") == "development" {
		encoder = zapcore.NewConsoleEncoder(zapcore.DevelopmentEncoderConfig())
	}

	core := zapcore.NewCore(encoder, zapcore.AddSync(os.Stdout), l)
	Logger = zap.New(core, zap.AddCaller(), zap.AddStacktrace(zapcore.ErrorLevel))
	defer Logger.Sync() // flushes buffer
}

// Info wraps zap Info.
func Info(msg string, fields ...zap.Field) { Logger.Info(msg, fields...) }

// Error wraps zap Error.
func Error(msg string, fields ...zap.Field) { Logger.Error(msg, fields...) }

// Fatal wraps zap Fatal.
func Fatal(msg string, fields ...zap.Field) { Logger.Fatal(msg, fields...) }
EOF

# ── internal/models/models.go ───────────────────────────────────────────────
cat > "${PROJECT_ROOT}/internal/models/models.go" << 'EOF'
// Package models defines GORM database models.
package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// User represents an application user.
type User struct {
	ID        uuid.UUID      `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Email     string         `gorm:"uniqueIndex;not null" json:"email"`
	Username  string         `gorm:"not null" json:"username"`
	Password  string         `gorm:"not null" json:"-"` // never serialized
	Role      string         `gorm:"default:user" json:"role"`
	Avatar    string         `json:"avatar,omitempty"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

// Product represents a catalog product.
type Product struct {
	ID          uuid.UUID      `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name        string         `gorm:"not null" json:"name"`
	Description string         `json:"description,omitempty"`
	Category    string         `gorm:"not null" json:"category"`
	Price       float64        `gorm:"type:decimal(10,2);not null" json:"price"`
	Stock       int            `gorm:"default:0" json:"stock"`
	IsActive    bool           `gorm:"default:true" json:"is_active"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

// Order represents a customer order.
type Order struct {
	ID          uuid.UUID      `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	UserID      uuid.UUID      `gorm:"type:uuid;not null;index" json:"user_id"`
	User        User           `json:"user,omitempty"`
	Status      string         `gorm:"default:pending" json:"status"`
	TotalAmount float64        `gorm:"type:decimal(12,2);default:0" json:"total_amount"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}
EOF

# ── internal/repository/repository.go ───────────────────────────────────────
cat > "${PROJECT_ROOT}/internal/repository/repository.go" << 'EOF'
// Package repository abstracts database operations.
package repository

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"${MODULE_NAME}/internal/models"
)

// ErrNotFound is returned when a record is not found.
var ErrNotFound = errors.New("record not found")

// UserRepo defines user data operations.
type UserRepo struct{ db *gorm.DB }

// NewUserRepo returns a new User repository.
func NewUserRepo(db *gorm.DB) *UserRepo { return &UserRepo{db: db} }

// Create inserts a new user.
func (r *UserRepo) Create(ctx context.Context, user *models.User) error {
	return r.db.WithContext(ctx).Create(user).Error
}

// GetByID fetches a user by UUID.
func (r *UserRepo) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	var u models.User
	if err := r.db.WithContext(ctx).First(&u, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &u, nil
}

// ProductRepo defines product data operations.
type ProductRepo struct{ db *gorm.DB }

// NewProductRepo returns a new Product repository.
func NewProductRepo(db *gorm.DB) *ProductRepo { return &ProductRepo{db: db} }

// Create inserts a new product.
func (r *ProductRepo) Create(ctx context.Context, p *models.Product) error {
	return r.db.WithContext(ctx).Create(p).Error
}

// List returns all products with pagination.
func (r *ProductRepo) List(ctx context.Context, limit, offset int) ([]models.Product, error) {
	var products []models.Product
	err := r.db.WithContext(ctx).Limit(limit).Offset(offset).Find(&products).Error
	return products, err
}
EOF

# ── internal/middleware/auth.go ─────────────────────────────────────────────
cat > "${PROJECT_ROOT}/internal/middleware/auth.go" << 'EOF'
// Package middleware provides Gin middleware: JWT auth, logging, recovery.
package middleware

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.uber.org/zap"

	"${MODULE_NAME}/internal/config"
	"${MODULE_NAME}/internal/logger"
)

// JWTAuth validates Bearer tokens and injects claims into context.
func JWTAuth(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		auth := c.GetHeader("Authorization")
		if auth == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing authorization header"})
			return
		}

		parts := strings.SplitN(auth, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization header format"})
			return
		}

		token, err := jwt.Parse(parts[1], func(t *jwt.Token) (interface{}, error) {
			return []byte(cfg.JWTSecret), nil
		}, jwt.WithValidMethods([]string{"HS256"}))
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			return
		}

		claims, _ := token.Claims.(jwt.MapClaims)
		c.Set("userID", claims["sub"])
		c.Set("role", claims["role"])
		c.Next()
	}
}

// Logger logs HTTP requests with Zap.
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		raw := c.Request.URL.RawQuery

		c.Next()

		latency := time.Since(start)
		clientIP := c.ClientIP()
		method := c.Request.Method
		statusCode := c.Writer.Status()
		if raw != "" {
			path = path + "?" + raw
		}

		logger.Info("http request",
			zap.String("client_ip", clientIP),
			zap.String("method", method),
			zap.String("path", path),
			zap.Int("status", statusCode),
			zap.Duration("latency", latency),
		)
	}
}
EOF

# ── internal/handlers/handlers.go ───────────────────────────────────────────
cat > "${PROJECT_ROOT}/internal/handlers/handlers.go" << 'EOF'
// Package handlers contains HTTP request handlers (Gin controllers).
package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"${MODULE_NAME}/internal/logger"
	"${MODULE_NAME}/internal/models"
	"${MODULE_NAME}/internal/repository"
)

// Handler groups all HTTP handlers.
type Handler struct {
	userRepo    *repository.UserRepo
	productRepo *repository.ProductRepo
}

// NewHandler creates a new Handler.
func NewHandler(ur *repository.UserRepo, pr *repository.ProductRepo) *Handler {
	return &Handler{userRepo: ur, productRepo: pr}
}

// HealthCheck returns service status.
func (h *Handler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "api"})
}

// CreateUserRequest is the payload for user creation.
type CreateUserRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Username string `json:"username" binding:"required,min=3"`
	Password string `json:"password" binding:"required,min=8"`
	Role     string `json:"role"`
}

// CreateUser handles POST /users.
func (h *Handler) CreateUser(c *gin.Context) {
	var req CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := &models.User{
		Email:    req.Email,
		Username: req.Username,
		Password: req.Password, // TODO: hash with bcrypt
		Role:     req.Role,
	}

	if err := h.userRepo.Create(c.Request.Context(), user); err != nil {
		logger.Error("failed to create user", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create user"})
		return
	}

	c.JSON(http.StatusCreated, user)
}

// ListUsers handles GET /users.
func (h *Handler) ListUsers(c *gin.Context) {
	// TODO: implement pagination
	c.JSON(http.StatusOK, gin.H{"users": []models.User{}})
}

// CreateProduct handles POST /products.
func (h *Handler) CreateProduct(c *gin.Context) {
	var p models.Product
	if err := c.ShouldBindJSON(&p); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := h.productRepo.Create(c.Request.Context(), &p); err != nil {
		logger.Error("failed to create product", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create product"})
		return
	}
	c.JSON(http.StatusCreated, p)
}

// ListProducts handles GET /products.
func (h *Handler) ListProducts(c *gin.Context) {
	products, err := h.productRepo.List(c.Request.Context(), 50, 0)
	if err != nil {
		logger.Error("failed to list products", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list products"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"products": products})
}
EOF

# ── internal/routes/routes.go ───────────────────────────────────────────────
cat > "${PROJECT_ROOT}/internal/routes/routes.go" << 'EOF'
// Package routes registers all HTTP endpoints.
package routes

import (
	"github.com/gin-gonic/gin"

	"${MODULE_NAME}/internal/config"
	"${MODULE_NAME}/internal/handlers"
	"${MODULE_NAME}/internal/middleware"
)

// Register sets up all API routes.
func Register(r *gin.Engine, h *handlers.Handler, cfg *config.Config) {
	// Global middleware
	r.Use(middleware.Logger())
	r.Use(gin.Recovery())

	// Public routes
	r.GET("/health", h.HealthCheck)

	// Protected routes
	api := r.Group("/api")
	api.Use(middleware.JWTAuth(cfg))
	{
		api.POST("/users", h.CreateUser)
		api.GET("/users", h.ListUsers)
		api.POST("/products", h.CreateProduct)
		api.GET("/products", h.ListProducts)
	}
}
EOF

# ── cmd/api/main.go ─────────────────────────────────────────────────────────
cat > "${PROJECT_ROOT}/cmd/api/main.go" << 'EOF'
// main.go bootstraps the Gin HTTP server with graceful shutdown.
package main

import (
	"context"
	"errors"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	gormLogger "gorm.io/gorm/logger"

	"${MODULE_NAME}/internal/config"
	appLogger "${MODULE_NAME}/internal/logger"
	"${MODULE_NAME}/internal/handlers"
	"${MODULE_NAME}/internal/models"
	"${MODULE_NAME}/internal/repository"
	"${MODULE_NAME}/internal/routes"
)

func main() {
	cfg := config.Load()
	appLogger.Init(cfg.LogLevel)
	appLogger.Info("starting server", zap.String("env", cfg.Env))

	// ── Database ───────────────────────────────────────────────────────────
	db, err := gorm.Open(postgres.Open(cfg.DatabaseURL), &gorm.Config{
		Logger: gormLogger.Default.LogMode(gormLogger.Silent),
	})
	if err != nil {
		appLogger.Fatal("failed to connect to database", zap.Error(err))
	}

	// Auto-migrate models
	if err := db.AutoMigrate(&models.User{}, &models.Product{}, &models.Order{}); err != nil {
		appLogger.Fatal("failed to auto-migrate", zap.Error(err))
	}
	appLogger.Info("database migrated")

	// ── Repositories & Handlers ────────────────────────────────────────────
	userRepo := repository.NewUserRepo(db)
	productRepo := repository.NewProductRepo(db)
	h := handlers.NewHandler(userRepo, productRepo)

	// ── Router ─────────────────────────────────────────────────────────────
	if cfg.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}
	r := gin.New()
	routes.Register(r, h, cfg)

	// ── Server with graceful shutdown ────────────────────────────────────────
	srv := &http.Server{
		Addr:    ":" + cfg.Port,
		Handler: r,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			appLogger.Fatal("server failed to start", zap.Error(err))
		}
	}()
	appLogger.Info("server listening", zap.String("port", cfg.Port))

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	appLogger.Info("shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		appLogger.Error("server forced to shutdown", zap.Error(err))
	}

	appLogger.Info("server exited")
}
EOF

# ── .env ────────────────────────────────────────────────────────────────────
cat > "${PROJECT_ROOT}/.env" << 'EOF'
ENV=development
PORT=8080
DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres?sslmode=disable
JWT_SECRET=change-me-in-production
LOG_LEVEL=info
EOF

# ── Dockerfile (multi-stage) ────────────────────────────────────────────────
cat > "${PROJECT_ROOT}/Dockerfile" << 'EOF'
# ── Builder stage ──────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /api ./cmd/api

# ── Runtime stage (distroless) ─────────────────────────────────────────────
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /api /api
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/api"]
EOF

# ── docker-compose.yml ──────────────────────────────────────────────────────
cat > "${PROJECT_ROOT}/docker-compose.yml" << 'EOF'
version: "3.9"

services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    volumes:
      - pg_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build: .
    environment:
      ENV: production
      PORT: 8080
      DATABASE_URL: postgres://postgres:postgres@db:5432/postgres?sslmode=disable
      JWT_SECRET: ${JWT_SECRET:-change-me-in-production}
      LOG_LEVEL: info
    ports:
      - "8080:8080"
    depends_on:
      db:
        condition: service_healthy

volumes:
  pg_data:
EOF

# ── .github/workflows/ci.yml ─────────────────────────────────────────────────
mkdir -p "${PROJECT_ROOT}/.github/workflows"
cat > "${PROJECT_ROOT}/.github/workflows/ci.yml" << 'EOF'
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Cache Go modules
        uses: actions/cache@v4
        with:
          path: ~/go/pkg/mod
          key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
          restore-keys: |
            ${{ runner.os }}-go-

      - name: Download dependencies
        run: go mod download

      - name: Build
        run: go build -v ./cmd/api

      - name: Test
        run: go test -v -race -coverprofile=coverage.out ./...

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage.out

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - name: golangci-lint
        uses: golangci/golangci-lint-action@v6
        with:
          version: latest
          args: --timeout=5m
EOF

# ── Makefile ────────────────────────────────────────────────────────────────
cat > "${PROJECT_ROOT}/Makefile" << 'EOF'
.PHONY: build test run migrate lint clean docker-build docker-run

MODULE := ${MODULE_NAME}
BINARY := api

build:
	go build -ldflags="-w -s" -o bin/$(BINARY) ./cmd/api

test:
	go test -v -race -coverprofile=coverage.out ./...

run:
	go run ./cmd/api

migrate:
	go run ./cmd/api migrate

dev:
	air -c .air.toml

lint:
	golangci-lint run ./...

fmt:
	go fmt ./...

vet:
	go vet ./...

clean:
	rm -rf bin/ coverage.out

docker-build:
	docker build -t $(BINARY):latest .

docker-run:
	docker-compose up --build

docker-down:
	docker-compose down -v

deps:
	go mod download
	go mod tidy

gen:
	go generate ./...

.DEFAULT_GOAL := build
EOF

# ── tests/handler_test.go ───────────────────────────────────────────────────
cat > "${PROJECT_ROOT}/tests/handler_test.go" << 'EOF'
package tests

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"

	"${MODULE_NAME}/internal/handlers"
	"${MODULE_NAME}/internal/repository"
)

func TestHealthCheck(t *testing.T) {
	gin.SetMode(gin.TestMode)

	// Mock repos (nil is okay for health check)
	h := handlers.NewHandler(nil, nil)

	r := gin.New()
	r.GET("/health", h.HealthCheck)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/health", nil)
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.Contains(t, w.Body.String(), "ok")
}
EOF

# ── .gitignore ──────────────────────────────────────────────────────────────
cat > "${PROJECT_ROOT}/.gitignore" << 'EOF'
# Binaries
bin/
*.exe
*.dll
*.so
*.dylib
*.test
*.out

# Go
vendor/

# IDE
.idea/
.vscode/
*.swp
*.swo

# Env
.env
.env.local

# OS
.DS_Store
Thumbs.db

# Coverage
coverage.out
*.cov

# Air (live reload)
.tmp/
EOF

# ── golangci-lint config (optional) ───────────────────────────────────────
cat > "${PROJECT_ROOT}/.golangci.yml" << 'EOF'
run:
  timeout: 5m
linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
    - gofmt
    - goimports
issues:
  exclude-use-default: false
  max-issues-per-linter: 0
  max-same-issues: 0
EOF

info "Go API project scaffolded successfully at: ${PROJECT_ROOT}"
info "Next steps:"
info "  cd ${PROJECT_ROOT}"
info "  make build"
info "  make run"
