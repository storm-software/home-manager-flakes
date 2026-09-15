"""Compile the pinned source's actual eligibility function and call-site filters.

The harness supplies deployment/context fixtures in place of the full server's
database, registry and billing services. Credential validation and the provider
admission/exclusion/gateway control flow come from the patched Go source, not a
Python reimplementation. No upstream dependencies, network or credentials are used.
"""

import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def function(source, signature):
    match = re.search(r"^" + re.escape(signature) + r"[^\n]*\{\n.*?^\}", source, re.M | re.S)
    if not match:
        raise AssertionError(f"Missing Go function: {signature}")
    return match.group()


def main():
    source = Path(sys.argv[1])
    go = sys.argv[2]
    service = (source / "internal/proxy/service.go").read_text()
    credentials = (source / "internal/requestcontext/credentials.go").read_text()
    auth = (source / "internal/auth/id.go").read_text()
    enabled = function(service, "func (s *Service) enabledProvidersForRequest(")
    start = service.index("\tenabledProviders := s.enabledProvidersForRequest(ctx, providers.ProviderOpenAI, r.Header)")
    end = service.index("\t// Codex (ChatGPT) subscription passthrough:", start)
    call_site = service[start:end]
    extracted = "\n".join([
        enabled,
        function(credentials, "func CodexSubscriptionCreds("),
        function(auth, "func HasAPIKeyPrefix("),
        "func (s *Service) responseProviders(ctx context.Context, r *http.Request) map[string]struct{} {\n"
        + call_site + "return enabledProviders\n}",
    ])
    # Qualifier-only rewrites let the source compile with standard-library-only
    # fixture types. The extracted statements and their order stay intact.
    for old, new in {
        "providers.ProviderOpenAI": '"openai"',
        "providers.ProviderAnthropic": '"anthropic"',
        "requestcontext.CodexSubscriptionCreds": "CodexSubscriptionCreds",
        "auth.HasAPIKeyPrefix": "HasAPIKeyPrefix",
        "uuid.UUID": "[16]byte",
        "billing.SubscriptionOnlyFromContext": "subscriptionOnlyFromContext",
    }.items():
        extracted = extracted.replace(old, new)
    fixture = Path(sys.argv[3]) if len(sys.argv) > 3 else Path(__file__).with_name("weave-codex-routing-fixture.go")
    harness = fixture.read_text()
    with tempfile.TemporaryDirectory(prefix="weave-routing-test-") as directory:
        path = Path(directory) / "routing_test.go"
        path.write_text(harness + "\n" + extracted)
        result = subprocess.run(
            [go, "test", "-v", str(path)],
            env={"PATH": os.environ["PATH"], "HOME": directory,
                 "GOCACHE": directory + "/cache", "GOPATH": directory + "/go",
                 "GOENV": "off", "GOTOOLCHAIN": "local", "GOPROXY": "off", "CGO_ENABLED": "0"},
            text=True,
        )
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
