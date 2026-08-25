# ocp-client-protocol

Kotlin and Swift client SDKs for the Open Code Protocol gRPC contract. The protos are synced
from [`ocp-protobuf-api`](https://github.com/code-payments/ocp-protobuf-api) at a pinned commit,
generated here, and published as one versioned package that both apps consume.

| Language | Package | Generated namespace |
|---|---|---|
| Kotlin | `com.flipcash:ocp-client-protocol` on Maven Central | `com.codeinc.opencode.gen.*` |
| Swift | `OCPClientProtocol`, resolved by SPM from this repo's tags | `Ocp_*_V1_*` |

Its sibling is [`flipcash2-client-protocol`](https://github.com/code-payments/flipcash2-client-protocol).
They are separate packages because the contracts are: flipcash2 does not import ocp.

## Install

```kotlin
implementation("com.flipcash:ocp-client-protocol:0.1.0")
```

```swift
.package(url: "https://github.com/code-payments/ocp-client-protocol", from: "0.1.0")
```

`code-android-app` pins the version in `gradle/libs.versions.toml`. `code-ios-app` pins it in
`FlipcashAPI/Package.swift` and re-exports the module, so app code still reaches these types
through `import FlipcashAPI`.

## What it contains

Four services — `Account`, `Currency`, `Messaging`, `Transaction` — plus the shared
`common/v1/model.proto`. The contract is owned upstream; `ocp.lock` records which commit of it
this package was generated from.

## Layout

```
proto/                       contract, synced from upstream at the SHA in ocp.lock
proto_deps/validate/         include-path dependency, never generated
Sources/OCPClientProtocol/   generated Swift, committed (SPM ships source)
build.gradle.kts             Kotlin generation + publishing
scripts/
  sync-protos.sh             pull upstream at a pinned SHA, re-namespace
  install-swift-toolchain.sh pinned generators into .tools/
  toolchain.env              the pins
  generate-swift.sh          regenerate Sources/
```

Generated Kotlin is not committed — it is a build input to the published JAR.

## Updating the contract

```bash
scripts/install-swift-toolchain.sh      # once: pinned generators into .tools/
scripts/sync-protos.sh <upstream-sha>   # re-pins ocp.lock
scripts/generate-swift.sh               # refresh committed Swift
./gradlew build                         # Kotlin regenerates as part of the build
```

Commit the resulting `proto/`, `ocp.lock`, and `Sources/` together. CI re-runs both generators
and fails if `Sources/` does not match the protos.

## Local development

Trying a contract change does not need a release. `sync-protos.sh --local` reads a checkout of
[`ocp-protobuf-api`](https://github.com/code-payments/ocp-protobuf-api) directly, uncommitted
edits included:

```bash
scripts/sync-protos.sh --local ../ocp-protobuf-api  # or set OCP_UPSTREAM_PATH
scripts/generate-swift.sh                           # only if you need the Swift side
```

That writes `commit: LOCAL` into `ocp.lock`. CI fails on it and the publish workflow refuses to
release it, so a local sync cannot reach `main` or Maven Central. Push the contract change and
re-run `scripts/sync-protos.sh <sha>` to get back to a reproducible pin.

Both apps can consume a checkout of this repo without a publish as well: `protoLocalRoot` in
Android's `local.properties`, `FLIPCASH_PROTO_LOCAL` for iOS. The whole loop, including what
stops a local state from shipping, is in `docs/proto-local-development.md` in the cross-platform
orchestrator directory.

## Releasing

`.github/workflows/publish.yml`, run from the Actions tab with a version like `0.1.0`. One
version covers both languages: the Kotlin artifact goes to Maven Central and the git tag the
workflow pushes *is* the Swift Package release. See [docs/releasing.md](docs/releasing.md) for
the required secrets and the one-time Central setup.

## Docs

| Document | Covers |
|---|---|
| [Code generation](docs/generation.md) | the pinned toolchain, what each generator emits, why the Swift is committed and the Kotlin is not |
| [Releasing](docs/releasing.md) | the publish workflow, the signing secrets, coordinates vs namespace |
| [Migration from vendored protos](docs/migration.md) | what this package replaced, and the parity evidence from the cutover |
