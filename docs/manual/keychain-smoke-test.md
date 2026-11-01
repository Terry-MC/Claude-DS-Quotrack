# Keychain CredentialStore smoke test

The automated tests use `InMemoryCredentialStore` and never touch the real
Keychain. Run this thin manual check after changing `KeychainCredentialStore`,
its queries, or the Settings account flow.

Use a disposable API key (or any dummy string), never a production credential.
The test only verifies storage behavior; it does not call a Provider.

## Preconditions

- Build and run the app from Xcode or:
  `xcodebuild build -project Quotrack.xcodeproj -scheme Quotrack -destination 'platform=macOS' -derivedDataPath .build/DerivedData`
- The app is sandboxed, so its files live under
  `~/Library/Containers/com.terry.quotrack/Data/`.
- Do not use `security ... -g` or Keychain Access "Show password"; the point is
  that Quotrack never displays a saved credential in full.

## Steps and expected results

1. **Add.** Open the menu bar item, right-click, choose 设置…, click 添加账户…,
   choose a Provider (try Moonshot or SiliconFlow and a Region), enter a label
   and a dummy credential, and save.
   - The Account appears in the Settings list.
   - No credential text is shown in the list or anywhere after saving.

2. **Inspect metadata.** Open
   `~/Library/Containers/com.terry.quotrack/Data/Library/Application Support/com.terry.quotrack/accounts.json`.
   - The Account's UUID, Provider, Region, and label are present.
   - The dummy credential is absent from this file and from `snapshots.json`.

3. **Relaunch.** Quit Quotrack from the menu bar and launch it again, then open
   设置….
   - The Account is still listed with the same label and Region.
   - Editing it shows an empty credential field; the saved credential is not
     displayed.

4. **Replace.** In 编辑账户…, change only the label and save.
   - The label changes; the UUID, Provider, and Region do not.
   - The Keychain item for the UUID is unchanged (in Keychain Access, search
     service `com.terry.quotrack`).
   - Reopen 编辑账户…, enter a new dummy credential in
     `替换凭证（留空则保持不变）`, and save. Repeat the Keychain Access search.
   - The item still exists for the same UUID, and no credential text is
     displayed.

5. **Delete.** Click 删除 and confirm.
   - The Account disappears from the list.
   - The UUID is gone from `accounts.json` and `snapshots.json`.
   - In Keychain Access (category 密码, service `com.terry.quotrack`) the item
     for that UUID is gone. Optionally confirm from Terminal without printing
     the secret:
     `security find-generic-password -s com.terry.quotrack -a <UUID>`
     should report that the item could not be found.
