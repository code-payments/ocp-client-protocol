# Changelog

Contract changes from a consumer's point of view: what appeared, what changed shape, and what breaks
if you upgrade. Field and enum renumbering matters more than its diff size suggests, so it gets
called out explicitly even when nothing else did.

`publish.yml` reads the section matching the version it is publishing and uses it as the GitHub
release notes, so a version with no entry here does not release. Write the entry in the same PR that
syncs the contract, while the diff is still in front of you.

## 0.9.0

Synced to [`ocp-protobuf-api@98cf14de`](https://github.com/code-payments/ocp-protobuf-api/commit/98cf14de185d5abadf6f03b6802ff298f61610d0),
picking up [#71](https://github.com/code-payments/ocp-protobuf-api/pull/71). Only `transaction.v1` moved.

Stablecoin swaps can now use CoinbaseStableSwapper's `swap_v2` instruction, which is `swap` without
the deprecated whitelist account. The field is additive, so upgrading changes nothing until a client
sets it.

### Added

- `swap_version` (`uint32`, at most 2) on the CoinbaseStableSwapper initiate parameters of
  `StatefulSwapRequest` (field 9) and `StatelessSwapRequest` (field 4). Only `2` selects `swap_v2`.
  Unset, `0` and `1` keep the legacy `swap` instruction.
- The server builds the swap instruction from this field, and the client rebuilds and signs the
  same transaction locally. A client that sends `2` has to build `swap_v2` itself: discriminator
  `[43, 4, 237, 11, 26, 201, 30, 98]`, the same `amount_in` and `min_amount_out` args, and `swap`'s
  accounts with the whitelist (index 12) removed. If the field and the local instruction disagree,
  the swap fails.

### Changed

- Comments only: the CoinbaseStableSwapper server parameters on `StatefulSwapResponse` and
  `StatelessSwapResponse` now list the swap step as `Swap` or `SwapV2`, per `swap_version`.

### Unchanged

Nothing was renumbered, and nothing existing changed type or meaning. No service, RPC, message or
enum case was removed.

## 0.8.0

Synced to [`ocp-protobuf-api@6f70c0d8`](https://github.com/code-payments/ocp-protobuf-api/commit/6f70c0d8e832531fd006bbb02fcb2c5d07e0c247),
picking up [#70](https://github.com/code-payments/ocp-protobuf-api/pull/70). Only `transaction.v1` moved.

A new intent type pays several OCP primary accounts from one intent. It is additive, so the upgrade
is free. A client that switches over `Metadata.type` exhaustively gets one more case to handle.

### Added

- `SendPublicMultiPaymentMetadata`, carried as `Metadata.send_public_multi_payment` (oneof field 5).
  It holds a `source`, a `mint`, and 2 to 10 `payments`, each one a `destination`, an optional
  `destination_owner`, and either `server_exchange_data` or `client_exchange_data`. The intent emits
  one `NoPrivacyTransferAction` from the source primary account per payment.
- Every destination has to be an OCP-managed primary account for the intent's mint. Destinations
  and their owners must be unique and must differ from the source. Every payment has to share the
  same currency, the same verified core-mint rate and, for launchpad currencies, the same verified
  reserve state. When a destination's owner is an existing OCP user with no primary account on the
  mint yet, the server opens it, and `destination_owner` is required for that payment. The server
  may cap the payment count below 10.

### Unchanged

Nothing was renumbered, and nothing existing changed type or meaning. No service, RPC, message or
enum case was removed.

## 0.7.0

Synced to [`ocp-protobuf-api@00ea80d0`](https://github.com/code-payments/ocp-protobuf-api/commit/00ea80d00cf1ce76216937b60cfd60adfd37dc99),
picking up [#69](https://github.com/code-payments/ocp-protobuf-api/pull/69). Only `balance.v1` moved.

`GetBalances` now reports each mint's balance in quarks, and can skip the per-mint breakdown when a
caller only needs owner totals. Both are additive, so the upgrade is free.

### Added

- `MintBalance.quarks` (field 4), a `uint64` holding the balance of that mint in quarks.
- `GetBalancesRequest.exclude_per_mint_balances` (field 4), a `bool`. When true,
  `OwnerBalance.balances_by_mint` comes back empty. Owner totals are unaffected and still count
  every mint matching the `mints` filter. The default, false, keeps today's response.

### Unchanged

Nothing was renumbered, and nothing existing changed type or meaning. No service, RPC, message or
enum case was removed. Everything else in the diff is comments.

## 0.6.0

Synced to [`ocp-protobuf-api@e3d25a85`](https://github.com/code-payments/ocp-protobuf-api/commit/e3d25a85b1e1ce088e956714e1a71248322e215f),
picking up [#67](https://github.com/code-payments/ocp-protobuf-api/pull/67) (docs only) and
[#68](https://github.com/code-payments/ocp-protobuf-api/pull/68). Only `balance.v1` moved.

`GetBalances` can now report fiat values alongside core-mint values. The change is opt-in per
request, so the upgrade is free: a caller that sends no currency codes gets exactly what it got
before.

### Added

- `GetBalancesRequest.currency_codes` (field 3), a `repeated string` of lowercase ISO 4217 codes
  such as `"usd"`. At most 256, no duplicates, each matching `^[a-z]{3,4}$`. Empty means core-mint
  values only.
- `OwnerBalance.fiat_values_by_currency` (field 4), a `map<string, double>` holding the owner's
  total across all balances, keyed by currency code.
- `MintBalance.fiat_values_by_currency` (field 3), the same map for a single mint's balance.

Both maps are populated only for the codes the request asked for. A code the caller did not request
is absent, not zero.

### Unchanged

Nothing was renumbered, and nothing existing changed type or meaning. The new fields take the next
free number in each message. No service, RPC, message or enum case was removed. Everything else in
the diff is comments.

## 0.5.0

No contract change. Still synced to
[`ocp-protobuf-api@82202912`](https://github.com/code-payments/ocp-protobuf-api/commit/82202912574e122bba90025fe8b292d5a3f04c05).

### Added

- `OcpContractInfo` (Kotlin) and `OCPContractInfo` (Swift), carrying `VERSION` /
  `version` and `PROTO_COMMIT` / `protoCommit` for the upstream commit this package was
  generated from, plus `shortProtoCommit` and `isLocal`. A package built from
  `sync-protos.sh --local` reports `LOCAL` as its commit, so a consumer can tell a local
  contract build from a pinned one at runtime.

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
