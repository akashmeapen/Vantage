package envelope

import (
	"testing"
	"time"
	"vantage_backend/internal/crypto"
)

func TestVerifyEnvelopeAndVoucher(t *testing.T) {
	// 1. Generate keypairs for issuer (Merchant) and sender (Buyer)
	issuerPub, issuerPriv, err := crypto.GenerateKeyPair()
	if err != nil {
		t.Fatalf("failed to generate issuer key: %v", err)
	}

	senderPub, senderPriv, err := crypto.GenerateKeyPair()
	if err != nil {
		t.Fatalf("failed to generate sender key: %v", err)
	}

	// 2. Create Voucher
	voucher := Voucher{
		ID:        "voucher-123",
		IssuerID:  issuerPub,
		Amount:    150.75,
		Currency:  "USD",
		Status:    "minted",
		Payload:   "Gift card description",
		CreatedAt: time.Now().Add(-10 * time.Minute),
		ExpiresAt: time.Now().Add(24 * time.Hour),
	}

	// Sign the voucher
	voucherSig, err := crypto.Sign(issuerPriv, []byte(voucher.SigningData()))
	if err != nil {
		t.Fatalf("failed to sign voucher: %v", err)
	}
	voucher.Signature = voucherSig

	// 3. Wrap in Envelope
	env := Envelope{
		ID:         "envelope-999",
		Voucher:    voucher,
		SenderID:   senderPub,
		ReceiverID: "receiver-pubkey-abc",
		Timestamp:  time.Now(),
	}

	// Sign the envelope
	envelopeSig, err := crypto.Sign(senderPriv, []byte(env.SigningData()))
	if err != nil {
		t.Fatalf("failed to sign envelope: %v", err)
	}
	env.SenderSignature = envelopeSig

	// 4. Verify original envelope
	ok, err := env.Verify()
	if err != nil {
		t.Fatalf("Verify failed with error: %v", err)
	}
	if !ok {
		t.Errorf("Expected verification to pass, but failed")
	}

	// 5. Verify failed on tampered voucher amount
	tamperedEnv := env
	tamperedEnv.Voucher.Amount = 999.99
	ok, _ = tamperedEnv.Verify()
	if ok {
		t.Errorf("Expected verification to fail on tampered voucher amount")
	}

	// 6. Verify failed on tampered envelope sender signature
	tamperedEnv2 := env
	tamperedEnv2.SenderSignature = "abcd"
	ok, _ = tamperedEnv2.Verify()
	if ok {
		t.Errorf("Expected verification to fail on invalid signature hex")
	}
}

func TestValidateTimestamp(t *testing.T) {
	// Standard timestamp
	env := Envelope{
		Timestamp: time.Now(),
	}
	if err := env.ValidateTimestamp(); err != nil {
		t.Errorf("Expected current timestamp to be valid, got error: %v", err)
	}

	// Future timestamp beyond skew (e.g. +10 minutes)
	futureEnv := Envelope{
		Timestamp: time.Now().Add(10 * time.Minute),
	}
	if err := futureEnv.ValidateTimestamp(); err == nil {
		t.Errorf("Expected future timestamp to fail validation, but succeeded")
	}

	// Future timestamp within skew (e.g. +2 minutes)
	skewEnv := Envelope{
		Timestamp: time.Now().Add(2 * time.Minute),
	}
	if err := skewEnv.ValidateTimestamp(); err != nil {
		t.Errorf("Expected timestamp within 5-min skew to pass, got error: %v", err)
	}
}
