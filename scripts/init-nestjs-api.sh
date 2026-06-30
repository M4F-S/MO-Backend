#!/bin/bash
set -euo pipefail

# kimi-backend: NestJS + TypeScript + Prisma + PostgreSQL + Redis scaffold
# Usage: bash init-nestjs-api.sh my-project

PROJECT_NAME="${1:-nestjs-api}"
DIR="$PWD/$PROJECT_NAME"

echo "🔧 Scaffolding NestJS API: $PROJECT_NAME"
mkdir -p "$DIR" && cd "$DIR"

# ─── package.json ───
cat > package.json << 'PKG'
{
  "name": "PROJECT_NAME",
  "version": "1.0.0",
  "description": "NestJS + TypeScript + Prisma + PostgreSQL + Redis API",
  "scripts": {
    "build": "nest build",
    "start": "nest start",
    "start:dev": "nest start --watch",
    "start:debug": "nest start --debug --watch",
    "start:prod": "node dist/main",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:cov": "jest --coverage",
    "test:e2e": "jest --config ./test/jest-e2e.json",
    "format": "prettier --write \"src/**/*.ts\"",
    "lint": "eslint \"{src,apps,libs,test}/**/*.ts\" --fix",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev",
    "prisma:studio": "prisma studio",
    "prisma:seed": "ts-node prisma/seed.ts"
  },
  "dependencies": {
    "@nestjs/common": "^10.0.0",
    "@nestjs/core": "^10.0.0",
    "@nestjs/platform-express": "^10.0.0",
    "@nestjs/swagger": "^7.0.0",
    "@nestjs/jwt": "^10.0.0",
    "@nestjs/passport": "^10.0.0",
    "@nestjs/throttler": "^5.0.0",
    "@nestjs/config": "^3.0.0",
    "@prisma/client": "^5.0.0",
    "passport": "^0.7.0",
    "passport-jwt": "^4.0.0",
    "passport-local": "^1.0.0",
    "bcrypt": "^5.0.0",
    "class-transformer": "^0.5.0",
    "class-validator": "^0.14.0",
    "compression": "^1.7.0",
    "helmet": "^7.0.0",
    "ioredis": "^5.0.0",
    "reflect-metadata": "^0.1.0",
    "rxjs": "^7.8.0",
    "winston": "^3.11.0",
    "winston-daily-rotate-file": "^4.7.0",
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.0.0",
    "@nestjs/schematics": "^10.0.0",
    "@nestjs/testing": "^10.0.0",
    "@types/bcrypt": "^5.0.0",
    "@types/compression": "^1.7.0",
    "@types/express": "^4.17.0",
    "@types/jest": "^29.0.0",
    "@types/node": "^20.0.0",
    "@types/passport-jwt": "^3.0.0",
    "@types/passport-local": "^1.0.0",
    "@typescript-eslint/eslint-plugin": "^6.0.0",
    "@typescript-eslint/parser": "^6.0.0",
    "eslint": "^8.0.0",
    "eslint-config-prettier": "^9.0.0",
    "eslint-plugin-prettier": "^5.0.0",
    "jest": "^29.0.0",
    "prettier": "^3.0.0",
    "prisma": "^5.0.0",
    "ts-jest": "^29.0.0",
    "ts-node": "^10.9.0",
    "typescript": "^5.0.0"
  }
}
PKG
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" package.json && rm package.json.bak

# ─── tsconfig.json ───
cat > tsconfig.json << 'TSC'
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strictNullChecks": true,
    "noImplicitAny": true,
    "strictBindCallApply": true,
    "forceConsistentCasingInFileNames": true,
    "noFallthroughCasesInSwitch": true,
    "esModuleInterop": true,
    "paths": { "@/*": ["src/*"] }
  }
}
TSC

# ─── nest-cli.json ───
cat > nest-cli.json << 'NEST'
{
  "$schema": "https://json.schemastore.org/nest-cli",
  "collection": "@nestjs/schematics",
  "sourceRoot": "src",
  "compilerOptions": { "deleteOutDir": true }
}
NEST

# ─── jest.config.js ───
cat > jest.config.js << 'JEST'
module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$',
  transform: { '^.+\\.(t|j)s$': 'ts-jest' },
  collectCoverageFrom: ['**/*.(t|j)s'],
  coverageDirectory: '../coverage',
  testEnvironment: 'node',
};
JEST

