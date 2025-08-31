## Guide and Plan to Reorganize `openai-mock-server` for Public Release

### 1) Purpose and scope
- **Purpose**: Prepare `go-go-golems/openai-mock-server` for a clean public release with a clear structure, a single canonical entrypoint, integrated Glazed CLI patterns, and a built‑in help system loading Markdown sections.
- **Scope**: Repository inventory, duplicates/unwanted items, Glazed integration plan for `BareCommand` (Run) and the HelpSystem, and a step‑by‑step reorganization plan with a final target tree.

### 2) What we have now (quick inventory)
- **Entrypoints**: [UPDATED] Single canonical entrypoint at `cmd/openai-mock-server/main.go` (migrated from `main.go` and `cmd_main.go`; removed `cmd/XXX/main.go`).
- **Server code**: `responses_api.go`, `config.go`, `config/bot.yaml`
- **Docs (root)**: [UPDATED] Consolidated into `docs/`:
  - `docs/RESPONSES_API.md` (from `RESPONSES_API_README.md`)
  - `docs/STREAMING.md` (from `STREAMING_DEMO_README.md`)
  - `docs/AGENTS.md` (from `AGENT.md`, `AGENTS.md` removed)
  - `README.md` remains overview entry; `responses_api_research.md` pending move to `docs/research/`.
- **Docs (embedded)**: [UPDATED] `pkg/docs/doc.go`, `pkg/docs/help/*` (help topics for built-in help system)
- **Python demos/tests**: multiple `*.py` scripts plus slow streaming text assets
- **CI/Tooling**: `.github/workflows/*` (includes a duplicate `release.yml` and `release.yaml`), `.golangci.yml`, `.goreleaser.yaml`, `lefthook.yml`, `Makefile`
- **Modules**: `go.mod`, `go.sum`, `go.work`, `go.work.sum`

### 3) Findings and duplicates
- **Duplicate workflow files**: `.github/workflows/release.yml` and `.github/workflows/release.yaml` are identical (confirmed by checksum). Keep one.
- **Docs overlap**:
  - `README.md` vs `docs/GETTING_STARTED.md` (intro/quickstart)
  - `RESPONSES_API_README.md` vs `pkg/doc/help/api-responses.md`
  - `STREAMING_DEMO_README.md` vs several streaming demos
  - `AGENT.md` vs `AGENTS.md`
- **Multiple entrypoints**: Choose a single canonical entrypoint under `cmd/openai-mock-server/main.go`.
- **Workspace files**: `go.work*` unnecessary for a single-module repo and can confuse newcomers.

### 4) Glazed integration: BareCommand (Run) and HelpSystem
This is derived from `@build-first-command.md` (tutorial) and `@14-writing-help-entries.md` (help entries/how-to).

- **Command style**: Follow Glazed patterns with Cobra. Commands implement `cmds.BareCommand` (Run) and optionally `cmds.GlazeCommand` (structured output). Use compile-time interface checks per guidelines.
- **Root command**: Add a canonical `serve` command for the mock server, plus `help` integration from Glazed.
- **Help system**: Keep Markdown docs in a package (now `pkg/docs/help`) and load them with Go `embed` via an `AddDocToHelpSystem` function.

#### 4.1 Root command and HelpSystem wiring
```go
package main

import (
	"fmt"
	"os"

	"github.com/go-go-golems/glazed/pkg/cli"
	help "github.com/go-go-golems/glazed/pkg/help"
	help_cmd "github.com/go-go-golems/glazed/pkg/help/cmd"
	"github.com/spf13/cobra"

	appdoc "github.com/go-go-golems/openai-mock-server/pkg/doc" // your doc package
)

func main() {
	rootCmd := &cobra.Command{Use: "openai-mock-server", Short: "Mock OpenAI-compatible API"}

	// Load and register help system
	hs := help.NewHelpSystem()
	if err := appdoc.AddDocToHelpSystem(hs); err != nil {
		fmt.Fprintf(os.Stderr, "failed to load docs: %v\n", err)
		os.Exit(1)
	}
	help_cmd.SetupCobraRootCommand(hs, rootCmd)

	// Register commands
	serveCmd, err := NewServeCommand()
	cobra.CheckErr(err)
	cobraServeCmd, err := cli.BuildCobraCommand(serveCmd,
		cli.WithParserConfig(cli.CobraParserConfig{ShortHelpLayers: []string{"default"}, MiddlewaresFunc: cli.CobraCommandDefaultMiddlewares}),
	)
	cobra.CheckErr(err)
	rootCmd.AddCommand(cobraServeCmd)

	cobra.CheckErr(rootCmd.Execute())
}
```

