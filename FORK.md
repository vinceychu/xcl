# This fork

A fork of [ivall/xcl](https://github.com/ivall/xcl) (GPL-2.0-only, unchanged licence).

- **Ready-made builds:** every push to `main` publishes `xcl-windows-x64.zip` under
  [Releases → latest](../../releases/tag/latest): `xcl.exe` with the DirectX Shader Compiler next to
  it, so no Rust toolchain or Windows SDK is needed (`.github/workflows/release.yml`).
- **Tracks upstream:** `main` merges `ivall/xcl` main every six hours
  (`.github/workflows/sync-upstream.yml`).
- Upstream's PR description gate (`pr-check.yml`) only runs in `ivall/xcl`.

## Linux (Wine / Proton)

Upstream targets Windows only. This fork also runs `xcl.exe` under Wine with vkd3d-proton
(D3D12 on Vulkan): XCL hands vkd3d-proton command allocators and lists with the runtime's own
vtable pointer, which it checks (`real::with_native_vtables`, Wine only).

- Measured on an NVIDIA RTX 5090, GE-Proton11-14 (Wine + vkd3d-proton, DXVK's `dxgi.dll`),
  DXC 1.9: the test title (`tests/testtitle`) passes 47 of its 48 checks. The one that fails,
  "user32: … hidden 1920x1080 console screen: not cloaked", asks for a DWM cloak Wine does not have.
- No retail game has been run on Linux yet.
- `xgameruntime.dll` (Gaming Services) is absent under Wine; XCL warns and uses its own task
  queues, async and networking.
- On a headless X server, start it without the Composite extension (`Xvfb -extension Composite`):
  with it, Xvfb and Xorg (dummy driver) crashed in `miValidateTree` when XCL showed its window.