# ─── .env.example ───
cat > .env.example << 'ENV'
# Application
NODE_ENV=development
PORT=3000
APP_NAME=PROJECT_NAME
API_PREFIX=api/v1

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/PROJECT_NAME?schema=public

# Redis
REDIS_URL=redis://localhost:6379
REDIS_PASSWORD=

# Auth
JWT_SECRET=change-me-in-production-min-32-characters-long
JWT_ACCESS_EXPIRATION=15m
JWT_REFRESH_EXPIRATION=7d

# Logging
LOG_LEVEL=info
LOG_FILE=logs/app.log

# Cors
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
ENV
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" .env.example && rm .env.example.bak

# ─── .env ───
cp .env.example .env

# ─── src/main.ts ───
mkdir -p src/{auth,common,config,users,prisma}
cat > src/main.ts << 'MAIN'
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';
import compression from 'compression';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);

  // Security middleware
  app.use(helmet());
  app.use(compression());
  app.enableCors({
    origin: configService.get('CORS_ORIGINS')?.split(',') || ['http://localhost:3000'],
    credentials: true,
  });

  // Validation
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // API prefix
  const apiPrefix = configService.get('API_PREFIX') || 'api/v1';
  app.setGlobalPrefix(apiPrefix);

  // Swagger (only in dev)
  if (configService.get('NODE_ENV') !== 'production') {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('PROJECT_NAME API')
      .setDescription('API documentation')
      .setVersion('1.0.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document);
  }

  const port = configService.get('PORT') || 3000;
  await app.listen(port);
  console.log(`🚀 Application running on: http://localhost:${port}`);
}
bootstrap();
MAIN
sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" src/main.ts && rm src/main.ts.bak

# ─── src/app.module.ts ───
cat > src/app.module.ts << 'APP'
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { PrismaModule } from './prisma/prisma.module';
import { CommonModule } from './common/common.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([{
      ttl: 60000,
      limit: 100,
    }]),
    PrismaModule,
    AuthModule,
    UsersModule,
    CommonModule,
  ],
})
export class AppModule {}
APP

# ─── src/prisma/prisma.module.ts ───
cat > src/prisma/prisma.module.ts << 'PRISMA_MOD'
import { Module, Global } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
PRISMA_MOD

# ─── src/prisma/prisma.service.ts ───
cat > src/prisma/prisma.service.ts << 'PRISMA_SVC'
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }

  async cleanDatabase() {
    if (process.env.NODE_ENV === 'production') return;
    const models = Reflect.ownKeys(this).filter((key) => key[0] !== '_' && key !== '$' && key !== 'constructor');
    return Promise.all(models.map((modelKey) => this[modelKey as string].deleteMany()));
  }
}
PRISMA_SVC

# ─── src/auth/auth.module.ts ───
cat > src/auth/auth.module.ts << 'AUTH_MOD'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './strategies/jwt.strategy';
import { LocalStrategy } from './strategies/local.strategy';

@Module({
  imports: [
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        secret: config.get('JWT_SECRET'),
        signOptions: { expiresIn: config.get('JWT_ACCESS_EXPIRATION') },
      }),
      inject: [ConfigService],
    }),
  ],
  providers: [AuthService, JwtStrategy, LocalStrategy],
  controllers: [AuthController],
  exports: [AuthService],
})
export class AuthModule {}
AUTH_MOD

# ─── src/auth/auth.service.ts ───
cat > src/auth/auth.service.ts << 'AUTH_SVC'
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
  ) {}

  async validateUser(email: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return null;
    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) return null;
    return { id: user.id, email: user.email, role: user.role };
  }

  async login(user: { id: string; email: string; role: string }) {
    const payload = { sub: user.id, email: user.email, role: user.role };
    return {
      access_token: this.jwtService.sign(payload),
      token_type: 'bearer',
      expires_in: 900,
    };
  }

  async register(email: string, password: string, name?: string) {
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new UnauthorizedException('Email already registered');
    const passwordHash = await bcrypt.hash(password, 12);
    return this.prisma.user.create({
      data: { email, passwordHash, name, role: 'user' },
      select: { id: true, email: true, name: true, role: true, createdAt: true },
    });
  }
}
AUTH_SVC

