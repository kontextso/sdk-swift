# Releasing

- This document describes the process for cutting a new release of the **Kontext SDK**.  
- Follow these steps to ensure consistency across releases.
- Replace version `1.0.0` with the proper one instead.

> We use versioning without `v` at the front to align it for both SPM and Cocoapods so please keep that in mind.
> For Example: `1.0.0`.

---

## 1. Create a release branch and test

1. Checkout branch `develop`
1. Pull the latest changes
1. Create a new branch `release/1.0.0`
1. Make sure it builds.
1. Run tests and make sure they are green.
1. Run ExampleSwiftUI and make sure it's OK.
1. Run ExampleUIKit and make sure it's OK.

## 2. Update the changelog

Edit CHANGELOG.md to include the new release notes in following format

```markdown
## [1.0.0](https://github.com//kontextso/sdk-swift/releases/tag/1.0.0)

Released on 2025-09-16.

## Added
 
- New feature added

## Updated

- Some feature updated

## Removed

- Old feature removed
```


## 3. Update the CocoaPods spec

Update the version in KontextSDK.podspec:

```
s.version = "1.0.0"

```

## 4. Update SDKInfo

Update the version in SDKInfo.swift to match the new version:


```swift

struct SDKInfo {
    ...
    static let sdkVersion = "1.0.0"
    ...
}
```

## 5. Commit changes

Commit the CHANGELOG.md and KontextSDK.podspec to `release/1.0.0` branch

```bash
git add CHANGELOG.md KontextSDK.podspec
git commit -m "Prepare release 1.0.0"
```

## 6. Open pull requests

1. Create a PR to develop named: "Release version 1.0.0" and use the last changelog entry as the PR description.
2. Merge the PR to develop.
3. Create a PR to master with same attributes.
4. Merge the PR to master.

## 7. Create an annotated tag

```bash
git tag -a 1.0.0 -m "Release 1.0.0"
git push origin 1.0.0
```

## 8. Publish to CocoaPods trunk

```bash
pod trunk push KontextSwiftSDK.podspec --allow-warnings
```

## 9. Create GitHub release

1. Go GitHub releases (under tags)
2. Draft a new release
3. Use release title that describes the changes as a whole.
4. Copy over the last CHANGELOG.md entry as release notes.
5. Choose a proper version tag you just created
6. Publish release

## 10. Verify

1. Check that the version is available on the [CocoaPods page](https://cocoapods.org/pods/KontextSwiftSDK).
2. Integrate the new version into the internal testing app and confirm it builds and runs.
3. Release the internal testing app with updated SDK version.
