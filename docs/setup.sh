#!/usr/bin/env bash
set -euo pipefail

cargo install --locked typst-cli@0.14.0

typst compile paper/hallmark.typ
typst compile --root . plan/hallmark-plan.typ
