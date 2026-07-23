---
name: nix-configuration
description: Nix, Nixpkgs, NixOS, nix-darwin, Home Manager, flake.nix, and Nix module configuration guidance. Use when creating, changing, debugging, reviewing, or structuring flakes, packages, dev shells, overlays, modules, hosts, tests, deployments, or declarative system configuration.
---

# Nix Configuration

Write unsurprising Nix that makes dependencies, composition, state, and verification explicit. Preserve the repository's established architecture unless it causes the problem being solved.

## Research Current Interfaces

Nix examples age quickly. Before introducing or changing an option, output, command, or third-party input:

1. Determine the pinned Nixpkgs and dependency revisions from `flake.lock` or the project's pinning mechanism.
2. Search the matching NixOS, nix-darwin, or Home Manager options and package set.
3. Read current upstream documentation or source for third-party APIs.
4. Treat blog snippets as design evidence, not current syntax.

Read [references/sources.md](references/sources.md) when choosing architecture, resolving conflicting advice, or updating old code.

## Workflow

1. Inspect `flake.nix`, the lock file, adjacent modules, formatter and checks, supported systems, and rebuild/deploy commands.
2. Trace imports, module arguments, overlays, package definitions, and callers before editing.
3. Classify the change as package, project environment, reusable module, host fact, shared policy, user policy, deployment, or persistent state.
4. Put it at the narrowest correct boundary. Do not redesign the repository for a local change.
5. Use the least powerful composition mechanism that works: direct expression, explicit function argument, module import, typed option, overlay, then framework abstraction.
6. Format and evaluate the smallest relevant output first, then build or test it.
7. Report what was evaluated, built, or boot-tested. Do not claim reproducibility from evaluation alone.

## Flakes And Pins

- Keep `flake.nix` a thin dependency and output boundary. Put package logic in package files, reusable behavior in modules, and machine details in host files.
- Commit `flake.lock` for deployable or reproducible artifacts. Review lock changes as dependency upgrades; avoid unrelated lock churn.
- Use conventional, discoverable outputs: `packages`, `apps`, `devShells`, `checks`, `formatter`, `overlays`, `nixosModules`, `nixosConfigurations`, `darwinConfigurations`, and `homeConfigurations`.
- Expose a `default` only when there is an obvious default. Verify output names with `nix flake show`.
- Enumerate systems actually supported. Do not advertise targets that are never evaluated or built.
- Use `inputs.<name>.inputs.nixpkgs.follows = "nixpkgs"` only when that input is designed to share the root package set. Do not force convergence mechanically.
- Flake inputs are evaluation-time dependencies. Prefer Nixpkgs fetchers and fixed hashes for ordinary build-time sources.
- Avoid ambient channels, registries, `<nixpkgs>`, `$NIX_PATH`, environment variables, `builtins.currentSystem`, and undeclared paths in reproducible code.
- Remember that Git-backed flakes omit untracked files. Stage a new source file before diagnosing a missing-path error.
- Flakes improve source pinning and interface conventions; they do not by themselves guarantee reproducible builds or deployments.

If the repository is not flake-based, do not migrate it without a concrete reason. A pinned non-flake configuration is valid.

## Packages And Overlays

- Define packages as ordinary parameterized Nix files and instantiate them with `pkgs.callPackage` where practical. This keeps dependencies visible and supports overrides and cross-compilation.
- Reuse one package derivation across `packages`, dev shells, images, tests, and service modules instead of rebuilding it differently in each place.
- Prefer direct package references or explicit arguments for local packages.
- Use an overlay only when consumers need a coherently extended or replaced package set. Do not use overlays merely to smuggle flake inputs through `pkgs`.
- Keep package sets coherent. Mixing Nixpkgs revisions can be acceptable for isolated executables but is risky for linked libraries, plugins, and package-set-wide overrides.
- Set Nixpkgs `config` and `overlays` explicitly when importing it outside the module system.
- Use a stable source name with `builtins.path { name = ...; }` when a source path's parent directory would otherwise affect its store name.

## Modules And Systems

