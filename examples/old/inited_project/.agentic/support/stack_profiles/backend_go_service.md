# Stack profile: Go backend service

Quick guidance for initializing a Go-based backend service with this framework.

## Tech choices

### Language & runtime
- Go 1.21+ recommended
- Module management: go modules (`go.mod`)

### Testing
- Test framework: standard `testing` package
- Mocking: `gomock` or interface-based mocks
- Integration tests: `testcontainers-go` for DB/services
- Test command: `go test ./...`
- Coverage: `go test -cover ./...`

### Common dependencies
- HTTP router: `chi`, `gin`, or stdlib `net/http`
- Database: `database/sql` + driver (`pgx` for postgres)
- Migrations: `golang-migrate` or `goose`
- Config: `viper` or environment variables
- Logging: `slog` (Go 1.21+) or `zap`

### Project structure (typical)
```
/cmd
  /api          # main.go for API server
/internal
  /handlers     # HTTP handlers
  /services     # Business logic
  /repository   # Data access
/pkg            # Public libraries
/migrations     # Database migrations
/testdata       # Test fixtures
```

## STACK.md template sections

```markdown
## Build & run
- Build: `go build -o bin/api cmd/api/main.go`
- Run: `./bin/api` or `go run cmd/api/main.go`
- Test: `go test ./...`
- Lint: `golangci-lint run`

## Dependencies
- Install: `go mod download`
- Update: `go get -u ./...`
- Tidy: `go mod tidy`

## Database
- Driver: pgx
- Migrations: golang-migrate
- Test DB: testcontainers or docker-compose

## Key constraints
- Go 1.21+ required
- CGO disabled by default
- Build for linux/amd64
```

## Test strategy guidance

### Unit tests
- Co-located: `user_service_test.go` next to `user_service.go`
- Table-driven tests for multiple scenarios
- Interface-based mocking

```go
func TestUserService_Create(t *testing.T) {
    tests := []struct{
        name string
        input User
        wantErr bool
    }{
        {"valid user", User{Email: "test@example.com"}, false},
        {"invalid email", User{Email: "invalid"}, true},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // test logic
        })
    }
}
```

### Integration tests
- Use `testcontainers-go` for real postgres/redis
- Or docker-compose with test profile
- Clean database between tests

## NFR considerations

For `spec/NFR.md`:
- **Performance**: Go excels at concurrency - document goroutine/channel usage patterns
- **Memory**: Document if you need to avoid GC pauses (realtime scenarios)
- **Deployment**: Static binary makes deployment simple - note target platforms

## Common gotchas

- Error handling: decide on error wrapping strategy (`errors.Wrap` vs `fmt.Errorf("%w")`)
- Context cancellation: use `context.Context` throughout
- Database connection pooling: configure MaxOpenConns appropriately
- Graceful shutdown: handle SIGTERM in main.go

## References

- Effective Go: https://go.dev/doc/effective_go
- Go project layout: https://github.com/golang-standards/project-layout
- Testing: https://go.dev/doc/tutorial/add-a-test

