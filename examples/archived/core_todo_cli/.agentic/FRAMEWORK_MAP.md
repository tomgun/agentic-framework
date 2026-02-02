# Framework Map: Visual Guide

This document shows how all parts of the agentic framework fit together.

## High-level relationships

```mermaid
graph TB
    subgraph truth [Project Truth at repo root]
        STACK[STACK.md<br/>how to build/test]
        STATUS[STATUS.md<br/>current state]
        CONTEXT[CONTEXT_PACK.md<br/>durable context]
        JOURNAL[JOURNAL.md<br/>session log]
        HUMAN[HUMAN_NEEDED.md<br/>escalations]
    end
    
    subgraph specs [spec/ - Specifications]
        PRD[PRD.md<br/>requirements]
        TECH[TECH_SPEC.md<br/>architecture]
        FEATURES[FEATURES.md<br/>feature registry]
        NFR[NFR.md<br/>constraints]
        ACC[acceptance/<br/>F-####.md]
        ADR[adr/<br/>decisions]
    end
    
    subgraph code [Codebase]
        SRC[src/<br/>annotated with @feature]
        TESTS[tests/<br/>unit/integration]
    end
    
    subgraph tools [.agentic/tools/]
        DOCTOR[doctor.sh<br/>check structure]
        REPORT[report.sh<br/>feature status]
        VERIFY[verify.sh<br/>comprehensive]
        COVERAGE[coverage.sh<br/>annotations]
        GRAPH[feature_graph.sh<br/>dependencies]
    end
    
    PRD --> FEATURES
    TECH --> FEATURES
    FEATURES --> ACC
    FEATURES --> SRC
    NFR --> FEATURES
    ADR --> TECH
    
    SRC --> TESTS
    
    TOOLS --> specs
    TOOLS --> code
    
    STATUS --> FEATURES
    CONTEXT --> TECH
    JOURNAL --> STATUS
```

---

## Agent workflow (session start to implementation)

```mermaid
sequenceDiagram
    participant Agent
    participant Context as CONTEXT_PACK.md
    participant Status as STATUS.md
    participant Journal as JOURNAL.md
    participant Spec as spec/
    participant Code as Codebase
    participant Tests as Tests
    
    Agent->>Context: 1. Read (where is X?)
    Agent->>Status: 2. Read (what's current focus?)
    Agent->>Journal: 3. Read last 2-3 entries
    Agent->>Spec: 4. Read acceptance for F-####
    Agent->>Code: 5. Search for @feature annotations
    Agent->>Code: 6. Read relevant files only
    Agent->>Code: 7. Implement changes
    Agent->>Tests: 8. Add/update tests
    Agent->>Status: 9. Update with progress
    Agent->>Journal: 10. Append session summary
```

---

## Development loop

```mermaid
flowchart TD
    Start([Start Session]) --> ReadContext[Read CONTEXT_PACK.md<br/>STATUS.md<br/>JOURNAL.md]
    ReadContext --> PickWork[Pick work from STATUS.md]
    PickWork --> ReadAcc[Read acceptance criteria]
    ReadAcc --> Plan[Plan small change]
    Plan --> Implement[Implement + annotate]
    Implement --> Test[Add/update tests]
    Test --> Review[Self-review]
    Review --> UpdateDocs[Update STATUS.md<br/>JOURNAL.md<br/>FEATURES.md]
    UpdateDocs --> Done{More work?}
    Done -->|Yes| PickWork
    Done -->|No| End([Session complete])
```

---

## Document lifecycle and dependencies

