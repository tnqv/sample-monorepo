package main

import (
	"net/http"
	"os"

	"sample-monorepo/internal/utils"
)

func main() {
	logLevel := os.Getenv("LOG_LEVEL")
	if logLevel == "" {
		logLevel = "info"
	}
	utils.InitLogger(logLevel)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok"}`))
	})

	utils.Logger.Infof("Starting API on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		utils.Logger.Fatal(err)
	}
}
