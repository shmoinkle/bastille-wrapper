# bastille-wrapper

A robust wrapper for `bastille` designed to automate and orchestrate jail creation and configuration. It provides a structured, configuration-driven approach to jail setup, ensuring consistency across deployments.

## Purpose
This tool was built to handle the "gap" between a base `bastille` jail and a fully configured environment. It allows you to define mounts, settings, service configurations (`sysrc`), templates, copying files to the jail, and post-creation commands in a single, ordered configuration file.

## Features
- **Config-driven**: Centralized configuration via custom config files.
- **Orchestration**: Fine-grained control over execution order via `#!ORDER`.
- **Validation**: Basic sanity checks for environment prerequisites (bastille root, releases, network interfaces).
- **Automation**: Fully integrates template application, mounting, file copying, and jail-specific configuration in a single execution.
- **Service Management**: Idiomatic `sysrc` integration for service enabling/disabling within jails.
- **Extensibility**: Designed to be extended with new orchestration features via a clear configuration-based section parser.
