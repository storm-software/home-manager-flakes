# Project Goals

The primary goals of this project are:
- To provide a flexible and declarative way to manage user environments.
- To enable reproducible and consistent setups across different machines.

## Key Features
- All AI agents should have their requests routed through weave router to ensure consistent handling and monitoring. Unless specified, Weave router should automatically determine the appropriate routing and handling for each request **(do not use the `force-model` option)**.
- Codex should be configured so that it's requests still go through Weave Router, but each request still uses the ChatGPT Pro subscription (ChatGPT OAuth token). As a result, **we should not require the OPENAI_API_KEY for Codex requests**.