# ─── src/auth/auth.controller.ts ───
cat > src/auth/auth.controller.ts << 'AUTH_CTRL'
import { Controller, Post, Body, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { LocalAuthGuard } from './guards/local-auth.guard';
import { RegisterDto } from './dto/register.dto';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  @UseGuards(LocalAuthGuard)
  @ApiOperation({ summary: 'User login' })
  async login(@Request() req) {
    return this.authService.login(req.user);
  }

  @Post('register')
  @ApiOperation({ summary: 'User registration' })
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto.email, dto.password, dto.name);
  }
}
AUTH_CTRL

# ─── src/auth/dto/register.dto.ts ───
mkdir -p src/auth/dto src/auth/guards src/auth/strategies
cat > src/auth/dto/register.dto.ts << 'REGISTER_DTO'
import { IsEmail, IsString, MinLength, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class RegisterDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'password123', minLength: 8 })
  @IsString()
  @MinLength(8)
  password: string;

  @ApiPropertyOptional({ example: 'John Doe' })
  @IsOptional()
  @IsString()
  name?: string;
}
REGISTER_DTO

# ─── src/auth/guards/local-auth.guard.ts ───
cat > src/auth/guards/local-auth.guard.ts << 'LOCAL_GUARD'
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class LocalAuthGuard extends AuthGuard('local') {}
LOCAL_GUARD

# ─── src/auth/guards/jwt-auth.guard.ts ───
cat > src/auth/guards/jwt-auth.guard.ts << 'JWT_GUARD'
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
JWT_GUARD

# ─── src/auth/strategies/local.strategy.ts ───
cat > src/auth/strategies/local.strategy.ts << 'LOCAL_STRAT'
import { Strategy } from 'passport-local';
import { PassportStrategy } from '@nestjs/passport';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthService } from '../auth.service';

@Injectable()
export class LocalStrategy extends PassportStrategy(Strategy) {
  constructor(private authService: AuthService) {
    super({ usernameField: 'email' });
  }

  async validate(email: string, password: string): Promise<any> {
    const user = await this.authService.validateUser(email, password);
    if (!user) throw new UnauthorizedException();
    return user;
  }
}
LOCAL_STRAT

# ─── src/auth/strategies/jwt.strategy.ts ───
cat > src/auth/strategies/jwt.strategy.ts << 'JWT_STRAT'
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PassportStrategy } from '@nestjs/passport';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get('JWT_SECRET'),
    });
  }

  async validate(payload: { sub: string; email: string; role: string }) {
    return { id: payload.sub, email: payload.email, role: payload.role };
  }
}
JWT_STRAT

# ─── src/users/users.module.ts ───
cat > src/users/users.module.ts << 'USERS_MOD'
import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';

@Module({
  providers: [UsersService],
  controllers: [UsersController],
  exports: [UsersService],
})
export class UsersModule {}
USERS_MOD

# ─── src/users/users.service.ts ───
cat > src/users/users.service.ts << 'USERS_SVC'
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async findById(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: { id: true, email: true, name: true, role: true, createdAt: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async findByEmail(email: string) {
    return this.prisma.user.findUnique({ where: { email } });
  }
}
USERS_SVC

# ─── src/users/users.controller.ts ───
cat > src/users/users.controller.ts << 'USERS_CTRL'
import { Controller, Get, Param, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('Users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  async getMe(@Request() req) {
    return this.usersService.findById(req.user.id);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async getById(@Param('id') id: string, @Request() req) {
    // BOLA prevention: only allow access to own data
    if (req.user.id !== id) throw new NotFoundException('User not found');
    return this.usersService.findById(id);
  }
}
USERS_CTRL

# ─── src/common/common.module.ts ───
cat > src/common/common.module.ts << 'COMMON_MOD'
import { Module, Global } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard } from '@nestjs/throttler';
import { RedisService } from './redis.service';
import { LoggerService } from './logger.service';

@Global()
@Module({
  providers: [
    RedisService,
    LoggerService,
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
  exports: [RedisService, LoggerService],
})
export class CommonModule {}
COMMON_MOD

# ─── src/common/redis.service.ts ───
cat > src/common/redis.service.ts << 'REDIS_SVC'
import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit {
  private client: Redis;

  constructor(private configService: ConfigService) {}

  onModuleInit() {
    this.client = new Redis(this.configService.get('REDIS_URL') || 'redis://localhost:6379', {
      password: this.configService.get('REDIS_PASSWORD') || undefined,
    });
  }

  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }

  async set(key: string, value: string, ttl?: number): Promise<void> {
    if (ttl) {
      await this.client.setex(key, ttl, value);
    } else {
      await this.client.set(key, value);
    }
  }

  async del(key: string): Promise<void> {
    await this.client.del(key);
  }

  async getClient(): Promise<Redis> {
    return this.client;
  }
}
REDIS_SVC

# ─── src/common/logger.service.ts ───
cat > src/common/logger.service.ts << 'LOGGER_SVC'
import { Injectable, LoggerService as NestLoggerService } from '@nestjs/common';
import * as winston from 'winston';
import * as DailyRotateFile from 'winston-daily-rotate-file';

@Injectable()
export class LoggerService implements NestLoggerService {
  private logger: winston.Logger;

  constructor() {
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json(),
      ),
      transports: [
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple(),
          ),
        }),
        new DailyRotateFile({
          filename: 'logs/app-%DATE%.log',
          datePattern: 'YYYY-MM-DD',
          maxFiles: '30d',
        }),
      ],
    });
  }

  log(message: string, context?: string) {
    this.logger.info(message, { context });
  }
  error(message: string, trace?: string, context?: string) {
    this.logger.error(message, { trace, context });
  }
  warn(message: string, context?: string) {
    this.logger.warn(message, { context });
  }
  debug(message: string, context?: string) {
    this.logger.debug(message, { context });
  }
  verbose(message: string, context?: string) {
    this.logger.verbose(message, { context });
  }
}
LOGGER_SVC

