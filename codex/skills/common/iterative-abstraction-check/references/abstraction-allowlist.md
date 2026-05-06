# Abstraction Allowlist
#
# Format:
# - One rule per non-empty line.
# - Supported prefixes:
#   - regex:<regular-expression>
#   - literal:<exact text>
# - Lines beginning with "#" are ignored.
#
# Keep rules narrow and always include a one-line reason comment above each rule.

# Example:
# Shared assignment action helper is intentionally repeated until extraction ticket WF-1234 lands.
# regex:TaskService\.buildAssigneeRequest\(event\?\.updateIds\[0\]

