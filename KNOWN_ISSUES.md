# Known Issues

Transient or environmental issues that have bitten bootstrap and their
diagnosis. Each entry: symptom → cause → fix → how to detect.

---

## Brew bottle of `python@3.11` is broken on macOS 26 (Tahoe)

**Symptom.** `apConfig` fails inside the oMLX install with:

```
==> python3.11 -m venv /opt/homebrew/Cellar/omlx/0.3.8/libexec
Error: Command '['…/libexec/bin/python3.11', '-m', 'ensurepip',
  '--upgrade', '--default-pip']' returned non-zero exit status 1.
```

The same failure hits **anything** that creates a venv against brew's
`python@3.11`: `python3.11 -m venv /tmp/foo` fails standalone, not just omlx.

**Cause.** Apple SDK / runtime version skew, not a brew or Python bug.

- `MacOSX26.4.sdk/usr/include/expat.h` **declares** the libexpat 2.7.2
  alloc-tracker API (`XML_SetAllocTrackerActivationThreshold`,
  `XML_SetAllocTrackerMaximumAmplification`). Comments in the header say
  *"Added in Expat 2.7.2."*
- `MacOSX15.4.sdk/usr/include/expat.h` does **not** declare them.
- macOS 26.2's runtime `libexpat.1.dylib` reports `XML_ExpatVersion() =
  expat_2.7.1` and does **not** actually export those symbols.

Result: anything compiled against the **macOS 26 SDK** that touches
`xml.parsers.expat` ends up with an unresolvable undefined symbol at runtime.
This affects brew's bottled `python@3.11` *and* any from-source rebuild on a
macOS 26.2 machine that uses the default CLT SDK. It will affect anything
else that compiles pyexpat (or other libexpat users) against the new SDK
until Apple ships a macOS point-update with runtime libexpat 2.7.2.

**Quick diagnosis** (5 seconds, no install required):

```bash
rm -rf /tmp/vt && /opt/homebrew/opt/python@3.11/bin/python3.11 -m venv /tmp/vt
# Failure with ensurepip CalledProcessError → you have this bug.
```

Confirming root cause (proves it's libexpat, not something else):

```bash
/opt/homebrew/opt/python@3.11/bin/python3.11 -c \
  'import xml.parsers.expat'  # ImportError: Symbol not found: _XML_SetAllocTrackerActivationThreshold
```

**Fix.** Force the build to use the older SDK (both are already on your
machine after running the CLT upgrade earlier):

```bash
HOMEBREW_SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  brew reinstall --build-from-source python@3.11
```

The 15.4 SDK's `expat.h` doesn't declare the 2.7.2 symbols, so the resulting
`pyexpat.so` doesn't reference them, and dyld resolves cleanly against the
running macOS 26 libexpat (which is 2.7.1).

> A plain `brew reinstall --build-from-source python@3.11` does **not** work
> — it picks up the default SDK (MacOSX26.4.sdk) which has the offending
> header declarations. The SDKROOT override is mandatory until Apple
> ships libexpat 2.7.2 in a macOS point-update.

Takes 10–15 min. Verify after:

```bash
/opt/homebrew/opt/python@3.11/bin/python3.11 -c \
  'import xml.parsers.expat as e; print(e.EXPAT_VERSION)'
rm -rf /tmp/vt && /opt/homebrew/opt/python@3.11/bin/python3.11 -m venv /tmp/vt \
  && /tmp/vt/bin/pip --version
```

Then re-run `apConfig`.

**Why not bake this into the playbook?** This is an Apple SDK/runtime skew
that'll get fixed when macOS 26.x ships libexpat 2.7.2 (likely 26.3 or a
26.2.1 point release). Always rebuilding Python from source with an SDK
override would add 10–15 min to every bootstrap, and the override path itself
becomes wrong as soon as Apple publishes the runtime fix. A detect-and-bail
pre-flight check is the right pattern — fast on a healthy machine, clear
remediation on a broken one. See open question below.

**Practical workaround we adopted for oMLX.** Avoided the formula entirely;
the `macos.yml` task installs the .dmg app from GitHub releases. The app
bundles its own Python + expat, so this bug doesn't apply. The brew formula
remains the only way to get the `omlx` CLI command, but we don't need it for
the server use case. If/when this bug clears, we can add the formula task
back alongside the DMG install.

**Open question.** Should we add a pre-flight check task to `macos.yml` that
runs `python3.11 -m venv /tmp/__pi_venv_probe__` and fails fast with a pointer
to this doc if it errors? Probably yes once we're sure the symptom is stable.

**First hit.** 2026-05-10, while installing oMLX via `apConfig` on
macos-26.2 / Apple Silicon / brew 5.1.10.
