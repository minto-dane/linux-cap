# DomainLease-Linux Superproject

Private superproject for DomainLease-Linux, formerly CapSched-Linux during the
private modeling phase.

This repository ties together the private project-control/model repository and
the private Linux patch queue.

## Submodules

```text
capsched/
  AI state, decisions, models, validation records, assurance maps, and design
  documents.

linux-patches/
  Upstream Linux base metadata plus the private DomainLease Linux patch series
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

The full public Linux history is not vendored into this private GitHub
superproject. The private content is the DomainLease state/model work and the
DomainLease Linux patch queue.
