package main

import (
    "log"
    "os"

    docpkg "mock-openai-server/pkg/docs"
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
    err := docpkg.AddDocToHelpSystem(hs)
    cobra.CheckErr(err)
    help_cmd.SetupCobraRootCommand(hs, rootCmd)

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
