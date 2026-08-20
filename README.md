# DomainLease-Linux Superproject

Public superproject for DomainLease-Linux, formerly CapSched-Linux during the
early modeling phase.

This repository pins the public project-control/model repository and public
Linux patch queue as submodules so a fresh clone resolves one reviewed
checkpoint.

## Submodules

```text
capsched/
  AI state, decisions, models, validation records, assurance maps, and design
  documents.

linux-patches/
  Upstream Linux base metadata plus the DomainLease Linux patch series
  and a recreate script.
```

## Local Working Trees

Large local working directories are intentionally not committed here:

```text
linux/
linux-upstream-base/
build/
tools/
local-host-tools/
```

The active Linux tree can be recreated from `linux-patches/`:

```sh
./linux-patches/scripts/recreate-capsched-linux-l0.sh ./linux
```

The full upstream Linux history is not vendored into this GitHub superproject.
The repositories are intentionally public. Do not commit credentials, private
keys, tokens, or private operational data. Model and prototype publication is
not evidence of F0/R11/K0 acceptance or hypervisor-grade protection.
