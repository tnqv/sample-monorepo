package main

import (
	"os"
	"time"

	"sample-monorepo/internal/utils"
)

func main() {
	logLevel := os.Getenv("LOG_LEVEL")
	if logLevel == "" {
		logLevel = "info"
	}
	utils.InitLogger(logLevel)

	intervalStr := os.Getenv("WORKER_INTERVAL")
	interval, err := time.ParseDuration(intervalStr)
	if err != nil {
		interval = 10 * time.Second
	}

	secret := os.Getenv("SECRET_KEY")
	if secret == "" {
		utils.Logger.Warn("SECRET_KEY not set, using default")
		secret = "default-secret"
	}

	utils.Logger.Info("Starting worker with interval ", interval, " and secret ", secret)
	for {
		utils.Logger.Info("Processing background task with secret: ", secret)
		time.Sleep(interval)
	}
}
