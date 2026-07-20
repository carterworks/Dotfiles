# Research Notes And Sources

This reference records the primary sources behind the skill. It was researched on 2026-07-20. Blog code is historical unless confirmed against the project's pinned versions and current upstream documentation.

## How To Weigh The Sources

- Use current Nix, Nixpkgs, NixOS, nix-darwin, Home Manager, and dependency documentation for exact interfaces.
- Use practitioner writing for architecture, workflow, tradeoffs, and failure modes.
- Prefer principles repeated across independent authors.
- Preserve disagreements. Flakes and flake frameworks do not have one community-wide consensus.

## Prominent Practitioners

### Eelco Dolstra

Nix's creator and the original flakes implementer. The three-part Tweag series establishes explicit inputs, standard outputs, pure evaluation, lock files, `nixosConfigurations`, reusable modules, checks, and clean-revision deployments. Its 2020 syntax is dated.

- [Nix Flakes, Part 1: An introduction and tutorial](https://www.tweag.io/blog/2020-05-25-flakes/), 2020-05-25
- [Nix Flakes, Part 2: Evaluation caching](https://www.tweag.io/blog/2020-06-25-eval-cache/), 2020-06-25
- [Nix Flakes, Part 3: Managing NixOS systems](https://www.tweag.io/blog/2020-07-31-nixos-flakes/), 2020-07-31

### Xe Iaso

Xe's complete seven-post flake series is a prominent practical introduction to standard outputs, dev shells, packages, reusable NixOS modules, containers, and application deployment. The module article motivates namespaced typed options, `mkIf`, hardened systemd services, and testing modules in a system. Some examples use old package names, output forms, releases, and ecosystem APIs.

- [Nix flakes series](https://xeiaso.net/blog/series/nix-flakes/), 2022
- [Nix Flakes: an Introduction](https://xeiaso.net/blog/nix-flakes-1-2022-02-21/), 2022-02-21
- [Nix Flakes: Packages and How to Use Them](https://xeiaso.net/blog/nix-flakes-2-2022-02-27/), 2022-02-27
- [Nix Flakes: Exposing and using NixOS Modules](https://xeiaso.net/blog/nix-flakes-3-2022-04-07/), 2022-04-07
- [Nix Flakes on WSL](https://xeiaso.net/blog/nix-flakes-4-wsl-2022-05-01/), 2022-05-01
- [How to look up a Nix package's store path from flake inputs](https://xeiaso.net/blog/nix-flakes-look-up-package/), 2022-08-06
- [NixOS machines, Terraform, and Tailscale](https://xeiaso.net/blog/nix-flakes-terraform/), 2022-12-07
- [Building Go programs with Nix Flakes](https://xeiaso.net/blog/nix-flakes-go-programs/), 2022-12-14

### Graham Christensen

Long-time NixOS contributor and Determinate Systems co-founder. His writing supports flakes as an interchange format while documenting governance concerns, and frames system quality in operational terms: explicitly managed state, rebuildability, VM tests, deployment observability, and repeatedly exercised recovery.

- [Erase your darlings](https://grahamc.com/blog/erase-your-darlings/), 2020-04-13
- [Flakes are such an obviously good thing](https://grahamc.com/blog/flakes-are-an-obviously-good-thing/), 2021-05-08
- [Prometheus and the NixOS System Version](https://grahamc.com/blog/nixos-system-version-prometheus/), 2018-02-04
- [An EPYC NixOS build farm](https://grahamc.com/blog/an-epyc-nixos-build-farm/), 2018-08-02
- [Optimising Docker Layers for Better Caching with Nix](https://grahamc.com/blog/nix-and-layered-docker-images/), 2018-10-01

### Jade Lovelace

Lix co-founder and core contributor. Jade supplies the strongest counterweight to flake-centric design: keep flakes as thin wrappers, write ordinary parameterized Nix underneath, use `callPackage`, distinguish evaluation inputs from build sources, and select package pinning strategies by rebuild scope and package-set coherence.

- [Flakes aren't real and cannot hurt you](https://jade.fyi/blog/flakes-arent-real/), 2024-01-02
- [Pinning packages in Nix](https://jade.fyi/blog/pinning-packages-in-nix/), 2024-05-19
- [Pinning NixOS with npins](https://jade.fyi/blog/pinning-nixos-with-npins/), 2024-05-20

### Jacek Galowicz

Nixpkgs test-driver maintainer, trainer, and Nixcademy founder. His system articles demonstrate separating production capability from insecure VM policy, developing against quick NixOS VMs, converting working systems into integration tests, and declaratively describing disks and installation with Disko and nixos-anywhere.

- [Quick VMs with NixOS](https://galowicz.de/blog/quick-vms-with-nixos/), 2023-03-13
- [Single-Command Server Bootstrapping](https://galowicz.de/blog/single-command-server-bootstrap/), 2023-04-05

### Ian Henry

Author of the 49-part *How to Learn Nix* series. His 2021 flake articles are intentionally experiential rather than prescriptive. They expose usability requirements often missed by architecture guides: obvious routine commands, discoverable outputs, actionable errors, understandable upgrades, and awareness of Git-state surprises. Specific Nix 2.4 behavior and old output names are dated.

- [How to Learn Nix](https://ianthehenry.com/posts/how-to-learn-nix/), 2021-2024
- [My first brush with flakes](https://ianthehenry.com/posts/how-to-learn-nix/flakes/), 2021-12-05
- [More flakes, unfortunately](https://ianthehenry.com/posts/how-to-learn-nix/more-flakes/), 2021-12-07
- [Chipping away at flakes](https://ianthehenry.com/posts/how-to-learn-nix/chipping-away-at-flakes/), 2021-12-18
- [New and unimproved shells](https://ianthehenry.com/posts/how-to-learn-nix/nix-develop/), 2021-12-27

### Amos Wenger

Prominent long-form systems educator. The complete `#nix` series is an end-to-end Rust service case study. It supports pinning Nixpkgs, committing the lock, sharing one package across development, CI, and deployment artifacts, and explicitly persisting mutable application state. Exact Crane, Rust overlay, and flake-utils usage is historical.

- [Building a Rust service with Nix](https://fasterthanli.me/series/building-a-rust-service-with-nix), 2023-03-05
- [Learning Nix from the bottom up](https://fasterthanli.me/series/building-a-rust-service-with-nix/part-9), 2023-03-05
- [Making a dev shell with Nix flakes](https://fasterthanli.me/series/building-a-rust-service-with-nix/part-10), 2023-03-05
- [Generating a Docker image with Nix](https://fasterthanli.me/series/building-a-rust-service-with-nix/part-11), 2023-03-05
- [Extra credit](https://fasterthanli.me/series/building-a-rust-service-with-nix/part-12), 2023-03-05

### Ryan Yin

Author of the widely used, living *NixOS & Flakes Book*. It provides the freshest tutorial synthesis in this corpus for thin flake entry points, host/module organization, Home Manager scope, typed custom options, merge priorities, `mkIf`, and module recursion hazards. As a living book, pages may change without preserving their original publication context.

- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [Enabling NixOS with Flakes](https://nixos-and-flakes.thiscute.world/nixos-with-flakes/nixos-with-flakes-enabled)
- [Modularize Your NixOS Configuration](https://nixos-and-flakes.thiscute.world/nixos-with-flakes/modularize-the-configuration)
- [Module System and Custom Options](https://nixos-and-flakes.thiscute.world/other-usage-of-flakes/module-system)
- [Getting Started with Home Manager](https://nixos-and-flakes.thiscute.world/nixos-with-flakes/start-using-home-manager)

### NobbZ / Norbert Melzer

Long-time community participant. His article compares explicit functions, `specialArgs`, `_module.args`, and overlays for passing inputs into modules, with warnings about import-time recursion and using overlays as a general dependency bus. His current configuration uses flake-parts, showing that old personal preferences are not timeless rules.

- [Getting inputs to modules in a nix-flake](https://blog.nobbz.dev/blog/2022-12-12-getting-inputs-to-modules-in-a-flake), 2022-12-12
- [Flakes and command-not-found](https://blog.nobbz.dev/blog/2023-02-27-nixos-flakes-command-not-found), 2023-02-27
- [NixOS configuration](https://github.com/NobbZ/nixos-config)

### Mitchell Hashimoto

His public NixOS configuration is unusually visible and explicitly prioritizes simple practices and working personal configuration over theoretical optimality. His sole indexed Nix article advocates one Nix dependency definition across development, CI, build, and runtime while retaining Docker as an integration boundary. He is influential but not a prolific Nix writer.

- [Using Nix with Dockerfiles](https://mitchellh.com/writing/nix-with-dockerfiles), 2023-04-23
- [NixOS system configurations](https://github.com/mitchellh/nixos-config)

## Institutional And Canonical Sources

### nix.dev

Current official documentation occupies a middle position: it documents flakes while explicitly listing their experimental status, composition and cross-compilation limitations, eager inputs, recursive duplication, and process concerns. It recommends considering thin wrappers and alternatives. Its best-practice guide supports explicit dependencies, no top-level `with`, avoiding `rec`, explicit Nixpkgs configuration, and reproducible source names.

- [Flakes](https://nix.dev/concepts/flakes)
- [Best practices](https://nix.dev/guides/best-practices)
- [Pinning Nixpkgs](https://nix.dev/reference/pinning-nixpkgs)
- [Module system](https://nix.dev/tutorials/module-system/)
- [Integration testing with NixOS virtual machines](https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines)

### Determinate Systems

Determinate declares locked flakes production-stable in its distribution and favors flakes as versioned organizational boundaries. Luc Perkins recommends one flake per versioned thing and generally avoiding helper libraries to reduce transitive inputs and abstraction. This is a company position, not upstream consensus.

- [Experimental does not mean unstable](https://determinate.systems/blog/experimental-does-not-mean-unstable), Graham Christensen, 2023-09-06
- [Best practices for Nix at work](https://determinate.systems/blog/best-practices-for-nix-at-work/), Luc Perkins

### flake-parts

Canonical documentation argues that the module system is useful when flake configuration has independent, shareable concerns. It recommends focused modules, `perSystem`, and `callPackage`. Its benefits are real at scale, but it adds an input, a second module layer, and framework-specific concepts.

- [Introduction and Why Modules?](https://flake.parts/)
- [Getting Started](https://flake.parts/getting-started)
- [Core options](https://flake.parts/options/flake-parts.html)
- [Partitions](https://flake.parts/options/flake-parts-partitions.html)

## Where The Sources Disagree

### Flakes As Default

- Determinate and Ryan Yin recommend a flake-first workflow.
- Eelco's original series presents flakes as the standardized interface.
- Jade and current nix.dev recommend thin wrappers and preserving ordinary Nix underneath.
- Ian Henry documents serious early UX costs.

Default for agents: preserve the project's choice. For new code, use a thin flake when the requested workflow needs flakes; do not make internal code flake-only without a reason.

### Helper Frameworks

- flake-parts users value typed merging, modularity, and reusable flake modules.
- Determinate argues plain Nix is usually clearer and avoids unnecessary transitive inputs.
- NobbZ's evolution shows framework choice can change with configuration scale.

Default for agents: plain outputs for small configurations; retain an established framework; introduce one only for demonstrated composition pressure.

### Overlays

- Early flake tutorials frequently distribute packages through overlays.
- Jade, NobbZ, and current guidance prefer direct references or `callPackage` when package-set extension is unnecessary.

Default for agents: overlays are for coherent package-set customization, not general input transport.

### Custom Options

- Reusable services benefit from typed, namespaced options and `mkIf`.
- Ryan explicitly warns beginners not to parameterize modules before simple imports become inadequate.

Default for agents: add options when there are real consumers or variation, not merely because a file is called a module.

### Ephemeral State

- Graham's ephemeral-root approach continuously tests whether persistence is explicit.
- It also raises migration effort and data-loss risk when persistence declarations are incomplete.

Default for agents: always model state explicitly; use ephemeral roots only when requested or already adopted.

## Historical Syntax Traps

Recheck any copied example containing:

- `defaultPackage`, `defaultApp`, singular `devShell`, singular `nixosModule`, or singular `overlay`
- `pkgs.nixFlakes` or old experimental-feature setup
- old `nixos-rebuild`, installer, WSL, Disko, nixos-anywhere, or command-not-found behavior
- fixed release branches such as 20.03, 21.11, 22.05, 22.11, 23.11, or 24.05
- old `vendorSha256`, builder, Crane, gomod2nix, or Rust-overlay APIs
- hardware, bootloader, filesystem, kernel, and service options copied from personal configurations

Current conventional output shapes usually include `packages.<system>.default`, `apps.<system>.default`, `devShells.<system>.default`, `nixosModules.default`, and `overlays.default`, but always verify against the pinned toolchain.
