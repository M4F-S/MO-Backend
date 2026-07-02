# Memory Layer Integration Reference

## Overview

This reference provides detailed templates and patterns for persisting project knowledge to the Obsidian vault using the `mo-graphify-obsidian-memory` skill. Both `MO-Frontend` and `MO-Backend` skills write to the same vault, creating a unified knowledge graph for full-stack projects.

## Vault Structure

```
~/Vaults/{project-name}/wiki/
├── index.md                    # Project index MOC
├── hot.md                      # Recent context cache
├── frontend/
│   ├── design-system.md
│   ├── components.md
│   ├── api-integration.md
│   └── performance.md
├── backend/
│   ├── api-contract.md
│   ├── database-schema.md
│   ├── security.md
│   └── integrations.md
├── decisions/
│   ├── ADR-001-database.md
│   ├── ADR-002-auth.md
│   └── ADR-003-frontend-framework.md
└── shared/
    ├── api-contract.md
    └── deployment.md
```

## Project MOC Template

```markdown
---
title: Project Name — Index
date: 2026-07-02
tags: [project, full-stack, active]
type: project
status: active
links:
  - "[[Project Name — Frontend]]"
  - "[[Project Name — Backend]]"
---

# Project Name

## Overview
Brief description of the project and its goals.

## Stack
- **Frontend:** Next.js 15 + React 19 + Tailwind CSS v4 + shadcn/ui
- **Backend:** NestJS + PostgreSQL + Redis + Prisma
- **Deployment:** Vercel (frontend) + Railway (backend)

## Links
- **Frontend MOC:** [[Project Name — Frontend]]
- **Backend MOC:** [[Project Name — Backend]]
- **API Contract:** [[Project Name — API Contract]]
- **Database Schema:** [[Project Name — Database Schema]]

## Decisions
- [[Project Name — ADR-001 Database]] — PostgreSQL vs MongoDB
- [[Project Name — ADR-002 Auth]] — JWT vs OAuth 2.1
- [[Project Name — ADR-003 Frontend Framework]] — Next.js vs Vite

## Status
- [x] Initial setup
- [x] Database schema
- [ ] Auth implementation
- [ ] Core API endpoints
- [ ] Frontend pages
- [ ] Deployment pipeline
```

## Frontend MOC Template

```markdown
---
title: Project Name — Frontend
date: 2026-07-02
tags: [frontend, project]
type: MOC
links:
  - "[[Project Name — Backend]]"
  - "[[Project Name — Design System]]"
  - "[[Project Name — Components]]"
---

# Project Name — Frontend

## Design System
- [[Project Name — Design System]] — Colors, typography, glassmorphism

## Components
- [[Project Name — Components]] — shadcn/ui registry, custom components

## API Integration
- [[Project Name — Frontend API Contract]] — TanStack Query patterns, endpoint mapping

## Decisions
- [[Project Name — ADR-003 Frontend Framework]] — Next.js vs Vite
- [[Project Name — ADR-004 Animation Library]] — Framer Motion vs GSAP

## Backend Coordination
- [[Project Name — Backend]]
- [[Project Name — API Contract]]
```

## Backend MOC Template

```markdown
---
title: Project Name — Backend
date: 2026-07-02
tags: [backend, project]
type: MOC
links:
  - "[[Project Name — Frontend]]"
  - "[[Project Name — Database Schema]]"
  - "[[Project Name — API Contract]]"
---

# Project Name — Backend

## Database
- [[Project Name — Database Schema]] — ER diagram, indexes, migrations

## API
- [[Project Name — API Contract]] — OpenAPI spec, endpoint mapping, error codes

## Security
- [[Project Name — Security]] — Auth, rate limiting, CORS, secrets

## Integrations
- [[Project Name — Integrations]] — Stripe, email, search, storage

## Decisions
- [[Project Name — ADR-001 Database]] — PostgreSQL vs MongoDB
- [[Project Name — ADR-002 Auth]] — JWT vs OAuth 2.1
- [[Project Name — ADR-005 API Style]] — REST vs GraphQL

## Frontend Coordination
- [[Project Name — Frontend]]
- [[Project Name — Frontend API Contract]]
```

## ADR Template

```markdown
---
title: Project Name — ADR-001 Database
date: 2026-07-02
tags: [decision, backend, database]
type: decision
status: accepted
links:
  - "[[Project Name — Backend]]"
  - "[[Project Name — Database Schema]]"
---

# ADR-001: Database Choice

## Context
What is the issue that we're seeing that is motivating this decision or change?

## Decision
What is the change that we're proposing or have agreed to implement?

## Consequences
What becomes easier or more difficult to do because of this change?

### Positive
- Benefit 1
- Benefit 2

### Negative
- Trade-off 1
- Trade-off 2

## Alternatives Considered
- Alternative 1: Why rejected
- Alternative 2: Why rejected

## Verification
- [ ] Decision documented in vault
- [ ] Schema updated
- [ ] Team reviewed
```

