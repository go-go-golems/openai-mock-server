package main

import (
    "fmt"
    "log"
    "os"
    "sort"

    docpkg "mock-openai-server/pkg/doc"
    server "mock-openai-server/pkg/server"
    cfg "mock-openai-server/pkg/server/config"
    "github.com/spf13/cobra"
    glaze_help "github.com/go-go-golems/glazed/pkg/help"
    help_cmd "github.com/go-go-golems/glazed/pkg/help/cmd"
    glazed_logging "github.com/go-go-golems/glazed/pkg/cmds/logging"
    "github.com/spf13/viper"
)

func main() {
    rootCmd := &cobra.Command{
        Use:   "openai-mock-server",
        Short: "Mock OpenAI-compatible API server",
        PersistentPreRun: func(cmd *cobra.Command, args []string) {
            cfg.LoadConfigFromEnv()
            _ = glazed_logging.InitLoggerFromViper()
        },
    }
    _ = glazed_logging.AddLoggingLayerToRootCommand(rootCmd, "openai-mock-server")
    _ = viper.BindPFlags(rootCmd.PersistentFlags())

    // Wire Glazed help system
    hs := glaze_help.NewHelpSystem()
    _ = docpkg.AddDocToHelpSystem(hs)
    help_cmd.SetupCobraRootCommand(hs, rootCmd)

    helpCmd := &cobra.Command{
        Use:   "help",
        Short: "Show built-in documentation",
        RunE: func(cmd *cobra.Command, args []string) error {
            _ = docpkg.LoadHelpSections()
            all, _ := cmd.Flags().GetBool("all")
            if all {
                slugs := make([]string, 0, len(docpkg.ListSections()))
                for k := range docpkg.ListSections() { slugs = append(slugs, k) }
                sort.Strings(slugs)
                for _, slug := range slugs {
                    sec, _ := docpkg.GetSection(slug)
                    fmt.Printf("# %s\n\n", sec.Title)
                    if sec.Short != "" { fmt.Printf("%s\n\n", sec.Short) }
                    fmt.Println(sec.Content)
                    fmt.Println()
                }
                return nil
            }
            fmt.Println("Available help topics:")
            for slug, sec := range docpkg.ListSections() {
                fmt.Printf("- %s: %s\n", slug, sec.Title)
            }
            return nil
        },
    }
    helpCmd.Flags().BoolP("all", "a", false, "Print all documentation pages")
    rootCmd.AddCommand(helpCmd)

    serveCmd := &cobra.Command{
        Use:   "serve",
        Short: "Start the mock server",
        RunE: func(cmd *cobra.Command, args []string) error {
            return server.StartHTTPServer()
        },
    }
    rootCmd.AddCommand(serveCmd)

    // Default to serve when no subcommand provided
    if len(os.Args) == 1 {
        if err := server.StartHTTPServer(); err != nil { log.Fatal(err) }
        return
    }

    if err := rootCmd.Execute(); err != nil {
        log.Fatal(err)
    }
}
