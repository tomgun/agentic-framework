# Python Backend Quality Knowledge

Deep domain expertise for building production Python backends with Django, FastAPI, or Flask.

## ORM Anti-Patterns

### N+1 Query Problem
The most common performance issue in Django/SQLAlchemy applications.

```python
# BAD: N+1 queries — 1 query for posts + N queries for authors
posts = Post.objects.all()
for post in posts:
    print(post.author.name)  # Each access triggers a new query

# GOOD: Django — prefetch in one query
posts = Post.objects.select_related('author').all()

# GOOD: SQLAlchemy — eager load
posts = session.query(Post).options(joinedload(Post.author)).all()
```

### Lazy Loading Traps
- Django: All foreign key access is lazy by default
- SQLAlchemy: Depends on `relationship()` configuration
- Fix: Always use `select_related()` (FK) or `prefetch_related()` (M2M) for data you know you'll access

## Async Python Pitfalls

### Blocking in Async Context
```python
# BAD: time.sleep blocks the event loop
@app.get("/slow")
async def slow():
    time.sleep(5)  # Blocks ALL concurrent requests
    return {"status": "done"}

# GOOD: Use async sleep
@app.get("/slow")
async def slow():
    await asyncio.sleep(5)  # Only this request waits
    return {"status": "done"}

# GOOD: Run sync code in executor
@app.get("/cpu-heavy")
async def cpu_heavy():
    result = await asyncio.get_event_loop().run_in_executor(
        None, expensive_computation
    )
    return {"result": result}
```

### Common Blocking Operations to Watch For
- `time.sleep()` → `asyncio.sleep()`
- `requests.get()` → `httpx.AsyncClient.get()`
- File I/O → `aiofiles`
- Database queries → async ORM (SQLAlchemy async, Django 4.1+ async ORM)

## Database Migration Safety

### Django
```bash
# Check for missing migrations
python manage.py makemigrations --check --dry-run

# Apply migrations
python manage.py migrate

# DANGEROUS operations that need care:
# - Removing a column: first deploy code that doesn't use it, then migrate
# - Renaming: use db_column to decouple model field name from DB column
# - Adding NOT NULL: always provide a default or make migration two-step
```

### Alembic (FastAPI/Flask)
```bash
# Generate migration
alembic revision --autogenerate -m "add user table"

# Apply
alembic upgrade head

# Rollback
alembic downgrade -1
```

### Zero-Downtime Migration Pattern
For large tables or busy databases:
1. Add new column as nullable
2. Deploy code that writes to both old and new columns
3. Backfill existing rows
4. Deploy code that reads from new column
5. Remove old column

## Input Validation

### FastAPI + Pydantic
```python
from pydantic import BaseModel, Field, EmailStr

class CreateUser(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=100)
    age: int = Field(ge=0, le=150)

@app.post("/users")
async def create_user(user: CreateUser):
    # user is already validated — safe to use
    ...
```

### Django REST Framework
```python
class UserSerializer(serializers.Serializer):
    email = serializers.EmailField()
    name = serializers.CharField(min_length=1, max_length=100)
    age = serializers.IntegerField(min_value=0, max_value=150)
```

## Testing Python Backends

### Test Database Strategy
- Use a separate test database (pytest-django creates/destroys per session)
- Use `testcontainers` for real PostgreSQL/Redis in CI
- Never mock the database for integration tests — real DB catches migration and constraint issues

### Fixtures Pattern
```python
import pytest
from httpx import AsyncClient

@pytest.fixture
async def client(app):
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.fixture
async def user(db_session):
    user = User(email="test@example.com", name="Test")
    db_session.add(user)
    await db_session.commit()
    return user

async def test_get_user(client, user):
    response = await client.get(f"/users/{user.id}")
    assert response.status_code == 200
    assert response.json()["email"] == "test@example.com"
```

## Connection Pool Management

### SQLAlchemy
```python
engine = create_async_engine(
    DATABASE_URL,
    pool_size=20,        # Max persistent connections
    max_overflow=10,     # Extra connections when pool is full
    pool_timeout=30,     # Seconds to wait for a connection
    pool_recycle=1800,   # Recycle connections after 30 minutes
)
```

### Django
```python
DATABASES = {
    'default': {
        'CONN_MAX_AGE': 600,  # Keep connections alive for 10 minutes
        'CONN_HEALTH_CHECKS': True,  # Django 4.1+: check before reuse
    }
}
```

## Deployment Checklist
- [ ] `DEBUG = False` in production
- [ ] `SECRET_KEY` from environment variable, not hardcoded
- [ ] HTTPS enforced (SECURE_SSL_REDIRECT in Django)
- [ ] Database connection pooling configured
- [ ] Logging configured with structured output (JSON)
- [ ] Health check endpoint exists (`/health` or `/healthz`)
- [ ] Graceful shutdown handles in-flight requests
- [ ] Static files served by CDN/nginx, not the application
