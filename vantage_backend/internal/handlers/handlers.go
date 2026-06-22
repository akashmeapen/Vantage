package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"vantage_backend/internal/envelope"
)

// Env holds the dependencies for API handlers.
type Env struct {
	DB *sql.DB
}

type RegisterRequest struct {
	DisplayName string `json:"display_name"`
	PublicKey   string `json:"public_key"`
}

type RegisterResponse struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
	PublicKey   string `json:"public_key"`
}

// Register registers a new user display name and public key, returning the user UUID.
func (e *Env) Register(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(map[string]string{"error": "Method not allowed"})
		return
	}

	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid request body"})
		return
	}

	if req.DisplayName == "" || req.PublicKey == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "display_name and public_key are required"})
		return
	}

	var userID string
	err := e.DB.QueryRow(
		"INSERT INTO users (display_name, public_key) VALUES ($1, $2) RETURNING id",
		req.DisplayName,
		req.PublicKey,
	).Scan(&userID)

	if err != nil {
		log.Printf("Error registering user: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to register user. Public key may already exist."})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(RegisterResponse{
		ID:          userID,
		DisplayName: req.DisplayName,
		PublicKey:   req.PublicKey,
	})
}

// MintVoucher unwraps the digital envelope, verifies signatures, and saves the voucher.
func (e *Env) MintVoucher(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(map[string]string{"error": "Method not allowed"})
		return
	}

	var env envelope.Envelope
	if err := json.NewDecoder(r.Body).Decode(&env); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid request body"})
		return
	}

	// 1. Verify cryptography signatures
	if ok, err := env.Verify(); !ok || err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		errMsg := "Cryptographic verification failed"
		if err != nil {
			errMsg = fmt.Sprintf("Cryptographic verification failed: %v", err)
		}
		json.NewEncoder(w).Encode(map[string]string{"error": errMsg})
		return
	}

	// 2. Validate timestamp skew
	if err := env.ValidateTimestamp(); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	// 3. Lookup issuer's UUID in the database using their public key
	var issuerUUID string
	err := e.DB.QueryRow("SELECT id FROM users WHERE public_key = $1", env.Voucher.IssuerID).Scan(&issuerUUID)
	if err == sql.ErrNoRows {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Issuer public key is not registered"})
		return
	} else if err != nil {
		log.Printf("Error checking issuer: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Database lookup error"})
		return
	}

	// 4. Insert voucher into database
	_, err = e.DB.Exec(
		`INSERT INTO vouchers (id, issuer_id, amount, currency, status, payload, signature, created_at, expires_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		env.Voucher.ID,
		issuerUUID,
		env.Voucher.Amount,
		env.Voucher.Currency,
		env.Voucher.Status,
		env.Voucher.Payload,
		env.Voucher.Signature,
		env.Voucher.CreatedAt,
		env.Voucher.ExpiresAt,
	)

	if err != nil {
		log.Printf("Error inserting voucher: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(map[string]string{"error": "Voucher already exists or insertion failed"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{
		"id":      env.Voucher.ID,
		"status":  "minted",
		"message": "Voucher successfully minted",
	})
}

// SettlePayment processes a voucher payment envelope, verifying signatures and ensuring idempotency.
func (e *Env) SettlePayment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(map[string]string{"error": "Method not allowed"})
		return
	}

	var env envelope.Envelope
	if err := json.NewDecoder(r.Body).Decode(&env); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid request body"})
		return
	}

	// 1. Verify signatures
	if ok, err := env.Verify(); !ok || err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		errMsg := "Cryptographic verification failed"
		if err != nil {
			errMsg = fmt.Sprintf("Cryptographic verification failed: %v", err)
		}
		json.NewEncoder(w).Encode(map[string]string{"error": errMsg})
		return
	}

	// 2. Validate timestamp
	if err := env.ValidateTimestamp(); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	// 3. Check for duplicate settlement (Idempotency)
	settled, err := IsSettled(e.DB, env.ID)
	if err != nil {
		log.Printf("Error checking idempotency: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Database query error"})
		return
	}
	if settled {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusConflict) // 409 Conflict
		json.NewEncoder(w).Encode(map[string]string{"error": "This payment envelope has already been settled"})
		return
	}

	// 4. Lookup settler UUID in database (Sender of the envelope is the settler)
	var settlerUUID string
	err = e.DB.QueryRow("SELECT id FROM users WHERE public_key = $1", env.SenderID).Scan(&settlerUUID)
	if err == sql.ErrNoRows {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Settler public key is not registered"})
		return
	} else if err != nil {
		log.Printf("Error checking settler: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Database lookup error"})
		return
	}

	// 5. Ensure Voucher exists in database (dynamically register if offline minted)
	var voucherExists bool
	err = e.DB.QueryRow("SELECT EXISTS(SELECT 1 FROM vouchers WHERE id = $1)", env.Voucher.ID).Scan(&voucherExists)
	if err != nil {
		log.Printf("Error checking voucher: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Database check error"})
		return
	}

	if !voucherExists {
		var issuerUUID string
		err = e.DB.QueryRow("SELECT id FROM users WHERE public_key = $1", env.Voucher.IssuerID).Scan(&issuerUUID)
		if err == sql.ErrNoRows {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{"error": "Voucher issuer is not registered"})
			return
		} else if err != nil {
			log.Printf("Error checking issuer: %v", err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": "Database query error"})
			return
		}

		_, err = e.DB.Exec(
			`INSERT INTO vouchers (id, issuer_id, amount, currency, status, payload, signature, created_at, expires_at)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
			env.Voucher.ID,
			issuerUUID,
			env.Voucher.Amount,
			env.Voucher.Currency,
			env.Voucher.Status,
			env.Voucher.Payload,
			env.Voucher.Signature,
			env.Voucher.CreatedAt,
			env.Voucher.ExpiresAt,
		)
		if err != nil {
			log.Printf("Error inserting offline voucher: %v", err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": "Failed to register offline voucher"})
			return
		}
	}

	// 6. Record settled payment
	_, err = e.DB.Exec(
		`INSERT INTO settled_payments (voucher_id, settler_id, envelope_id)
		 VALUES ($1, $2, $3)`,
		env.Voucher.ID,
		settlerUUID,
		env.ID,
	)
	if err != nil {
		log.Printf("Error inserting settled payment: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(map[string]string{"error": "Payment already settled / unique key conflict"})
		return
	}

	// 7. Update voucher status to settled
	_, err = e.DB.Exec("UPDATE vouchers SET status = 'settled' WHERE id = $1", env.Voucher.ID)
	if err != nil {
		log.Printf("Error updating voucher status: %v", err)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"id":          env.ID,
		"voucher_id":  env.Voucher.ID,
		"status":      "settled",
		"message":     "Payment successfully settled",
	})
}
