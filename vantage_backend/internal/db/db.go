package db

import (
	"database/sql"
	"fmt"
	"time"

	// PostgreSQL driver — imported for side-effect registration.
	_ "github.com/lib/pq"
)

// Connect opens a PostgreSQL connection using the provided DSN,
// configures pool settings, and verifies the connection with a ping.
func Connect(databaseURL string) (*sql.DB, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("db.Connect: failed to open connection: %w", err)
	}

	// Connection pool tuning — sensible defaults for a lightweight backend.
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	// Verify that the database is actually reachable.
	if err := db.Ping(); err != nil {
		db.Close()
		return nil, fmt.Errorf("db.Connect: failed to ping database: %w", err)
	}

	return db, nil
}
