// Generate the router's BYOK encryption key with the same Tink implementation
// and dependency versions as the pinned router. Output is captured privately.
package main

import (
	"os"

	"github.com/tink-crypto/tink-go/v2/aead"
	"github.com/tink-crypto/tink-go/v2/insecurecleartextkeyset"
	"github.com/tink-crypto/tink-go/v2/keyset"
)

func main() {
	handle, err := keyset.NewHandle(aead.AES256GCMKeyTemplate())
	if err != nil {
		panic(err)
	}
	if err := insecurecleartextkeyset.Write(handle, keyset.NewJSONWriter(os.Stdout)); err != nil {
		panic(err)
	}
}
