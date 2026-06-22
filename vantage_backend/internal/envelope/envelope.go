package envelope

import (
	"fmt"
	"strconv"
	"strings"
	"time"
	"vantage_backend/internal/crypto"
)

type Voucher struct {
	ID        string    `json:"id"`
	IssuerID  string    `json:"issuer_id"`
	Amount    float64   `json:"amount"`
	Currency  string    `json:"currency"`
	Status    string    `json:"status"`
	Payload   string    `json:"payload"`
	CreatedAt time.Time `json:"created_at"`
	ExpiresAt time.Time `json:"expires_at"`
	Signature string    `json:"signature"`
}

type Envelope struct {
	ID              string    `json:"id"`
	Voucher         Voucher   `json:"voucher"`
	SenderID        string    `json:"sender_id"`
	ReceiverID      string    `json:"receiver_id"`
	Timestamp       time.Time `json:"timestamp"`
	SenderSignature string    `json:"sender_signature"`
}

// formatDouble formats a float to match Dart's double.toString() behavior.
func formatDouble(val float64) string {
	s := strconv.FormatFloat(val, 'f', -1, 64)
	if !strings.Contains(s, ".") {
		s = s + ".0"
	}
	return s
}

// formatTime formats a time to match Dart's DateTime.toIso8601String() UTC output.
func formatTime(t time.Time) string {
	return t.UTC().Format("2006-01-02T15:04:05.000Z")
}

// SigningData for Voucher: "$id|$issuerId|$amount|$currency|$status|$payload|${createdAt.toIso8601String()}|${expiresAt.toIso8601String()}"
func (v *Voucher) SigningData() string {
	return fmt.Sprintf("%s|%s|%s|%s|%s|%s|%s|%s", v.ID, v.IssuerID, formatDouble(v.Amount), v.Currency, v.Status, v.Payload, formatTime(v.CreatedAt), formatTime(v.ExpiresAt))
}

// SigningData for Envelope: "$id|${voucher.id}|$senderId|$receiverId|${timestamp.toIso8601String()}"
func (e *Envelope) SigningData() string {
	return fmt.Sprintf("%s|%s|%s|%s|%s", e.ID, e.Voucher.ID, e.SenderID, e.ReceiverID, formatTime(e.Timestamp))
}

// Verify verifies the cryptographic signatures of both the envelope (by the sender)
// and the nested voucher (by the issuer).
func (e *Envelope) Verify() (bool, error) {
	// 1. Verify Voucher Signature (by Issuer)
	voucherMsg := e.Voucher.SigningData()
	voucherOk, err := crypto.Verify(e.Voucher.IssuerID, []byte(voucherMsg), e.Voucher.Signature)
	if err != nil {
		return false, fmt.Errorf("failed to verify voucher: %w", err)
	}
	if !voucherOk {
		return false, fmt.Errorf("invalid voucher signature")
	}

	// 2. Verify Envelope Signature (by Sender)
	envelopeMsg := e.SigningData()
	envelopeOk, err := crypto.Verify(e.SenderID, []byte(envelopeMsg), e.SenderSignature)
	if err != nil {
		return false, fmt.Errorf("failed to verify envelope: %w", err)
	}
	if !envelopeOk {
		return false, fmt.Errorf("invalid envelope signature")
	}

	return true, nil
}

// ValidateTimestamp checks if the envelope timestamp is in the future.
// It allows a small clock skew window (e.g. 5 minutes).
func (e *Envelope) ValidateTimestamp() error {
	skew := 5 * time.Minute
	if e.Timestamp.After(time.Now().Add(skew)) {
		return fmt.Errorf("envelope timestamp is too far in the future")
	}
	return nil
}
