#!/usr/bin/env bash
set -euo pipefail

cargo install --locked typst-cli@0.14.0

typst compile main.typ
