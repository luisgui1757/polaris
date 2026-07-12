# Sentinel Adapter Rules

Tool-specific instruction files are adapters, not independent policy sources.

By default, adapters **inline** the rendered Sentinel contract into each tool's
native auto-loaded entrypoint, so the rules reach the model at startup with no
tool call and no slash command. Pointing at a separate file is a fallback only
where a tool reliably expands file references; most do not. Adapters must not
fork policy.

Generated adapters carry a content hash, and repositories verify them (drift
check) so a change in core cannot silently fall out of sync with what tools
actually load.
