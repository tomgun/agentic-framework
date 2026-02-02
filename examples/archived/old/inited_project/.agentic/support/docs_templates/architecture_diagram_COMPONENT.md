# Architecture Diagram: [COMPONENT NAME]

**Purpose**: Visual representation of [component/system/subsystem] architecture.

**Last updated**: YYYY-MM-DD

**Related specs**: `spec/TECH_SPEC.md`, ADR-####

---

## Context (C4 Level 1)

High-level system context showing external actors and systems.

```mermaid
C4Context
    title System Context for [Your System]
    
    Person(user, "User", "Primary user of the system")
    System(yourSystem, "Your System", "Core application")
    System_Ext(externalAPI, "External API", "Third-party service")
    
    Rel(user, yourSystem, "Uses")
    Rel(yourSystem, externalAPI, "Calls", "HTTPS")
```

---

## Container (C4 Level 2)

Major containers/deployable units and their interactions.

```mermaid
C4Container
    title Container Diagram for [Your System]
    
    Person(user, "User")
    
    Container(webapp, "Web App", "React/Next.js", "User interface")
    Container(api, "API Server", "Node.js/Express", "Business logic")
    ContainerDb(db, "Database", "PostgreSQL", "Persistent data")
    
    Rel(user, webapp, "Uses", "HTTPS")
    Rel(webapp, api, "Calls", "REST/JSON")
    Rel(api, db, "Reads/writes", "SQL")
```

---

## Component (C4 Level 3)

Key components within a container and their responsibilities.

```mermaid
graph TD
    subgraph api [API Server]
        authModule[Auth Module]
        userService[User Service]
        dataLayer[Data Access Layer]
    end
    
    subgraph db [Database]
        userTable[(Users Table)]
        sessionTable[(Sessions Table)]
    end
    
    authModule --> userService
    userService --> dataLayer
    dataLayer --> userTable
    authModule --> sessionTable
```

---

## Data Flow

Show how data flows through the system for key operations.

```mermaid
sequenceDiagram
    actor User
    participant WebApp
    participant API
    participant DB
    
    User->>WebApp: Submit form
    WebApp->>API: POST /api/resource
    API->>API: Validate input
    API->>DB: INSERT INTO table
    DB-->>API: Success
    API-->>WebApp: 201 Created
    WebApp-->>User: Show confirmation
```

---

## Deployment

Infrastructure and deployment topology.

```mermaid
graph LR
    subgraph cloud [Cloud Provider]
        subgraph vpc [VPC]
            lb[Load Balancer]
            app1[App Server 1]
            app2[App Server 2]
            db[(Database)]
        end
        cdn[CDN]
    end
    
    users[Users] --> cdn
    cdn --> lb
    lb --> app1
    lb --> app2
    app1 --> db
    app2 --> db
```

---

## Design Notes

### Key decisions
- Decision 1: rationale (link to ADR-#### if exists)
- Decision 2: rationale

### Constraints
- Constraint from `STACK.md` or `spec/NFR.md`

### Evolution
- Original design: brief description
- Changed on YYYY-MM-DD: what changed and why (link ADR if applicable)

---

## Related Resources
- Technical spec: `spec/TECH_SPEC.md#architecture`
- ADRs: ADR-0001, ADR-0003
- Features: F-0001, F-0005

