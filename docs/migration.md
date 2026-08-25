# Migration from vendored protos

`code-android-app` and `code-ios-app` each used to vendor their own copy of the OCP protos and
generate independently — two copies of the contract, two generator toolchains, and nothing that
made them agree. This package replaced both.

`0.1.0` shipped in August 2026. Android migrated in
[code-android-app#1325](https://github.com/code-payments/code-android-app/pull/1325) and iOS in
[code-ios-app#645](https://github.com/code-payments/code-ios-app/pull/645), which together
deleted the vendored copies; Android's remaining `:definitions:*` modules and its
`scripts/fetch-protos.sh` went in
[code-android-app#1326](https://github.com/code-payments/code-android-app/pull/1326).

## The parity gate, and why it is gone

Before the apps migrated, `scripts/verify-parity.sh` proved this repo was a drop-in replacement
for what they generated: 263 Kotlin/Java files against
`:definitions:opencode:models:generateDebugProto` and 9 Swift files against
`FlipcashAPI/.../Payments/Generated`, both identical, with the Kotlin split matching per
generator (4 grpc, 4 grpckt, 5 java, 119 kotlin, 131 validate-kt).

That gate retired with the copies it compared against — an app that no longer generates has no
second output to disagree with.

## What replaced it

Contract drift between the platforms was possible because each vendored its own copy. With one
generation point it is possible only if the two apps sit on different package versions, which is
a visible version number rather than a silent content diff.

What still needs watching is generator drift, which parity never guarded well anyway: the Swift
output moves on a transitive grpc-swift-2 release with no contract change at all.
`scripts/toolchain.env` is the guarantee now — see [Code generation](generation.md).
