package crypto

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"fmt"
)

// GenerateKeyPair generates a new Ed25519 private key (seed + public key) and public key.
// Returns hex-encoded representations of both.
func GenerateKeyPair() (string, string, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return "", "", fmt.Errorf("crypto.GenerateKeyPair: %w", err)
	}
	return hex.EncodeToString(pub), hex.EncodeToString(priv), nil
}

// Sign signs a message using a hex-encoded private key (64-byte or 32-byte seed).
// Returns a hex-encoded signature.
func Sign(privateKeyHex string, message []byte) (string, error) {
	privBytes, err := hex.DecodeString(privateKeyHex)
	if err != nil {
		return "", fmt.Errorf("crypto.Sign: invalid private key hex: %w", err)
	}

	var priv ed25519.PrivateKey
	if len(privBytes) == ed25519.PrivateKeySize { // 64 bytes
		priv = ed25519.PrivateKey(privBytes)
	} else if len(privBytes) == 32 { // 32-byte seed
		priv = ed25519.NewKeyFromSeed(privBytes)
	} else {
		return "", fmt.Errorf("crypto.Sign: invalid private key size: expected 32 or 64 bytes, got %d", len(privBytes))
	}

	sig := ed25519.Sign(priv, message)
	return hex.EncodeToString(sig), nil
}

// Verify verifies a hex-encoded signature against a message and a hex-encoded public key.
func Verify(publicKeyHex string, message []byte, signatureHex string) (bool, error) {
	pubBytes, err := hex.DecodeString(publicKeyHex)
	if err != nil {
		return false, fmt.Errorf("crypto.Verify: invalid public key hex: %w", err)
	}

	if len(pubBytes) != ed25519.PublicKeySize { // 32 bytes
		return false, fmt.Errorf("crypto.Verify: invalid public key size: expected %d, got %d", ed25519.PublicKeySize, len(pubBytes))
	}

	sigBytes, err := hex.DecodeString(signatureHex)
	if err != nil {
		return false, fmt.Errorf("crypto.Verify: invalid signature hex: %w", err)
	}

	if len(sigBytes) != ed25519.SignatureSize { // 64 bytes
		return false, fmt.Errorf("crypto.Verify: invalid signature size: expected %d, got %d", ed25519.SignatureSize, len(sigBytes))
	}

	pub := ed25519.PublicKey(pubBytes)
	isValid := ed25519.Verify(pub, message, sigBytes)
	return isValid, nil
}
