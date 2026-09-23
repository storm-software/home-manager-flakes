# Local Mindctl Router

Home Manager installs Mindctl v0.1.5 and the matching local Laya System 1
classifier. The activation wrapper selects Mindctl by default, writes
`$XDG_CONFIG_HOME/mindctl/config.yaml`, starts Laya on `127.0.0.1:8091`, starts
Mindctl on `127.0.0.1:8080`, and routes Codex through `mindctl-auto` while
preserving ChatGPT OAuth.

The first Laya start builds the pinned sidecar image and downloads the pinned
`convaiinnovations/laya` model into
`$XDG_STATE_HOME/mindctl/laya-model-cache`. This can take several minutes.
Mindctl safely uses its configured fallback tier while the classifier is not
ready.

Activation owns the complete Mindctl YAML file. Before the first managed
write, an existing file is preserved as `config.yaml.pre-home-manager`.
Generated gateway, classifier, and encryption values live only in the private
`$XDG_STATE_HOME/mindctl/secrets.env`; repeated activations preserve them. The
Laya container receives a separate `laya.env` containing only its classifier
token.
SQLite data is stored in `$XDG_STATE_HOME/mindctl/mindctl.db`.

Use `--skip-mindctl-router` to stop Mindctl and Laya and run standalone
Headroom. Use `--weave-router` to stop Mindctl and Laya and select Weave; Weave
wins if both flags are present.

Useful checks:

```sh
systemctl --user status mindctl-router mindctl-laya weave-docker
journalctl --user -u mindctl-router -u mindctl-laya
curl --fail http://127.0.0.1:8080/readyz
curl --fail http://127.0.0.1:8091/readyz
```

No OpenAI API key is configured. Codex owns OAuth login and refresh; Mindctl
forwards the request-scoped bearer and ChatGPT account ID only to the ChatGPT
Codex backend.
