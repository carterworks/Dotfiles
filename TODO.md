# TODO

## Installation blocker: Atuin on macOS

The main nixpkgs pin's Atuin 18.23.0 fails its `filtered_commands_leave_no_captured_output` end-to-end test on `Carters-MacBook-Pro`. The shell-completion, Home Manager, and Darwin system failures are downstream dependency failures.

The failing derivation is `/nix/store/g144wicsf2xrv1hxc3wkf95y6dzdf6fq-atuin-18.23.0.drv`, matching [failed Hydra build 349284273](https://hydra.nixos.org/build/349284273). The Darwin test fix was merged in [nixpkgs PR #574509](https://github.com/NixOS/nixpkgs/pull/574509), after the previous October 15 pin.

The temporary macOS workaround selects the unmodified Atuin package from the separate `nixpkgs-atuin` input, pinned to `7a6522c868711d06e3a520bbcdfafe9806f4337f`. Its output, `/nix/store/lyh7qwqxlbyv8va4ssmh2js4jdq36w4q-atuin-18.23.0`, was downloaded successfully from `cache.nixos.org` with local builds disabled. This replaces the test-skipping override, which required a custom source build. Linux is unchanged. The main nixpkgs pin has since advanced to `09063bd1f2b36fd9fd793c36dfade7bd40a93dfc`, which contains the Darwin test fix; its Atuin output matches the cached workaround output. The workaround remains until the macOS install is validated.

- [x] Validate that the upstream `nixos-unstable` channel advanced beyond `fe13242281a67641c0102cdb1087f0ebe586c7df` and run `./update --apply` to pick up the newer snapshot. The lock now points at `09063bd1f2b36fd9fd793c36dfade7bd40a93dfc`.
- [ ] Remove the temporary Atuin assignment in `nix/machines/carters-macbook-pro.nix` and the `nixpkgs-atuin` input from `flake.nix`, then run `nix flake lock` to prune its lock entry. Follow the machine file's validation instructions. Complete this task only after Atuin is available without local compilation or the temporary pin and `./install` succeeds.

Run this Bash one-liner from the repository root. It prints the current revision and exits successfully only when the channel has advanced:

```bash
rev=$(git ls-remote --exit-code https://github.com/NixOS/nixpkgs.git refs/heads/nixos-unstable) && rev=${rev%%[[:space:]]*} && if [[ -n "$rev" && "$rev" != fe13242281a67641c0102cdb1087f0ebe586c7df ]]; then printf 'Channel advanced: %s\n' "$rev"; else printf 'Channel has not advanced: %s\n' "$rev"; false; fi
```

This command checks channel advancement only; it does not verify that the lock was updated, that the Atuin fix is included, or that installation succeeds.

## Temporary pins and workarounds

- [ ] `t3code-cli`: remove the patchelf 0.15.2 pin in `nix/packages/t3code-cli.nix` once a newer patchelf can rewrite the Node SEA launcher without corrupting its program headers. Validate with `nix build .#t3code-cli`, `t3 --version`, and `t3 serve` before removing.
- [ ] `t3code-cli`: revisit `dontStrip = true` once stripping can preserve the embedded Node SEA payload; verify `t3 --version` and `t3 serve` before removing it.
- [ ] macOS Brave: remove the `sourceRoot` overlay in `nix/machines/carters-macbook-pro.nix` once NixOS/nixpkgs#560971 is fixed upstream.
- [ ] Vicinae on scylla: remove the `QT_QUICK_BACKEND=software` override in `nix/machines/scylla/hyprland.nix` once the Qt OpenGL backend opens reliably with hardware rendering.
- [ ] stable-diffusion.cpp: drop the upstream master pin in `nix/users/carter/packages.nix` when nixpkgs ships Qwen Image 2.1 support and the Turbo sigma preset.
- [ ] kubelogin: reassess the 0.1.9 pin when newer releases persist the Ethos device-code token instead of re-prompting on every invocation.
