# ROADMAP

## Current Status
- Transitioned to standalone `bastille-wrapper` identity.
- Modernized configuration processing with `SYSRC`.
- Added dynamic configuration support in plan.

## Planned Features

### Order of Operations
- Add the ability to specify the execution order for configuration sections (e.g., applying templates before mounts or CMDs).
- *Consideration*: Support line-level prefixing (e.g., `#!M` for mount, `#!S` for setting) to allow arbitrary interleaving of operations in the configuration file.

### Dynamic Configuration (`#!ARG`)
- Allow host-side command execution to populate variables for use in `CMD` or `SETTINGS`.
- *Example*: `#!ARG` -> `newuser=$(whoami)` then in `CMD` use `pw useradd $newuser`.

### Enhanced Validation
- Improve mount path existence checks.
- Add input sanitization for jail names and network parameters.

### Robust Mount Handling
- Improve error handling for complex paths, specifically those containing spaces or non-standard characters.
- Better validation of host/jail directory mappings before attempting mount operations.

### Future Orchestration
- Support for more `bastille` commands, allowing for more comprehensive jail lifecycle management directly through the wrapper.