- **Notes**:
  - Uses the Glazed HelpSystem and registers enhanced `help` commands.
  - Adds a `serve` command built from a Glazed command using `cli.BuildCobraCommand`.

#### 4.2 BareCommand for `serve`
```go
package main

import (
	"context"
	"fmt"
	"net/http"

	"github.com/go-go-golems/glazed/pkg/cmds"
	"github.com/go-go-golems/glazed/pkg/cmds/parameters"
	"github.com/go-go-golems/glazed/pkg/cmds/layers"
)

type ServeCommand struct { *cmds.CommandDescription }

type ServeSettings struct {
	Addr string `glazed.parameter:"addr"`
}

var _ cmds.BareCommand = &ServeCommand{}

func NewServeCommand() (*ServeCommand, error) {
	cmdDesc := cmds.NewCommandDescription(
		"serve",
		cmds.WithShort("Start the mock OpenAI server"),
		cmds.WithFlags(
			parameters.NewParameterDefinition("addr", parameters.ParameterTypeString, parameters.WithDefault(":3117"), parameters.WithHelp("listen address")),
		),
	)
	return &ServeCommand{CommandDescription: cmdDesc}, nil
}

func (c *ServeCommand) Run(ctx context.Context, pl *layers.ParsedLayers) error {
	settings := &ServeSettings{}
	if err := pl.InitializeStruct(layers.DefaultSlug, settings); err != nil { return err }

	mux := http.NewServeMux()
	// TODO: register handlers: /v1/chat/completions, /v1/models, /health, etc.
	fmt.Printf("listening on %s\n", settings.Addr)
	return http.ListenAndServe(settings.Addr, mux)
}
```

- **Why BareCommand?** Direct, human-readable control over server lifecycle output. If you also want structured output for a `status`-like command, implement `GlazeCommand` separately or use dual-mode.

#### 4.3 Built‑in help documents (embed + loader)
This follows `@14-writing-help-entries.md`:
```go
package doc

import (
	"embed"
	"github.com/go-go-golems/glazed/pkg/help"
)

//go:embed help/*
var docFS embed.FS

func AddDocToHelpSystem(hs *help.HelpSystem) error {
	return hs.LoadSectionsFromFS(docFS, "help")
}
```
- Place Markdown files with frontmatter like:
```yaml
---
Title: Mock Server Overview
Slug: overview
Short: What this server provides and how to run it
Topics:
- getting-started
IsTopLevel: true
ShowPerDefault: true
SectionType: GeneralTopic
---

Use the `serve` command to launch the server ...
```
- Add more focused topics: chat completions, responses API, configuration, streaming, etc. The existing `pkg/doc/help/*` can remain the source of truth; alternatively, maintain docs in `docs/` and copy/generate into `pkg/doc/help/` if you prefer a single-authoring location.

### 5) Target repository structure (proposed -> in progress)
```
.
├── cmd/
│   └── openai-mock-server/
│       └── main.go                  # root with help + command wiring (DONE)
├── pkg/
│   └── docs/
│       └── help/                   # embedded help sections (frontmatter md)
│   └── server/
│       ├── http/
│       │   ├── handlers.go         # /v1/chat/completions, /v1/models, /health
│       │   └── middleware.go       # CORS, logging
│       └── config/
│           ├── config.go           # types + loading
│           └── bot.yaml            # defaults
├── docs/
│   ├── GETTING_STARTED.md
│   ├── CONFIGURATION.md
│   ├── RESPONSES_API.md             # (DONE)
│   └── STREAMING.md                 # (DONE)
├── examples/                         # (DONE)
│   ├── python/
│   │   ├── responses_api_demo.py
│   │   ├── simple_streaming_demo.py
│   │   └── tmux_streaming_demo.py
│   └── streaming/
│       ├── slow_streaming_demo.py
│       └── assets/
│           ├── slow_01_start.txt
│           ├── slow_02_few_tokens.txt
│           ├── slow_03_more_tokens.txt
│           └── slow_04_final.txt
├── tests/                           # (DONE)
│   └── python/
│       ├── test_mock_server.py
│       ├── test_responses_api.py
│       └── streaming_test.py
├── .github/workflows/
│   ├── codeql-analysis.yml
│   ├── dependency-scanning.yml
│   ├── lint.yml
│   ├── push.yml
│   └── release.yml                 # single canonical release workflow
├── .golangci.yml
├── .goreleaser.yaml
├── .gitignore
├── lefthook.yml
├── Makefile
├── README.md
├── LICENSE
```

