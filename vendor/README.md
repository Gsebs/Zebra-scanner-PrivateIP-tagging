# Vendor APKs (download once)

The deploy script will install Termux + Termux:Widget on each scanner
automatically - but it needs the APK files to be in this folder first.

## What to download

1. **Termux** - https://f-droid.org/en/packages/com.termux/
   - On the page, scroll to the "Packages" section and download the latest
     release (the link will look like `com.termux_118.apk` or similar).
   - Save it directly into this `vendor/` folder.

2. **Termux:Widget** - https://f-droid.org/en/packages/com.termux.widget/
   - Same as above. The filename will look like `com.termux.widget_13.apk`.
   - Save it into this `vendor/` folder.



The deploy script finds them by glob (`com.termux_*.apk`,
`com.termux.widget_*.apk`), so you don't need to rename them.


**If a scanner already has Termux installed from the Play Store**, the deploy
script will fail with a signing-key conflict. Uninstall the Play Store
version on the scanner first (Settings -> Apps -> Termux -> Uninstall), then
re-run the deploy script. The F-Droid version will install cleanly.

