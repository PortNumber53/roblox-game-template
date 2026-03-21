package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

// Config holds the application configuration.
type Config struct {
	Port                string            `json:"port"`
	StripeWebhookSecret string            `json:"stripe_webhook_secret"`
	Routes              map[string]string `json:"routes"` // saas_id -> upstream webhook URL
}

// StripeEventMinimal is the minimal structure needed to extract metadata for routing.
// We only parse what we need — the full raw body is forwarded upstream.
type StripeEventMinimal struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

type StripeEventData struct {
	Object json.RawMessage `json:"object"`
}

type StripeObject struct {
	Metadata map[string]string `json:"metadata"`
	// Some event types nest metadata under sub-objects (e.g. invoice -> subscription -> metadata).
	// We check common locations.
	Customer     *StripeObjectRef `json:"customer,omitempty"`
	Subscription *StripeObjectRef `json:"subscription,omitempty"`
}

type StripeObjectRef struct {
	Metadata map[string]string `json:"metadata,omitempty"`
}

func loadConfig(path string) (*Config, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("open config: %w", err)
	}
	defer f.Close()

	var cfg Config
	if err := json.NewDecoder(f).Decode(&cfg); err != nil {
		return nil, fmt.Errorf("decode config: %w", err)
	}

	if cfg.Port == "" {
		cfg.Port = "8080"
	}
	if len(cfg.Routes) == 0 {
		return nil, fmt.Errorf("no routes configured")
	}
	return &cfg, nil
}

// extractSaaSID tries to find the saas_id from the event's metadata.
func extractSaaSID(body []byte) (string, error) {
	var event StripeEventMinimal
	if err := json.Unmarshal(body, &event); err != nil {
		return "", fmt.Errorf("unmarshal event: %w", err)
	}

	var data StripeEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return "", fmt.Errorf("unmarshal event data: %w", err)
	}

	var obj StripeObject
	if err := json.Unmarshal(data.Object, &obj); err != nil {
		return "", fmt.Errorf("unmarshal event object: %w", err)
	}

	// Check top-level metadata first.
	if id, ok := obj.Metadata["saas_id"]; ok && id != "" {
		return id, nil
	}

	// Fallback: check nested subscription metadata.
	if obj.Subscription != nil {
		if id, ok := obj.Subscription.Metadata["saas_id"]; ok && id != "" {
			return id, nil
		}
	}

	// Fallback: check nested customer metadata.
	if obj.Customer != nil {
		if id, ok := obj.Customer.Metadata["saas_id"]; ok && id != "" {
			return id, nil
		}
	}

	return "", fmt.Errorf("no saas_id found in event metadata")
}

func main() {
	configPath := os.Getenv("CONFIG_PATH")
	if configPath == "" {
		configPath = "config.json"
	}

	cfg, err := loadConfig(configPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	log.Printf("Loaded %d route(s):", len(cfg.Routes))
	for saasID, url := range cfg.Routes {
		log.Printf("  %s -> %s", saasID, url)
	}

	httpClient := &http.Client{Timeout: 30 * time.Second}

	http.HandleFunc("/webhook/stripe", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20)) // 1 MB max
		if err != nil {
			log.Printf("ERROR: reading body: %v", err)
			http.Error(w, "failed to read body", http.StatusBadRequest)
			return
		}
		defer r.Body.Close()

		// Verify Stripe signature if secret is configured.
		if cfg.StripeWebhookSecret != "" {
			sigHeader := r.Header.Get("Stripe-Signature")
			if sigHeader == "" {
				log.Printf("WARN: missing Stripe-Signature header")
				http.Error(w, "missing signature", http.StatusBadRequest)
				return
			}
			if err := verifySignature(body, sigHeader, cfg.StripeWebhookSecret); err != nil {
				log.Printf("WARN: invalid signature: %v", err)
				http.Error(w, "invalid signature", http.StatusUnauthorized)
				return
			}
		}

		saasID, err := extractSaaSID(body)
		if err != nil {
			log.Printf("WARN: %v", err)
			http.Error(w, "unable to determine routing: "+err.Error(), http.StatusBadRequest)
			return
		}

		upstreamURL, ok := cfg.Routes[saasID]
		if !ok {
			log.Printf("WARN: no route for saas_id=%q", saasID)
			http.Error(w, fmt.Sprintf("no route configured for saas_id: %s", saasID), http.StatusNotFound)
			return
		}

		log.Printf("Routing event to saas_id=%q -> %s", saasID, upstreamURL)

		// Forward the original request body and relevant headers to the upstream service.
		proxyReq, err := http.NewRequestWithContext(r.Context(), http.MethodPost, upstreamURL, bytes.NewReader(body))
		if err != nil {
			log.Printf("ERROR: creating proxy request: %v", err)
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		proxyReq.Header.Set("Content-Type", "application/json")
		// Forward the Stripe signature so upstream can re-verify if needed.
		if sig := r.Header.Get("Stripe-Signature"); sig != "" {
			proxyReq.Header.Set("Stripe-Signature", sig)
		}

		resp, err := httpClient.Do(proxyReq)
		if err != nil {
			log.Printf("ERROR: forwarding to %s: %v", upstreamURL, err)
			http.Error(w, "upstream error", http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()

		// Forward the upstream response back to Stripe.
		respBody, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
		if err != nil {
			log.Printf("ERROR: reading upstream response: %v", err)
			http.Error(w, "upstream read error", http.StatusBadGateway)
			return
		}

		for _, h := range []string{"Content-Type"} {
			if v := resp.Header.Get(h); v != "" {
				w.Header().Set(h, v)
			}
		}
		w.WriteHeader(resp.StatusCode)
		w.Write(respBody)

		log.Printf("Completed: saas_id=%q status=%d", saasID, resp.StatusCode)
	})

	// Health check endpoint.
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok"}`))
	})

	addr := ":" + cfg.Port
	log.Printf("Stripe webhook router listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}

