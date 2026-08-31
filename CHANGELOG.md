# Changelog

Contract changes from a consumer's point of view: what appeared, what changed shape, and what breaks
if you upgrade. Field and enum renumbering matters more than its diff size suggests, so it gets
called out explicitly even when nothing else did.

`publish.yml` reads the section matching the version it is publishing and uses it as the GitHub
release notes, so a version with no entry here does not release. Write the entry in the same PR that
syncs the contract, while the diff is still in front of you.

## 0.3.0

No contract change. `ocp.lock` points at the same upstream commit as `0.2.0`, and the generated
Kotlin and Swift are unchanged. Swift consumers have nothing to gain from this release.

### Added

- The Kotlin artifact now ships R8 keep rules, at `META-INF/proguard/ocp-client-protocol.pro`:

  ```proguard
  -keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
      <fields>;
  }
  ```

  protobuf-javalite ships no keep rules of its own, so until now every Android consumer had to
  write one, and the obvious `-keep class * extends GeneratedMessageLite { *; }` is far wider
  than javalite needs. javalite resolves *fields* reflectively — the schema built from
  `newMessageInfo` looks up `java.lang.reflect.Field` by the generated `<name>_` field — while
  builders and message methods are reached from ordinary call sites, so R8 traces those without
  help. `-keepclassmembers` also does not keep the class, so a message type nothing references is
  still removed entirely.

  On upgrading, an Android consumer can delete its own protobuf keep rules. Dropping the wide
  pair from `code-android-app` cut 25,542 live methods and 568 live classes, and moved its R8
  optimization score from 89.3% to 96.3%.

  The rule is deliberately not scoped to `com.codeinc.opencode.gen.**`. The well-known types (`Any`, `Timestamp`,
  `Duration`, `Struct`) come from protobuf-javalite itself, and other dependencies ship generated
  messages with no rules of their own, so a package-scoped rule would leave those broken under R8
  full mode. Both contract packages ship identical rule text; R8 collapses them into one entry.

## 0.2.0

Synced to [`ocp-protobuf-api@ea6418c5`](https://github.com/code-payments/ocp-protobuf-api/commit/ea6418c5561e16771d456062be2fcbd3ddeb9caf).

### Added

- `ocp.balance.v1.Balance`, a new service with one unary RPC, `GetBalance`. It takes an owner account
  and returns `core_mint_value`, a `uint64` in quarks, alongside a result enum of `OK`, `DENIED`, and
  `NOT_FOUND`.

  `GetBalanceRequest` carries no auth or signature field, unlike every other OCP request. It reads
  balance for any owner account rather than the caller's own, so there is nothing to sign.

Nothing existing changed. No field number or enum value moved, so upgrading from `0.1.0` needs no
consumer changes.

## 0.1.0

First release. The OCP contract is now generated once here and published for both platforms, replacing
the copies each app vendored and generated for itself.

- Kotlin, on Maven Central as `com.flipcash:ocp-client-protocol`, under `com.codeinc.opencode.gen.*`.
- Swift, as the `OCPClientProtocol` module. The git tag is the SPM release.
