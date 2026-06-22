package db

import (
	"database/sql"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
)

// RunMigrations reads schema.sql and executes it against the database.
func RunMigrations(db *sql.DB) error {
	schemaPath, err := findSchemaFile()
	if err != nil {
		return fmt.Errorf("RunMigrations: %w", err)
	}

	log.Printf("Loading schema from: %s", schemaPath)
	schemaBytes, err := ioutil.ReadFile(schemaPath)
	if err != nil {
		return fmt.Errorf("RunMigrations: failed to read schema file: %w", err)
	}

	log.Println("Executing database schema migrations...")
	_, err = db.Exec(string(schemaBytes))
	if err != nil {
		return fmt.Errorf("RunMigrations: failed to execute schema: %w", err)
	}

	log.Println("Database schema migrations completed successfully ✓")
	return nil
}

func findSchemaFile() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	// Traverse up to find the scripts/migrations/schema.sql
	for {
		path := filepath.Join(dir, "scripts", "migrations", "schema.sql")
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
		// Also check with vantage_backend prefix
		pathSub := filepath.Join(dir, "vantage_backend", "scripts", "migrations", "schema.sql")
		if _, err := os.Stat(pathSub); err == nil {
			return pathSub, nil
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return "", fmt.Errorf("schema.sql not found in current directory or any parent directories")
}
