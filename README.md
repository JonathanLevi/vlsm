# VLSM

A validating labelled state transition and message production system
(VLSM) abstractly models a distributed system with faults. This project
contains a formalization of VLSMs and their theory in the Coq proof assistant.

## Meta

- License: [BSD 3-Clause "New" or "Revised" License](LICENSE.md)
- Compatible Coq versions: 8.13
- Additional dependencies:
  - [Coq-std++](https://gitlab.mpi-sws.org/iris/stdpp/) 1.5.0
- Coq namespace: `VLSM`

## Building instructions

The project is compatible with the 2021.09 package pick for Coq 8.13 of
[Coq Platform release 2021.09.0](https://github.com/coq/platform/releases/tag/2021.09.0),
so you can obtain all dependencies by installing that Coq Platform variant.

The simplest way of working with this project without needing to install anything is doing so online, by clicking here:
[![Open in Papillon](https://papillon.expert/github-badge.svg)](https://papillon.expert/projects/github/runtimeverification/vlsm/master)

To instead install dependencies manually via [opam](https://opam.ocaml.org/doc/Install.html), do:

```shell
opam repo add coq-released https://coq.inria.fr/opam/released
opam install coq.8.13.2 coq-stdpp.1.5.0
```

To build the project when you have all dependencies installed, do:

```shell
git clone https://github.com/runtimeverification/vlsm.git
cd vlsm
make   # or make -j <number-of-cores-on-your-machine>
```

## Coq file organization

- `theories/VLSM/Lib`: Various extensions to the Coq standard library and Coq-std++.
- `theories/VLSM/Core`: Core VLSM definitions and theory.

## Documentation

- [latest coqdoc presentation of the Coq files](https://runtimeverification.github.io/vlsm-docs/latest/coqdoc/toc.html)
- [latest Alectryon presentation the Coq files](https://runtimeverification.github.io/vlsm-docs/latest/alectryon/toc.html)
