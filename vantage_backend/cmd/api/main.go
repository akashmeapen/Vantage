package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"vantage_backend/internal/db"

	"github.com/joho/godotenv"
)

func main() {
	// ── Load .env file (if present) ──────────────────────────────
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, reading from system environment")
	}

	// ── Load configuration from environment ──────────────────────
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("FATAL: DATABASE_URL environment variable is not set")
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// ── Establish database connection ────────────────────────────
	log.Println("Connecting to database...")
	database, err := db.Connect(databaseURL)
	if err != nil {
		log.Fatalf("FATAL: Could not connect to database: %v", err)
	}
	defer database.Close()
	log.Println("Database connected successfully ✓")

	// ── Register routes ──────────────────────────────────────────
	mux := http.NewServeMux()

	// Health check — verifies the server is up and DB is reachable.
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		dbStatus := "connected"
		if err := database.Ping(); err != nil {
			dbStatus = "disconnected"
			w.WriteHeader(http.StatusServiceUnavailable)
			json.NewEncoder(w).Encode(map[string]string{
				"status":   "unhealthy",
				"database": dbStatus,
				"error":    err.Error(),
			})
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{
			"status":   "healthy",
			"database": dbStatus,
		})
	})

	// ── Start server ─────────────────────────────────────────────
	log.Printf("Vantage Backend starting on port :%s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatalf("FATAL: Server failed to start: %v", err)
	}
}
