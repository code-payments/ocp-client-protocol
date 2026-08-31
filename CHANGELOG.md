# Changelog

Contract changes from a consumer's point of view: what appeared, what changed shape, and what breaks
if you upgrade. Field and enum renumbering matters more than its diff size suggests, so it gets
called out explicitly even when nothing else did.

`publish.yml` reads the section matching the version it is publishing and uses it as the GitHub
release notes, so a version with no entry here does not release. Write the entry in the same PR that
syncs the contract, while the diff is still in front of you.

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
