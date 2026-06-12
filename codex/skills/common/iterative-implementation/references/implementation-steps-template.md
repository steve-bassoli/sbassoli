# Implementation Queue Item Template

Use this structure for entries in:

- `/codex/output/iterative_implementation_items.txt`

```json
[
  {
    "id": "IMP-1",
    "description": "<step title and objective summary>",
    "complexity": "medium",
    "source_file": "unknown",
    "source_line_start": "unknown",
    "source_line_end": "unknown",
    "code_context": "<constraints, dependencies, prerequisites summary>",
    "target_file": "unknown",
    "risk_context": "<execution risks and dependency notes>",
    "metadata": {
      "objective": "<what this step accomplishes>",
      "context": "<full constraints, assumptions, prerequisites>",
      "implementation_details": "<exact file paths, components, commands, expected code changes>",
      "validation": "<commands/checks/manual verification + expected result>",
      "user_verification_checkpoint": "<what user should verify after completion>",
      "next_step_prompt": "<explicit question asking permission to continue>"
    }
  }
]
```

Track status in:

- `/codex/output/iterative_implementation_items_status.txt`
