# This fork

A fork of [ivall/xcl](https://github.com/ivall/xcl) (GPL-2.0-only, unchanged licence).

- **Ready-made builds:** every push to `main` publishes `xcl-windows-x64.zip` under
  [Releases → latest](../../releases/tag/latest): `xcl.exe` with the DirectX Shader Compiler next to
  it, so no Rust toolchain or Windows SDK is needed (`.github/workflows/release.yml`).
- **Tracks upstream:** `main` merges `ivall/xcl` main every six hours
  (`.github/workflows/sync-upstream.yml`).
- Upstream's PR description gate (`pr-check.yml`) only runs in `ivall/xcl`.
