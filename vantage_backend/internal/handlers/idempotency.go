package handlers

import (
	"database/sql"
	"errors"
)

var ErrAlreadySettled = errors.New("payment has already been settled")

// IsSettled checks if an envelope ID already exists in the settled_payments table.
func IsSettled(db *sql.DB, envelopeID string) (bool, error) {
	var exists bool
	err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM settled_payments WHERE envelope_id = $1)", envelopeID).Scan(&exists)
	if err != nil {
		return false, err
	}
	return exists, nil
}
