package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strconv"
	"strings"
	"time"
)

// verifySignature checks the Stripe-Signature header against the webhook secret.
// This avoids pulling in the full stripe-go dependency just for signature verification.
// Tolerance is set to 5 minutes (Stripe's default).
const signatureTolerance = 5 * time.Minute

func verifySignature(payload []byte, sigHeader, secret string) error {
	pairs := parseSignatureHeader(sigHeader)

	tsStr, ok := pairs["t"]
	if !ok {
		return fmt.Errorf("missing timestamp in signature header")
	}
	ts, err := strconv.ParseInt(tsStr, 10, 64)
	if err != nil {
		return fmt.Errorf("invalid timestamp: %w", err)
	}

	// Check timestamp tolerance.
	eventTime := time.Unix(ts, 0)
	if time.Since(eventTime) > signatureTolerance {
		return fmt.Errorf("timestamp too old: %v", eventTime)
	}

	// Stripe uses v1 signatures.
	expectedSig, ok := pairs["v1"]
	if !ok {
		return fmt.Errorf("missing v1 signature")
	}

	// Compute expected signature: HMAC-SHA256 of "timestamp.payload".
	signedPayload := fmt.Sprintf("%d.%s", ts, string(payload))
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(signedPayload))
	computed := hex.EncodeToString(mac.Sum(nil))

	if !hmac.Equal([]byte(computed), []byte(expectedSig)) {
		return fmt.Errorf("signature mismatch")
	}

	return nil
}

func parseSignatureHeader(header string) map[string]string {
	result := make(map[string]string)
	parts := strings.Split(header, ",")
	for _, part := range parts {
		kv := strings.SplitN(strings.TrimSpace(part), "=", 2)
		if len(kv) == 2 {
			result[kv[0]] = kv[1]
		}
	}
	return result
}