```mermaid
graph LR
    subgraph init [Initialization Phase]
        InitQ[Agent asks<br/>init questions]
        InitQ --> WriteStack[Write STACK.md]
        InitQ --> WriteContext[Write CONTEXT_PACK.md]
        InitQ --> WritePRD[Write spec/PRD.md]
        InitQ --> WriteTech[Write spec/TECH_SPEC.md]
        InitQ --> WriteStatus[Write STATUS.md]
    end
    
    subgraph dev [Development Phase]
        WritePRD --> CreateFeatures[Create FEATURES.md<br/>with F-#### IDs]
        CreateFeatures --> WriteAcc[Write acceptance/<br/>F-####.md]
        WriteAcc --> Implement[Implement with<br/>@feature annotations]
        Implement --> UpdateFeatures[Update FEATURES.md<br/>implementation status]
        UpdateFeatures --> UpdateStatus[Update STATUS.md]
        UpdateStatus --> AppendJournal[Append JOURNAL.md]
    end
    
    subgraph decisions [Decision Points]
        TradeOff{Tradeoff decision?}
        TradeOff -->|Yes| WriteADR[Write ADR-####]
        TradeOff -->|No| Continue[Continue]
        WriteADR --> UpdateTech[Update TECH_SPEC.md]
    end
    
    dev --> decisions
```

---

## Tool dependencies

```mermaid
graph TD
    subgraph inputs [Input Files]
        FEAT[spec/FEATURES.md]
        NFRS[spec/NFR.md]
        STAT[STATUS.md]
        ACC[spec/acceptance/]
        CODE[Codebase with<br/>@feature annotations]
    end
    
    subgraph tools [Tools]
        DOC[doctor.sh]
        REP[report.sh]
        VER[verify.sh]
        COV[coverage.sh]
        GRAPH[feature_graph.sh]
    end
    
    subgraph outputs [Outputs/Checks]
        Structure[Structure valid?]
        FeatStatus[Feature status<br/>summary]
        CrossRef[Cross-references<br/>valid?]
        Coverage[Annotation<br/>coverage %]
        DepGraph[Dependency<br/>visualization]
    end
    
    FEAT --> DOC
    NFRS --> DOC
    STAT --> DOC
    ACC --> DOC
    
    DOC --> Structure
    
    FEAT --> REP
    REP --> FeatStatus
    
    FEAT --> VER
    NFRS --> VER
    STAT --> VER
    ACC --> VER
    VER --> CrossRef
    
    FEAT --> COV
    CODE --> COV
    COV --> Coverage
    
    FEAT --> GRAPH
    GRAPH --> DepGraph
```

---

## Feature lifecycle

```mermaid
stateDiagram-v2
    [*] --> Planned: Feature added to<br/>FEATURES.md
    
    Planned --> InProgress: Agent starts work<br/>Updates STATUS.md
    
    InProgress --> Implemented: Code written<br/>@feature annotations added<br/>Update State: partial/complete
    
    Implemented --> Tested: Tests written<br/>Update Tests: complete
    
    Tested --> Accepted: Acceptance verified<br/>Set Accepted: yes
    
    Accepted --> Shipped: Deployed<br/>Set Status: shipped
    
    Shipped --> [*]
    
    Planned --> Deprecated: Requirement changed
    InProgress --> Deprecated: Pivot decision
    Deprecated --> [*]
    
    note right of Planned
        spec/FEATURES.md:
        Status: planned
        State: none
        Tests: todo
    end note
    
    note right of Shipped
        spec/FEATURES.md:
        Status: shipped
        State: complete
        Tests: complete
        Accepted: yes
    end note
```

---

## Information flow: Specs → Code → Tests

```mermaid
graph LR
    subgraph specification [Specification]
        F[F-0001 in<br/>FEATURES.md]
        A[F-0001.md<br/>acceptance criteria]
        N[NFR-0001 in<br/>NFR.md]
    end
    
    subgraph implementation [Implementation]
        C1[Component A<br/>@feature F-0001<br/>@nfr NFR-0001]
        C2[Component B<br/>@feature F-0001]
    end
    
    subgraph testing [Testing]
        U1[Unit tests<br/>component A]
        U2[Unit tests<br/>component B]
        I[Integration tests<br/>F-0001]
        E[E2E test<br/>F-0001 acceptance]
    end
    
    F --> A
    A --> C1
    A --> C2
    N --> C1
    
    C1 --> U1
    C2 --> U2
    C1 --> I
    C2 --> I
    A --> E
```