## API Contract Template

```markdown
---
title: Project Name — API Contract
date: 2026-07-02
tags: [api, contract, backend, frontend]
type: reference
links:
  - "[[Project Name — Backend]]"
  - "[[Project Name — Frontend]]"
  - "[[Project Name — Database Schema]]"
---

# API Contract

## Base URL
- Development: `http://localhost:3001`
- Staging: `https://api-staging.example.com`
- Production: `https://api.example.com`

## Authentication
- JWT (RS256) in `httpOnly` cookie
- Refresh token rotation
- CSRF token for mutation endpoints

## Endpoints

### Auth
| Method | Endpoint | Description | Frontend Usage |
|--------|----------|-------------|----------------|
| POST | `/v1/auth/login` | Login | `useLoginMutation` |
| POST | `/v1/auth/refresh` | Refresh token | `useRefreshToken` interceptor |
| POST | `/v1/auth/logout` | Logout | `useLogoutMutation` |

### Resources
| Method | Endpoint | Description | Frontend Usage |
|--------|----------|-------------|----------------|
| GET | `/v1/users` | List users | `useUsersQuery` |
| GET | `/v1/users/:id` | Get user | `useUserQuery` |
| POST | `/v1/users` | Create user | `useCreateUserMutation` |

## Error Codes
| Code | Status | Description | Frontend Handling |
|------|--------|-------------|-----------------|
| `AUTH_INVALID` | 401 | Invalid credentials | Redirect to login |
| `RATE_LIMITED` | 429 | Too many requests | Retry with backoff |
| `VALIDATION_ERROR` | 422 | Input validation failed | Show field errors |

## Shared Types
```typescript
// Generated from OpenAPI spec
// See scripts/generate-shared-types.sh
```
```

## Python Helpers

### Initialize Project Vault
```python
import os

def init_project_vault(project_name, vault_base="~/Vaults"):
    """Create project vault structure."""
    vault_path = os.path.expanduser(f"{vault_base}/{project_name}/wiki")
    
    dirs = ["frontend", "backend", "decisions", "shared"]
    for d in dirs:
        os.makedirs(os.path.join(vault_path, d), exist_ok=True)
    
    # Create index MOC
    create_note(
        title=f"{project_name} — Index",
        content=f"Project hub for {project_name}.\n\n## Stack\n\n## Links\n\n## Decisions\n\n## Status",
        tags=["project", "full-stack", "active"],
        note_type="project",
        links=[f"{project_name} — Frontend", f"{project_name} — Backend"]
    )
    
    return vault_path
```

### Create Full-Stack Project
```python
def create_fullstack_project(project_name, vault_path=None):
    """Create all MOCs and initial notes for a full-stack project."""
    if vault_path is None:
        vault_path = init_project_vault(project_name)
    
    # Frontend MOC
    create_moc(
        title=f"{project_name} — Frontend",
        description=f"Frontend architecture and design decisions for {project_name}.",
        related_notes=[
            f"{project_name} — Design System",
            f"{project_name} — Components",
            f"{project_name} — Frontend API Contract"
        ]
    )
    
    # Backend MOC
    create_moc(
        title=f"{project_name} — Backend",
        description=f"Backend architecture and API decisions for {project_name}.",
        related_notes=[
            f"{project_name} — Database Schema",
            f"{project_name} — API Contract",
            f"{project_name} — Security"
        ]
    )
    
    # API Contract
    create_note(
        title=f"{project_name} — API Contract",
        content="## Base URL\n\n## Authentication\n\n## Endpoints\n\n## Error Codes\n\n## Shared Types",
        tags=["api", "contract", "shared"],
        note_type="reference",
        links=[f"{project_name} — Frontend", f"{project_name} — Backend"]
    )
    
    return vault_path
```

## Cross-Skill Linking Rules

1. **Always bidirectional link:** If frontend MOC links to backend MOC, backend MOC must link to frontend MOC.
2. **Shared notes in `shared/`:** API contracts, deployment config, and project index go in the shared folder.
3. **Tag consistently:** All notes use `["project-name"]` plus skill tag (`["frontend"]` or `["backend"]`).
4. **ADR naming:** Use sequential numbers: `ADR-001`, `ADR-002`, etc. Reset counter per project.
5. **Update hot.md:** After every significant session, update the project's `hot.md` with recent changes.

## Summary

| Operation | Command |
|-----------|---------|
| Init project vault | `init_project_vault("MyProject")` |
| Create full-stack project | `create_fullstack_project("MyProject")` |
| Create ADR | `create_note(title="ADR-005 Topic", tags=["decision"], type="decision")` |
| Link frontend to backend | Add `[[Project Name — Backend]]` to frontend MOC |
| Update hot cache | `update_note("Project Name — hot", append_content="...")` |
