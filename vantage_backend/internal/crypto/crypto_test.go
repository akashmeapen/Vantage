package crypto

import (
	"encoding/hex"
	"testing"
)

func TestGenerateKeyPair(t *testing.T) {
	pub, priv, err := GenerateKeyPair()
	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}

	if len(pub) != 64 { // hex string of 32 bytes public key
		t.Errorf("Expected public key length 64, got %d", len(pub))
	}

	if len(priv) != 128 { // hex string of 64 bytes private key (seed + public key)
		t.Errorf("Expected private key length 128, got %d", len(priv))
	}
}

func TestSignAndVerify(t *testing.T) {
	pub, priv, err := GenerateKeyPair()
	if err != nil {
		t.Fatalf("GenerateKeyPair failed: %v", err)
	}

	message := []byte("vantage-test-message-123")

	// Sign the message
	sig, err := Sign(priv, message)
	if err != nil {
		t.Fatalf("Sign failed: %v", err)
	}

	// Verify the signature
	valid, err := Verify(pub, message, sig)
	if err != nil {
		t.Fatalf("Verify failed: %v", err)
	}
	if !valid {
		t.Errorf("Expected signature to be valid, but was invalid")
	}

	// Verify with wrong message
	wrongMessage := []byte("vantage-test-message-456")
	validWrongMsg, err := Verify(pub, wrongMessage, sig)
	if err != nil {
		t.Fatalf("Verify failed on wrong message: %v", err)
	}
	if validWrongMsg {
		t.Errorf("Expected signature to be invalid for modified message, but was valid")
	}

	// Verify with tampered signature
	sigBytes, _ := hex.DecodeString(sig)
	sigBytes[0] ^= 0xFF // tamper first byte
	tamperedSig := hex.EncodeToString(sigBytes)

	validWrongSig, err := Verify(pub, message, tamperedSig)
	if err != nil {
		t.Fatalf("Verify failed on tampered signature: %v", err)
	}
	if validWrongSig {
		t.Errorf("Expected signature to be invalid for tampered signature, but was valid")
	}
}
