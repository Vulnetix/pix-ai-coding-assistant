---
name: manifest-edit-gate
description: Gate edits to dependency manifest files
event: message:preprocessed
---

Intercepts file write operations targeting dependency manifests and runs the Vulnetix manifest edit scan.
