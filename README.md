# ocp-client-protocol

Kotlin and Swift client SDKs for the Open Code Protocol, generated from the contract in
[`ocp-protobuf-api`](https://github.com/code-payments/ocp-protobuf-api) and published so the
apps consume a versioned dependency instead of vendoring `.proto` files and running protoc
themselves.

`code-android-app` and `code-ios-app` used to each vendor their own copy of these protos and
generate independently — two copies of the contract, two generator toolchains, and no mechanism
that made them agree. This repo is the single generation point that replaced them.

It is the sibling of [`flipcash2-client-protocol`](https://github.com/code-payments/flipcash2-client-protocol).
The two are separate packages because the contracts are independent — flipcash2 does not import
ocp — and because they belong to different orgs once the split lands.

## Status

Released. `0.1.0` is on Maven Central and tagged for SPM. Android consumes it in
[code-android-app#1325](https://github.com/code-payments/code-android-app/pull/1325) and iOS in
[code-ios-app#645](https://github.com/code-payments/code-ios-app/pull/645), which together delete
both vendored copies.

Before the apps migrated, `scripts/verify-parity.sh` proved this repo is a drop-in replacement
for what they generated: 263 Kotlin/Java files against
`:definitions:opencode:models:generateDebugProto` and 9 Swift files against
`FlipcashAPI/.../Payments/Generated`, both identical, with the Kotlin split matching per
generator (4 grpc, 4 grpckt, 5 java, 119 kotlin, 131 validate-kt). That gate is retired with the
copies it compared against — an app that no longer generates has no second output to disagree
with. What guards the output now is `scripts/toolchain.env`, since a floating generator moves
the Swift without any contract change.

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

Generated Kotlin is not committed. It is a build input to a published JAR, so the
reviewable-diff argument that applies to Swift does not apply here.

## Updating the contract

```bash
scripts/install-swift-toolchain.sh      # once: pinned generators into .tools/
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
- **The Swift generators are pinned, and one of the pins is transitive.** `brew install
  protoc-gen-grpc-swift` was enough to reproduce the committed output in August 2026 and is
  not enough now. The gRPC stub text is rendered by grpc-swift-2's `GRPCCodeGen`, which
  grpc-swift-protobuf pulls in with a floating `from:` requirement — so the output moves
  when *that* releases, with the plugin's own version unchanged. 2.2.1 added `Sendable` to
  the metadata enums and 2.3.0 added `type:` to every `MethodDescriptor`: ~840 changed
  lines across 9 files, no contract change. `scripts/toolchain.env` pins all four
  versions and `install-swift-toolchain.sh` builds the plugins against them.
- **Coroutines are an explicit dependency.** The generated grpckt stubs reference
  `kotlinx.coroutines.flow.Flow`; the app gets that from elsewhere in its graph, a standalone
  artifact cannot.

## Releasing

`.github/workflows/publish.yml`, run from the Actions tab with a version like `0.1.0`. One
version covers both languages: the Kotlin artifact goes to Maven Central, and the git tag the
workflow pushes *is* the Swift Package release, because SPM resolves source straight from this
repo.

The workflow refuses to publish a version that is already tagged, builds and signs everything
before it uploads anything, and tags last — so a broken POM or a stale `Sources/` fails while
the version number is still spendable. `dry_run` does everything except upload and tag.

Consuming a release:

```kotlin
implementation("com.flipcash:ocp-client-protocol:0.1.0")
```

```swift
.package(url: "https://github.com/code-payments/ocp-client-protocol", from: "0.1.0")
```

### Secrets this needs

Set in both repos.

| Secret | What it is |
|---|---|
| `MAVEN_CENTRAL_USERNAME` | Central Portal user token, not the account login |
| `MAVEN_CENTRAL_PASSWORD` | the matching token password |
| `MAVEN_SIGNING_KEY` | ASCII-armored private key, `gpg --armor --export-secret-keys` |
| `MAVEN_SIGNING_KEY_ID` | last 8 characters of the key id |
| `MAVEN_SIGNING_KEY_PASSWORD` | the key's passphrase |

**The signing key's public half must be on a keyserver Central queries.** Producing valid
`.asc` files is not enough: Central fetches the public key by fingerprint to check them, and
one it cannot find fails the whole deployment with `Could not find a public key by the key
fingerprint` against every signed file. Upload once, per key:

```bash
gpg --keyserver keyserver.ubuntu.com --send-keys <fingerprint>
```

The `com.flipcash` namespace is verified in the Central Portal. That was the other one-time
human step, and the one that needs a DNS TXT record.

## Not done yet

Both consumer PRs are open, not merged.

Note that the artifact coordinates and the generated namespace are deliberately different.
The artifact publishes under `com.flipcash`; the code inside it stays in
`com.codeinc.opencode.gen.*`, because that is what the app imports and it is set by
`java_package` in the protos.
