// Test-only adapters for isolated execution of pinned routing source.
package proxy

import (
	"context"
	"net/http"
	"reflect"
	"strings"
	"testing"
)

type Credentials struct {
	APIKey, AccountID []byte
	Source            string
	OAuth             bool
}

const SourceCodexSubscription = "codex_subscription"
const APIKeyPrefix = "rk"
const AnalyticsAPIKeyPrefix = "ra"

type clients map[string]struct{}

func (c clients) Len() int                     { return len(c) }
func (c clients) NameSet() map[string]struct{} { return c }

type Service struct {
	clients                      clients
	byokOnly                     bool
	deploymentKeyedProviders     map[string]struct{}
	passthroughEligibleProviders map[string]struct{}
	excluded, gateways           map[string]struct{}
}

func (s *Service) excludedProvidersForRequest(context.Context) map[string]struct{} { return s.excluded }
func (s *Service) gatewayProvidersForRequest(context.Context) map[string]struct{}  { return s.gateways }

type externalKey struct {
	Plaintext []byte
	Provider  string
}

func externalKeysFromContext(context.Context) []externalKey     { return nil }
func anthropicSubscriptionFromContext(context.Context) string   { return "" }
func subscriptionCredsFromHeaderValue(string) *Credentials      { return nil }
func codexSubscriptionFromContext(context.Context) *Credentials { return nil }

// The fixture uses a router-authenticated request whose transient subscription
// context was removed, so only the header pair can enroll OpenAI.
func installationIDFromContext(context.Context) [16]byte { return [16]byte{1} }
func subscriptionOnlyFromContext(context.Context) bool   { return false }
func restrictToSubscriptionProviders(_ context.Context, _ http.Header, enabled map[string]struct{}) map[string]struct{} {
	return enabled
}
func ExtractClientCredentials(provider string, h http.Header) *Credentials {
	if provider != "openai" {
		return nil
	}
	raw, ok := strings.CutPrefix(h.Get("Authorization"), "Bearer ")
	if !ok {
		return nil
	}
	return CodexSubscriptionCreds(raw, h.Get("ChatGPT-Account-ID"))
}

func set(names ...string) map[string]struct{} {
	out := make(map[string]struct{}, len(names))
	for _, name := range names {
		out[name] = struct{}{}
	}
	return out
}

func TestCodexOAuthPolicy(t *testing.T) {
	for _, tc := range []struct {
		name, token, account     string
		excluded, gateways, want map[string]struct{}
	}{
		{"ordinary OAuth retains other providers", "fixture.oauth.token", "fixture-account", nil, nil, set("openai", "anthropic")},
		{"excluded OpenAI stays excluded", "fixture.oauth.token", "fixture-account", set("openai"), nil, set("anthropic")},
		{"gateway only stays exclusive", "fixture.oauth.token", "fixture-account", nil, set("gateway"), set("gateway")},
		{"gateway policy still wins with exclusions", "fixture.oauth.token", "fixture-account", set("openai"), set("gateway"), set("gateway")},
		{"missing account does not enroll OpenAI", "fixture.oauth.token", "", nil, nil, set("anthropic")},
		{"empty token does not enroll OpenAI", "", "fixture-account", nil, nil, set("anthropic")},
		{"API key does not become OAuth", "sk-fixture", "fixture-account", nil, nil, set("anthropic")},
		{"router key does not become OAuth", "rk_fixture", "fixture-account", nil, nil, set("anthropic")},
		{"analytics key does not become OAuth", "ra_fixture", "fixture-account", nil, nil, set("anthropic")},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s := &Service{clients: clients{"anthropic": {}}, excluded: tc.excluded, gateways: tc.gateways}
			r, err := http.NewRequest("POST", "http://fixture.invalid/v1/responses", nil)
			if err != nil {
				t.Fatal(err)
			}
			r.Header.Set("Authorization", "Bearer "+tc.token)
			r.Header.Set("ChatGPT-Account-ID", tc.account)
			for attempt := 0; attempt < 2; attempt++ {
				got := s.responseProviders(context.Background(), r)
				if !reflect.DeepEqual(got, tc.want) {
					t.Fatalf("providers = %v, want %v", got, tc.want)
				}
			}
		})
	}
}
