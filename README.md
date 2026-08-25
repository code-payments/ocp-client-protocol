# ocp-client-protocol

Kotlin and Swift client SDKs for the Open Code Protocol, generated from the contract in
[`ocp-protobuf-api`](https://github.com/code-payments/ocp-protobuf-api) and published so the
apps consume a versioned dependency instead of vendoring `.proto` files and running protoc
themselves.

Today `code-android-app` and `code-ios-app` each vendor their own copy of these protos and
generate independently. That is two copies of the contract, two generator toolchains, and no
mechanism that makes them agree. This repo is the single generation point.

It is the sibling of [`flipcash2-client-protocol`](https://github.com/code-payments/flipcash2-client-protocol).
The two are separate packages because the contracts are independent — flipcash2 does not import
ocp — and because they belong to different orgs once the split lands.

## Status

Pilot. It has never been published to a real registry, and neither app depends on it on a
branch. What is verified is that the generated code is a drop-in replacement for what the apps
produce now:

| Output | Files | Compared against | Result |
|---|---|---|---|
| Kotlin/Java | 263 | `:definitions:opencode:models:generateDebugProto` | identical |
| Swift | 9 | `FlipcashAPI/.../Payments/Generated` | identical |

The Kotlin split matches per generator too: 4 grpc, 4 grpckt, 5 java, 119 kotlin, 131
validate-kt. `scripts/verify-parity.sh` is that check, and it should stay green until both
apps migrate.

Both artifacts also build: `swift build` compiles the SPM target, and `./gradlew build
publishToMavenLocal` produces a 1418-class JAR under `com.codeinc.opencode.gen.*`.

The consumer side is proven too. Pointing `:services:opencode` at the mavenLocal artifact and
dropping `:definitions:opencode:models` from its classpath builds the app and passes the
module's 603 unit tests, with `protovalidate-runtime` and coroutines arriving transitively.

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

None of these exist yet — the first publish is blocked until someone with org access adds them.

| Secret | What it is |
|---|---|
| `MAVEN_CENTRAL_USERNAME` | Central Portal user token, not the account login |
| `MAVEN_CENTRAL_PASSWORD` | the matching token password |
| `MAVEN_SIGNING_KEY` | ASCII-armored private key, `gpg --armor --export-secret-keys` |
| `MAVEN_SIGNING_KEY_ID` | last 8 characters of the key id |
| `MAVEN_SIGNING_KEY_PASSWORD` | the key's passphrase |

The `com.flipcash` namespace also has to be verified in the Central Portal before the first
upload is accepted, which means a DNS TXT record on the matching domain. That is a one-time
human step and it gates everything else here.

The signing path itself is verified: a throwaway key produces `.asc` signatures for all five
artifacts Central requires (jar, sources, javadoc, pom, module), and all five verify.

## Not done yet

A real released version and a committed dependency in either app. Publishing CI exists but has
never run: the Central namespace is unverified and the signing secrets are unset.

Note that the artifact coordinates and the generated namespace are deliberately different.
The artifact publishes under `com.flipcash`; the code inside it stays in
`com.codeinc.opencode.gen.*`, because that is what the app imports and it is set by
`java_package` in the protos.
