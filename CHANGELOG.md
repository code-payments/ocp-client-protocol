# Changelog

Contract changes from a consumer's point of view: what appeared, what changed shape, and what breaks
if you upgrade. Field and enum renumbering matters more than its diff size suggests, so it gets
called out explicitly even when nothing else did.

`publish.yml` reads the section matching the version it is publishing and uses it as the GitHub
release notes, so a version with no entry here does not release. Write the entry in the same PR that
syncs the contract, while the diff is still in front of you.

## 0.4.0

Synced to [`ocp-protobuf-api@82202912`](https://github.com/code-payments/ocp-protobuf-api/commit/82202912574e122bba90025fe8b292d5a3f04c05).

**Breaking.** `ocp.balance.v1.Balance` had exactly one RPC and it has been replaced, so every
consumer of the service has work to do. There is no deprecation window: `GetBalance` is gone in the
same release that adds `GetBalances`.

### Removed

- `GetBalance`, along with `GetBalanceRequest` and `GetBalanceResponse`.

- `GetBalancesResponse.Result.NOT_FOUND`. `OK` and `DENIED` keep `0` and `1`, so no surviving case
  renumbers and no positional mapping shifts underneath you. What changes is that "this owner has no
  balance" no longer has a result code: an owner with nothing to report is simply absent from
  `balances_by_owner`. Code that branched on `NOT_FOUND` needs to branch on a missing map entry
  instead, and code that treated a non-`OK` result as a hard failure will now see `OK` where it used
  to see `NOT_FOUND`.

### Added

- `GetBalances`, a unary RPC that batches what `GetBalance` did one owner at a time.

  `GetBalancesRequest` takes `repeated owners` (1 to 1024) where the old request took a single
  `owner`, plus an optional `repeated mints` filter (up to 1024). Leaving `mints` empty returns
  every mint each owner holds, which is the closest thing to the old behaviour.

  `GetBalancesResponse` returns `map<string, OwnerBalance> balances_by_owner`, keyed by owner
  address. Each `OwnerBalance` carries the `core_mint_value` total in quarks that the old flat
  response returned directly, plus `map<string, MintBalance> balances_by_mint` keyed by mint
  address for the per-mint breakdown. So the scalar total still exists, one level further down.

  Like `GetBalance` before it, `GetBalancesRequest` carries no auth or signature field. It reads
  balances for arbitrary owner accounts rather than the caller's own, so there is nothing to sign.

### Migrating

A single-owner call maps across mechanically: wrap the owner in `owners`, leave `mints` empty, and
read `balances_by_owner[owner]?.core_mint_value` where you read `core_mint_value` before. Treat a
missing entry as the old `NOT_FOUND`. The per-mint breakdown and the multi-owner batch are new
capability, not something the old shape expressed, so nothing forces you to use either.

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