### 6) Concrete reorganization steps (checklist)
- [x] Move to single entrypoint under `cmd/openai-mock-server/main.go`; delete `cmd_main.go` and `cmd/XXX/main.go`
- [ ] Create `ServeCommand` as `BareCommand` and register via Glazed/Cobra
- [x] Wire Glazed HelpSystem, load embedded docs from `pkg/docs/help`
- [x] Split server code into `pkg/server` and `pkg/server/config`
- [x] Consolidate docs:
  - [x] `RESPONSES_API_README.md` → `docs/RESPONSES_API.md`
  - [x] `STREAMING_DEMO_README.md` → `docs/STREAMING.md`
  - [x] Merge `AGENT.md` + `AGENTS.md` → `docs/AGENTS.md`
  - [ ] Keep `README.md` short (overview + quick start + links)
  - [ ] Move research notes to `docs/research/` or `research/`
- [x] Organize Python assets: `examples/python/` and `tests/python/`
- [x] Remove one duplicate workflow file (keep only `release.yml`)
- [x] Ensure `make` targets: `build`, `lint`, `test` are up-to-date (release: pending goreleaser)

### 7) Release readiness criteria
- **Build**: `go build ./...` succeeds (DONE); `golangci-lint run` passes
- **Docs**: `README.md` concise, with links to `docs/` (DONE); in-app `help` shows top-level topics
- **CI**: No duplicate workflows; green on PRs and `main`
- **Submodules/Deps**: Either no submodules, or properly declared `.gitmodules` with clear bootstrap instructions
- **Examples**: Usable, minimal friction (requirements file for Python) (DONE)
- **Versioning**: `goreleaser` config aligns with a single binary `openai-mock-server`

### 8) Notes from the Glazed docs (implications)
- Use `parsedLayers.InitializeStruct(layers.DefaultSlug, &Settings{})` to map flags → settings. Avoid reading Cobra flags directly.
- Prefer `cli.BuildCobraCommand` (or dual mode via `cli.WithDualMode(true)`) to bridge Glazed and Cobra without manual flag wiring.
- Maintain help sections with YAML frontmatter and no top-level `#` title (the HelpSystem adds it).
- Add compile-time interface assertions like `var _ cmds.BareCommand = &ServeCommand{}` for safety.

### 9) Suggested follow-up tasks after reorg
- Add `status` and `version` commands (dual-mode example from the tutorial)
- Add optional structured logging with the Glazed logging layer (see tutorial section)
- Extend endpoints (embeddings/images) as needed and document them
- Provide a minimal Dockerfile and GitHub workflow for image publishing

---

## Appendix A — Minimal code skeletons

### A.1 Root command with HelpSystem and `serve`
```go
rootCmd := &cobra.Command{Use: "openai-mock-server", Short: "Mock OpenAI-compatible API"}

hs := help.NewHelpSystem()
_ = appdoc.AddDocToHelpSystem(hs)
help_cmd.SetupCobraRootCommand(hs, rootCmd)

serveCmd, _ := NewServeCommand()
cobraServeCmd, _ := cli.BuildCobraCommand(serveCmd)
rootCmd.AddCommand(cobraServeCmd)

_ = rootCmd.Execute()
```

### A.2 `ServeCommand` (BareCommand) skeleton
```go
type ServeCommand struct { *cmds.CommandDescription }

type ServeSettings struct { Addr string `glazed.parameter:"addr"` }

var _ cmds.BareCommand = &ServeCommand{}
```

### A.3 Embedded docs loader
```go
//go:embed help/*
var docFS embed.FS

func AddDocToHelpSystem(hs *help.HelpSystem) error {
	return hs.LoadSectionsFromFS(docFS, "help")
}
```

---

## Final deliverable
This document serves as the implementation guide and checklist to bring `openai-mock-server` to public release quality with a cohesive CLI built on Glazed and a consistent in-binary help experience.
