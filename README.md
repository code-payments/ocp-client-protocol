# ocp-client-protocol

Kotlin and Swift client SDKs for the Open Code Protocol, generated from the contract in
[`ocp-protobuf-api`](https://github.com/code-payments/ocp-protobuf-api) and published so the
apps consume a versioned dependency instead of vendoring `.proto` files and running protoc
themselves.

Today `code-android-app` and `code-ios-app` each vendor their own copy of these protos and
generate independently. That is two copies of the contract, two generator toolchains, and no
mechanism that makes them agree. This repo is the single generation point.

## Status

Pilot. Nothing consumes this yet, and it has never been published to a real registry. What is
verified is that the generated code is a drop-in replacement for what the apps produce now:

| Output | Files | Compared against | Result |
|---|---|---|---|
| Kotlin/Java | 263 | `:definitions:opencode:models:generateDebugProto` | identical |
| Swift | 9 | `FlipcashAPI/.../Payments/Generated` | identical |

The Kotlin split matches per generator too: 4 grpc, 4 grpckt, 5 java, 119 kotlin, 131
validate-kt. `scripts/verify-parity.sh` is that check, and it should stay green until both
apps migrate.

Both artifacts also build: `swift build` compiles the SPM target, and `./gradlew build
publishToMavenLocal` produces a 1418-class JAR under `com.codeinc.opencode.gen.*`.

## Layout

```
proto/                       contract, synced from upstream at the SHA in ocp.lock
proto_deps/validate/         include-path dependency, never generated
Sources/OCPClientProtocol/   generated Swift, committed (SPM ships source)
build.gradle.kts             Kotlin generation + publishing
scripts/
  sync-protos.sh             pull upstream at a pinned SHA, re-namespace
  generate-swift.sh          regenerate Sources/
  verify-parity.sh           the phase-1 gate
```

Generated Kotlin is not committed. It is a build input to a published JAR, so the
reviewable-diff argument that applies to Swift does not apply here.

## Updating the contract

```bash
scripts/sync-protos.sh <upstream-sha>   # re-pins ocp.lock
scripts/generate-swift.sh               # refresh committed Swift
./gradlew build                         # Kotlin regenerates as part of the build
```

## Things worth knowing

- **This repo owns the `java_package` namespace.** Upstream ships `com.codeinc.gen.*`; the
  Android app has always consumed `com.codeinc.opencode.gen.*` via a `sed`/`awk` pass at the
  end of its `fetch-protos.sh`. `sync-protos.sh` does that rewrite instead, so the published
  artifact needs no consumer-side post-processing. Swift is unaffected — `java_package` does
  not influence swift-protobuf naming, which the byte-identical Swift output confirms.
- **`validate/validate.proto` is an include-path dependency only.** It is never generated. The
  iOS build currently generates it and then deletes the resulting
  `validate_validate.pb.swift`; keeping it in `proto_deps/` and off the generation list removes
  the need for that step.
- **`grpc-kotlin` codegen is pinned to 1.4.1**, matching the app. 1.5.0 was tested: it differs
  in line wrapping only (344 lines, no API change), so the bump is safe but belongs in its own
  commit.
- **The JVM and Android variants of the protobuf Gradle plugin differ.** The JVM variant
  registers the `java` builtin by default; the Android variant does not, which is why the app
  declares `java` as a plugin and this repo configures the builtin instead.
- **Coroutines are an explicit dependency.** The generated grpckt stubs reference
  `kotlinx.coroutines.flow.Flow`; the app gets that from elsewhere in its graph, a standalone
  artifact cannot.

## Not done yet

Publishing CI, a real released version, and consumption by either app. The Maven coordinates
(`com.codeinc.opencode:ocp-client-protocol`) and the Swift module name (`OCPClientProtocol`)
are proposals, not decisions.