---

## Token efficiency strategy

```mermaid
graph TB
    Start([Session Start<br/>10-15K token budget])
    
    Start --> Always[Always Read 2-3K tokens:<br/>CONTEXT_PACK.md<br/>STATUS.md<br/>JOURNAL.md recent]
    
    Always --> Task{Know the task?}
    Task -->|No| ReadStatus[Read more STATUS.md]
    ReadStatus --> Task
    
    Task -->|Yes| Acc[Read acceptance<br/>F-####.md<br/>~1K tokens]
    
    Acc --> Find[Search for @feature<br/>to find code<br/>~0 tokens]
    
    Find --> ReadCode[Read specific files only<br/>3-5K tokens]
    
    ReadCode --> Ready{Can implement?}
    
    Ready -->|No, unclear| ReadMore[Read TECH_SPEC section<br/>~1-2K tokens]
    ReadMore --> Ready
    
    Ready -->|Yes| Code[Start coding<br/>~5K buffer remaining]
    
    Code --> Done([Implementation])
    
    style Always fill:#90EE90
    style Code fill:#87CEEB
```

---

## Quality gates

```mermaid
graph LR
    Change[Code Change] --> Review{Self Review}
    Review -->|Pass| Tests{Tests Pass?}
    Review -->|Fail| Fix1[Fix Issues]
    Fix1 --> Review
    
    Tests -->|Fail| Fix2[Fix Code/Tests]
    Fix2 --> Tests
    
    Tests -->|Pass| Docs{Docs Updated?}
    Docs -->|No| UpdateDocs[Update STATUS.md<br/>FEATURES.md<br/>JOURNAL.md]
    UpdateDocs --> Docs
    
    Docs -->|Yes| Verify{verify.sh clean?}
    
    Verify -->|Fail| Fix3[Fix Issues]
    Fix3 --> Verify
    
    Verify -->|Pass| Done([Ready to commit])
    
    style Done fill:#90EE90
```

---

## Scaling thresholds (when to reorganize)

```mermaid
graph TD
    Check[Periodic Check] --> Count{What's growing?}
    
    Count -->|Features > 30| SplitFeat[Suggest splitting<br/>FEATURES.md by domain]
    Count -->|NFRs > 15| SplitNFR[Suggest splitting<br/>NFR.md by category]
    Count -->|ADRs > 20| IndexADR[Suggest ADR index<br/>by category]
    Count -->|Files > 100| SplitContext[Suggest module-specific<br/>context docs]
    Count -->|Tests > 5min| SplitTests[Suggest fast/slow<br/>test separation]
    
    SplitFeat --> Present[Present suggestion<br/>to user]
    SplitNFR --> Present
    IndexADR --> Present
    SplitContext --> Present
    SplitTests --> Present
    
    Present --> Decision{User decides}
    Decision -->|Accept| Implement[Agent helps<br/>reorganize]
    Decision -->|Reject| Continue[Continue as-is]
    
    Implement --> Done[Reorganized]
    Continue --> Done
```

---

## Legend

**Colors in diagrams:**
- Green: Success/completion states
- Blue: Active work/implementation
- Yellow/Orange: Decision points
- Gray: Normal states

**Arrow types:**
- Solid arrow (→): Direct dependency or flow
- Dotted arrow (⋯→): Optional or conditional relationship

**Box types:**
- Rectangle: Process or file
- Diamond: Decision point
- Rounded rectangle: Start/end states
- Cylinder: Database or persistent storage

---

## Quick navigation

- **New to framework?** Start at [`START_HERE.md`](START_HERE.md)
- **Need specific docs?** See START_HERE document index
- **Want workflows?** See [`workflows/`](workflows/) directory
- **Need tools help?** See [`tools/`](tools/) directory with .sh scripts