- Separate reusable capabilities from concrete hosts. Hosts should mostly compose modules and declare hardware, identity, topology, and deliberate exceptions.
- Split by ownership and reason to change, not arbitrary file size. Typical boundaries are hardware, base policy, roles/capabilities, users, environment-specific policy, and host facts.
- A simple always-on configuration file is already a module. Add custom options only when consumers need variation, reuse, or a stable interface.
- For reusable modules, use a collision-resistant namespace, typed options, useful descriptions, `lib.mkEnableOption` when optional, and `lib.mkIf` for conditional implementation.
- Provide a `package` option when consumers may need to override the implementation package.
- Prefer existing upstream options over generating raw configuration files. Use free-form settings only for behavior the upstream module does not expose cleanly.
- Let option types perform merging. Use `mkDefault` for genuine overridable policy, `mkBefore` or `mkAfter` when order is semantically required, and `mkForce` only for an intentional hard override.
- Never put `imports` under `config`. Do not make `imports` depend on values supplied through `_module.args`; import resolution happens too early and commonly recurses.
- Do not write `config = if config.foo ...`; use `config = lib.mkIf config.foo ...` or condition an individual option value.
- Pass non-module dependencies explicitly. Use ordinary function arguments for narrow local dependencies and `specialArgs` or `extraSpecialArgs` for values genuinely needed throughout a module graph.
- Keep NixOS policy system-scoped and Home Manager policy user-scoped. Promote user settings to NixOS only when the system or every user requires them.
- Keep debug conveniences, insecure VM settings, and production policy in separate modules. Reuse the production capability inside the test environment, not vice versa.
- Keep generated hardware configuration recognizable and isolate disk, boot, and hardware facts from shared policy.
- Never change `system.stateVersion`, `home.stateVersion`, or equivalent compatibility state merely to match the current release. Change it only as a researched migration.

## Frameworks

- Do not add `flake-utils`, flake-parts, auto-import machinery, or a dendritic framework to a small flake merely to remove a few lines.
- Keep an existing framework when the repository relies on its merge semantics and conventions.
- Introduce flake-parts only when independent flake concerns need typed, mergeable composition or repeated per-system glue has become a demonstrated maintenance problem.
- Introduce auto-discovery or dendritic organization only at a scale where explicit imports are a measured burden. Account for hidden import edges, slower evaluation, harder debugging, and flake lock growth.
- Optimize flake-parts with partitions only after measuring eager fetching or evaluation problems.

## State, Secrets, And Deployment

- Separate declarative configuration, immutable store content, mutable runtime state, and secrets. They have different lifecycles and recovery guarantees.
- Never place secret values in Nix expressions, derivations, command-line arguments, world-readable store paths, or committed flake inputs. Follow the repository's existing secret system.
- Declare which state must survive rebuild, reboot, replacement, and disaster recovery. A reproducible system closure does not reproduce databases, keys, or user data.
- Prefer declarative disk and installation tooling when the project already uses it, but treat disk changes as destructive and verify device assumptions explicitly.
- Build before switching or deploying. For remote changes, preserve a rollback path and avoid mixing unrelated dependency upgrades with service changes.
- Deploy production from a clean, committed revision when traceability matters. Record the revision in monitoring or system metadata where the existing system supports it.
- Ephemeral-root or impermanence designs are optional operational strategies, not defaults. Adopt them only with an audited persistence list and tested recovery.

## Style

- Prefer explicit names and small lexical scopes. Avoid top-level `with`; usually avoid `rec`; use `let` and `inherit` deliberately.
- Avoid clever recursive merges, dynamic import trees, and generalized host generators until repeated concrete cases justify them.
- Keep lists and attribute sets readable. Follow the repository's formatter rather than hand-aligning code.
- Comments should explain a compatibility constraint, hardware quirk, ordering requirement, or upstream bug, not restate the option name.

## Verification Ladder

Run the smallest applicable steps, then expand:

1. Format or check formatting with the repository's formatter.
2. Parse/evaluate the changed expression or exact output.
3. Run `nix flake check` when present and relevant.
4. Build the changed package, dev shell, module check, or system toplevel.
5. For service behavior, use `pkgs.testers.runNixOSTest`, an existing VM/container test, or the project's deployment test.
6. For multi-host repositories, evaluate or build every host affected by shared modules.

Expose cheap, deterministic checks under `checks` so CI and `nix flake check` discover them. Evaluation catches module and type errors; builds catch derivation errors; VM tests catch boot, service, network, and state behavior.

Do not run `nixos-rebuild switch`, `darwin-rebuild switch`, destructive Disko modes, remote deployment, secret rekeying, or lock-wide updates without user intent.

## Review Checklist

- Are all evaluation dependencies pinned and explicit?
- Is `flake.nix` an interface rather than the implementation dump?
- Are outputs conventional and discoverable?
- Are host facts, reusable capabilities, user policy, and mutable state separated?
- Are module options typed, namespaced, and conditional without recursion hazards?
- Is an overlay or framework solving a real package-set or composition problem?
- Are secrets kept out of the store and source tree?
- Does the same package flow through development, tests, images, and services?
- Are lock changes intentional and scoped?
- Were all affected systems evaluated, built, or behavior-tested at the appropriate level?