# ─── prisma/schema.prisma ───
mkdir -p prisma
cat > prisma/schema.prisma << 'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id           String   @id @default(cuid())
  email        String   @unique
  name         String?
  passwordHash String
  role         String   @default("user")
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  @@index([email])
  @@index([role])
}

model AuditLog {
  id        String   @id @default(cuid())
  action    String
  userId    String?
  metadata  Json?
  createdAt DateTime @default(now())

  @@index([createdAt])
  @@index([userId])
}
PRISMA

# ─── prisma/seed.ts ───
cat > prisma/seed.ts << 'SEED'
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('password123', 12);
  await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: {},
    create: {
      email: 'admin@example.com',
      name: 'Admin User',
      passwordHash,
      role: 'admin',
    },
  });
  console.log('Seeded admin user');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
SEED

# ─── docker-compose.yml ───
cat > docker-compose.yml << 'DOCKER'
version: '3.8'

services:
  app:
    build: .
    container_name: PROJECT_NAME-app
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/PROJECT_NAME?schema=public
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
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production=false
COPY . .
RUN npm run build
RUN npm prune --production

# ─── Production Stage ───
FROM node:20-alpine

WORKDIR /app
RUN apk add --no-cache curl

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/prisma ./prisma

ENV NODE_ENV=production
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/api/v1/health/live || exit 1

CMD ["node", "dist/main"]
DOCKERFILE

# ─── .gitignore ───
cat > .gitignore << 'GITIGNORE'
# Dependencies
node_modules/

# Build output
dist/
build/

# Environment
.env
.env.local
.env.*.local

# Logs
logs/
*.log

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Test coverage
coverage/

# Prisma
prisma/migrations/
GITIGNORE

# ─── .prettierrc ───
cat > .prettierrc << 'PRETTIER'
{
  "singleQuote": true,
  "trailingComma": "all",
  "tabWidth": 2,
  "semi": true,
  "printWidth": 100
}
PRETTIER

# ─── .eslintrc.js ───
cat > .eslintrc.js << 'ESLINT'
module.exports = {
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: 'tsconfig.json',
    tsconfigRootDir: __dirname,
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint/eslint-plugin'],
  extends: [
    'plugin:@typescript-eslint/recommended',
    'plugin:prettier/recommended',
  ],
  root: true,
  env: { node: true, jest: true },
  rules: {
    '@typescript-eslint/interface-name-prefix': 'off',
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/explicit-module-boundary-types': 'off',
    '@typescript-eslint/no-explicit-any': 'warn',
  },
};
ESLINT

echo ""
echo "✅ NestJS scaffold complete: $PROJECT_NAME"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_NAME"
echo "  npm install"
echo "  npx prisma generate"
echo "  npx prisma migrate dev --name init"
echo "  npm run prisma:seed"
echo "  npm run start:dev"
echo ""
echo "Swagger docs: http://localhost:3000/api/docs"
