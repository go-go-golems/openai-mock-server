APP=openai-mock-server
MOCK_SERVER_CONFIG ?= pkg/server/config/bot.yaml

.PHONY: help fmt vet build run test test-chat test-responses test-stream clean docs lint lintmax docker-lint gosec govulncheck

help:
	@echo "Common targets:"
	@echo "  make fmt           - go fmt ./..."
	@echo "  make vet           - go vet ./..."
	@echo "  make build         - build $(APP)"
	@echo "  make run           - run server (uses $(MOCK_SERVER_CONFIG))"
	@echo "  make docs          - print all embedded docs (help --all)"
	@echo "  make test          - run all Python tests (server must be running)"
	@echo "  make test-chat     - run chat SDK tests"
	@echo "  make test-responses- run Responses API suite"
	@echo "  make test-stream   - run streaming tests"
	@echo "  make clean         - remove binary"
	@echo "  make lint          - run golangci-lint"
	@echo "  make docker-lint   - run golangci-lint in docker"
	@echo "  make gosec         - run gosec static analysis"
	@echo "  make govulncheck   - run govulncheck vulnerability scan"

docs:
	go run ./cmd/openai-mock-server help --all

fmt:
	go fmt ./...

vet:
	go vet ./...

lint:
	golangci-lint run -v

lintmax:
	golangci-lint run -v --max-same-issues=100

docker-lint:
	docker run --rm -v $(shell pwd):/app -w /app golangci/golangci-lint:v2.0.2 golangci-lint run -v

gosec:
	go install github.com/securego/gosec/v2/cmd/gosec@latest
	gosec -exclude=G101,G304,G301,G306,G204 -exclude-dir=ttmp -exclude-dir=.history ./...

govulncheck:
	go install golang.org/x/vuln/cmd/govulncheck@latest
	govulncheck ./...

build:
	go build -o $(APP) ./cmd/openai-mock-server

run:
	@echo "Starting server with $(MOCK_SERVER_CONFIG)"
	MOCK_SERVER_CONFIG=$(MOCK_SERVER_CONFIG) go run ./cmd/openai-mock-server serve

test: test-chat test-responses test-stream

test-chat:
	python3 tests/python/test_mock_server.py || true

test-responses:
	python3 tests/python/test_responses_api.py || true

test-stream:
	python3 tests/python/streaming_test.py || true

clean:
	rm -f $(APP)

.PHONY: logcopter-generate
logcopter-generate:
	GOWORK=off go tool logcopter-gen -include-main -var zlog -area-prefix go-go-golems.openai-mock-server -strip-prefix mock-openai-server ./cmd/... ./pkg/...

.PHONY: logcopter-check
logcopter-check:
	GOWORK=off go tool logcopter-gen -include-main -var zlog -area-prefix go-go-golems.openai-mock-server -strip-prefix mock-openai-server -check ./cmd/... ./pkg/...

GLAZED_LINT_BIN ?= /tmp/glazed-lint
GLAZED_LINT_PKG ?= github.com/go-go-golems/glazed/cmd/tools/glazed-lint
GLAZED_VERSION ?= v1.3.4

.PHONY: glazed-lint-build glazed-lint

glazed-lint-build:
	@echo "Building glazed-lint from Glazed module..."
	@if [ -n "$(GLAZED_VERSION)" ]; then \
		echo "Installing $(GLAZED_LINT_PKG)@$(GLAZED_VERSION)"; \
		GOBIN=$(dir $(GLAZED_LINT_BIN)) GOWORK=off go install $(GLAZED_LINT_PKG)@$(GLAZED_VERSION); \
	else \
		echo "Installing $(GLAZED_LINT_PKG) from workspace/module"; \
		GOBIN=$(dir $(GLAZED_LINT_BIN)) go install $(GLAZED_LINT_PKG); \
	fi

# The server config package is legacy runtime/environment plumbing rather than
# Glazed CLI flag wiring; allow it while keeping the rollout gate enabled.
GLAZED_LINT_ALLOW_PATHS ?= pkg/server/config/

glazed-lint: glazed-lint-build
	GOWORK=off go vet -vettool=$(GLAZED_LINT_BIN) -glazedclilint.allow-paths=$(GLAZED_LINT_ALLOW_PATHS) ./cmd/... ./pkg/...
