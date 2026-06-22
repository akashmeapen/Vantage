package handlers

// Idempotency layer: prevents duplicate settlement of the same envelope
// Uses a unique envelope ID to ensure at-most-once processing
