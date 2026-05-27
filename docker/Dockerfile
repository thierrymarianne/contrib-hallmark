# Pre-built hallmark opam toolchain.
#
# Built by .github/workflows/hallmark-deps-image.yml and consumed by the
# hallmark-check and hallmark-functional jobs in .github/workflows/sdk.yml
# via the `container:` directive. Single source of truth for the dep
# chain is lib/hallmark/scripts/opam_setup.sh, which is COPYed in below
# and executed at image-build time.
#
# Image tag is content-addressed on hashFiles(opam_setup.sh) — any edit
# to that script naturally invalidates the image tag and triggers a
# rebuild via the workflow's paths filter.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# apt prereqs:
#   opam            — package manager that drives the install
#   git, make       — used by opam build recipes
#   build-essential — gcc + ld for the OCaml compiler
#   m4              — required by camlp-streams (transitive)
#   unzip, rsync    — used by some opam package fetchers
#   ca-certificates — TLS roots for HTTPS opam repos
#   libgmp-dev      — depext of zarith (pulled in by rocq-runtime); pre-installed
#                     so opam doesn't have to apt-get it at solve time, which would
#                     fail after the apt lists cleanup below
#   pkg-config      — depext of zarith (conf-pkg-config); same reason
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      opam git make build-essential m4 unzip rsync ca-certificates \
      libgmp-dev pkg-config \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/hallmark
COPY lib/hallmark/scripts/opam_setup.sh /opt/hallmark/opam_setup.sh

# Install the hallmark switch + Rocq deps + coq-ext-lib.
#
# opam_setup.sh installs: rocq-core, rocq-stdlib, rocq-equations,
# rocq-metarocq, cmdliner, sexplib. coq-ext-lib is installed
# separately here to match sdk.yml's current behaviour (theories/Stripe/
# dune declares ExtLib as a required theories dependency, but
# opam_setup.sh intentionally doesn't list it — see hallmark-check
# step comment in sdk.yml).
#
# `opam clean -a -c -s --logs` reclaims ~hundreds of MB of build
# artefacts and download cache that aren't needed at runtime.
RUN opam init --bare --disable-sandboxing -y \
 && /opt/hallmark/opam_setup.sh \
 && eval "$(opam env --switch=hallmark --set-switch)" \
 && opam install -y coq-ext-lib \
 && opam clean -a -c -s --logs

# Consumers should `eval $(opam env --switch=hallmark --set-switch)`
# as the first command in any shell step. We do not set an ENTRYPOINT
# because GitHub Actions overrides it for `container:` jobs.
