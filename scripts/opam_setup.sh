#!/usr/bin/env bash
set -euo pipefail

SWITCH_NAME="hallmark"
OCAML_VERSION="5.2.1"
ROCQ_VERSION="9.1.0"

if opam switch list --short | grep -q "^${SWITCH_NAME}$"; then
  echo "Switch '${SWITCH_NAME}' already exists, selecting it."
  opam switch "${SWITCH_NAME}"
else
  echo "Creating opam switch '${SWITCH_NAME}' with OCaml ${OCAML_VERSION}..."
  opam switch create "${SWITCH_NAME}" "ocaml-base-compiler.${OCAML_VERSION}"
fi

eval "$(opam env --switch=${SWITCH_NAME} --set-switch)"

echo "Adding Coq released repository..."
opam repo add coq-released https://coq.inria.fr/opam/released || true
opam update

echo "Pinning rocq-core ${ROCQ_VERSION}..."
opam pin add rocq-core "${ROCQ_VERSION}" --yes

echo "Installing dependencies..."
opam install rocq-stdlib rocq-equations rocq-metarocq cmdliner --yes

echo "Done. Activate with: eval \"\$(opam env --switch=${SWITCH_NAME} --set-switch)\""
