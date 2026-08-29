# Release Checklist

Use this checklist for every package release. Replace `X.Y.Z` and `<revision>`
with the intended version and immutable release commit.

## Prepare

- Start from a clean `main` branch synchronized with `origin/main`.
- Confirm `build.zig.zon` declares `X.Y.Z` and the intended minimum Zig
  version.
- Move relevant entries from `Unreleased` into an `X.Y.Z` changelog section
  with the release date, breaking-change notes, and migration instructions.
- Regenerate `docs/supported-languages.md` and confirm no unexplained diff.
- Update compatibility and architecture documents in the same slice as any
  behavior or API change.

## Verify

Run the local equivalents of the CI gates:

```sh
zig fmt --check build.zig src tests tools
./build.sh test -Doptimize=debug
./build.sh test-shared -Dexternal-backends=false -Doptimize=safe
./build.sh test-optional -Dexternal-backends=true -Doptimize=safe
```

Then:

- run affected consumer integration suites with the release commit;
- measure consumer binary-size changes and update reviewed baselines for
  intentional differences;
- rerun relevant benchmarks when parser, scanner, capture storage, allocation,
  or compiler behavior changed;
- push the release commit and wait for every required GitHub Actions job to
  pass.

## Tag And Pin

Create an annotated version tag on the verified release commit and push it:

```sh
git tag -a vX.Y.Z <revision>
git push origin vX.Y.Z
```

Calculate the Zig package hash from the immutable revision rather than a moving
branch:

```sh
zig fetch 'git+https://github.com/alogic0/zig-native-syntax.git#<revision>'
```

Update consumers with that exact Git URL and printed package hash. Run each
consumer's accepted local gates, commit its manifest change independently, and
verify its remote CI before considering the release integration complete.

## Publish Record

- Confirm the tag resolves to the tested commit and the package can be fetched
  in a clean cache.
- Publish release notes matching the changelog, including breaking changes,
  dependency changes, and measured size or performance effects.
- Leave a new empty `Unreleased` section at the top of `CHANGELOG.md` for the
  next development cycle.
