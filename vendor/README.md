# Vendor Files Directory

This folder is intended to hold the Android APK installers required by the deployment scripts. 

Since these files are very large and update frequently, they are **not** included directly in the source control repository.

### What goes here?
You need to download two files from F-Droid and place them inside this `vendor/` folder:

1. **Termux APK** (`com.termux_*.apk`)
   Download: https://f-droid.org/packages/com.termux/
   
2. **Termux:Widget APK** (`com.termux.widget_*.apk`)
   Download: https://f-droid.org/packages/com.termux.widget/

Once those two `.apk` files are in this folder, you can run the `deploy_to_scanner` scripts!
