APP=openai-mock-server
MOCK_SERVER_CONFIG ?= pkg/server/config/bot.yaml

.PHONY: help fmt vet build run test test-chat test-responses test-stream clean docs lint lintmax docker-lint gosec govulncheck tag-major tag-minor tag-patch release goreleaser

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
	@echo "  make tag-patch     - create a patch tag with svu"
	@echo "  make tag-minor     - create a minor tag with svu"
	@echo "  make tag-major     - create a major tag with svu"
	@echo "  make release       - push tags (requires remote)"

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

tag-major:
	git tag $(shell svu major)

tag-minor:
	git tag $(shell svu minor)

tag-patch:
	git tag $(shell svu patch)

release:
	git push --tags
	- GOPROXY=proxy.golang.org go list -m github.com/go-go-golems/openai-mock-server@$(shell svu current)

goreleaser:
	goreleaser release --skip=sign --snapshot --clean

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
