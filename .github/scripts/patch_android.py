import os
import re

def patch():
    # 1. Add location, internet & notification permissions to AndroidManifest.xml
    manifest_path = "android/app/src/main/AndroidManifest.xml"
    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            content = f.read()
        perms = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>

    <queries>
        <intent>
            <action android:name="android.intent.action.INSERT" />
            <data android:mimeType="vnd.android.cursor.dir/event" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="geo" />
        </intent>
    </queries>
    <uses-feature android:name="android.hardware.location.gps" android:required="false"/>
    <uses-feature android:name="android.hardware.location.network" android:required="false"/>
"""
        receivers = """
        <!-- Required for scheduled notifications in flutter_local_notifications -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""
        if "android.permission.SCHEDULE_EXACT_ALARM" not in content:
            content = content.replace("<application", perms + "    <application")
        # The API key is stored in SharedPreferences; keep it out of adb
        # backups and cloud backups of the app's private data.
        if "android:allowBackup" not in content:
            content = re.sub(
                r"<application\b",
                '<application android:allowBackup="false"',
                content,
                count=1,
            )
        # Enable Android Predictive Back gesture (Android 13/14+)
        if "android:enableOnBackInvokedCallback" not in content:
            content = re.sub(
                r"<application\b",
                '<application android:enableOnBackInvokedCallback="true"',
                content,
                count=1,
            )
        if "ScheduledNotificationReceiver" not in content:
            content = content.replace("<activity", receivers + "        <activity")
        content = re.sub(r'package="[^"]*"', 'package="com.spor.mobile"', content)
        content = re.sub(r'android:label="[^"]*"', 'android:label="Spor"', content)
        if "android:roundIcon" not in content:
            content = content.replace(
                'android:icon="@mipmap/ic_launcher"',
                'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"'
            )
        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(content)
        print("Patched AndroidManifest.xml with notification permissions, receivers and app label Spor")

    # Copy custom launcher icons from assets/android/res
    import shutil
    assets_res = "assets/android/res"
    dest_res = "android/app/src/main/res"
    if os.path.exists(assets_res) and os.path.exists(dest_res):
        for root, dirs, files in os.walk(assets_res):
            rel_dir = os.path.relpath(root, assets_res)
            target_dir = os.path.join(dest_res, rel_dir)
            os.makedirs(target_dir, exist_ok=True)
            for f in files:
                shutil.copy2(os.path.join(root, f), os.path.join(target_dir, f))
        print("Copied custom Spor launcher icons to android/app/src/main/res")

    # 2. Upgrade Kotlin version to 1.9.22 in build.gradle and settings.gradle
    for fn in ["android/build.gradle", "android/settings.gradle"]:
        if os.path.exists(fn):
            with open(fn, "r", encoding="utf-8") as f:
                content = f.read()
            content = re.sub(
                r"ext\.kotlin_version\s*=\s*['\"][^'\"]+['\"]",
                "ext.kotlin_version = '1.9.22'",
                content,
            )
            content = re.sub(
                r'id\s*[\'"]org\.jetbrains\.kotlin\.android[\'"]\s*version\s*[\'"][^\'"]+[\'"]',
                "id 'org.jetbrains.kotlin.android' version '1.9.22'",
                content,
            )
            with open(fn, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Patched Kotlin version in {fn}")

    # 3. Upgrade compileSdkVersion to 34 and enable multiDex in app/build.gradle
    app_gradle = "android/app/build.gradle"
    if os.path.exists(app_gradle):
        with open(app_gradle, "r", encoding="utf-8") as f:
            content = f.read()
        content = re.sub(r'compileSdk(?:Version)?\s*=?\s*\d+', "compileSdkVersion 36", content)
        content = re.sub(r'targetSdk(?:Version)?\s*=?\s*\d+', "targetSdkVersion 36", content)
        content = re.sub(r'minSdk(?:Version)?\s*=?\s*(?:\d+|flutter\.minSdkVersion)', "minSdkVersion 32", content)

        # Enforce com.spor.mobile namespace and applicationId
        content = re.sub(r'namespace\s*=?\s*["\'][^"\']+["\']', 'namespace "com.spor.mobile"', content)
        content = re.sub(r'applicationId\s*=?\s*["\'][^"\']+["\']', 'applicationId "com.spor.mobile"', content)

        if "multiDexEnabled" not in content and "defaultConfig {" in content:
            content = content.replace("defaultConfig {", "defaultConfig {\n        multiDexEnabled true")

        with open(app_gradle, "w", encoding="utf-8") as f:
            f.write(content)
        print("Patched compileSdkVersion 36, targetSdkVersion 36, minSdkVersion 32 (Android 12L), applicationId com.spor.mobile in app/build.gradle")

    # 3.1 Ensure gradle.properties suppresses unsupported compileSdk warning
    gradle_props = "android/gradle.properties"
    if os.path.exists(gradle_props):
        with open(gradle_props, "r", encoding="utf-8") as f:
            props = f.read()
        if "android.suppressUnsupportedCompileSdk" not in props:
            props += "\nandroid.suppressUnsupportedCompileSdk=36\n"
            with open(gradle_props, "w", encoding="utf-8") as f:
                f.write(props)
        print("Ensured android.suppressUnsupportedCompileSdk=36 in gradle.properties")

    # 4. Copy permanent release keystore to android/app/spor-release.jks
    keystore_src = "keystores/spor-release.jks"
    if not os.path.exists(keystore_src) and os.path.exists("../.github/keystores/spor-release.jks"):
        keystore_src = "../.github/keystores/spor-release.jks"

    keystore_dest = "android/app/spor-release.jks"
    if os.path.exists(keystore_src):
        os.makedirs("android/app", exist_ok=True)
        shutil.copy2(keystore_src, keystore_dest)
        print(f"Copied release keystore from {keystore_src} to {keystore_dest}")
    else:
        print(f"WARNING: Release keystore not found at {keystore_src}!")

    # 5. Patch signingConfigs and buildTypes in app/build.gradle
    if os.path.exists(app_gradle):
        with open(app_gradle, "r", encoding="utf-8") as f:
            content = f.read()

        signing_block = """    signingConfigs {
        release {
            keyAlias 'spor'
            keyPassword 'spor123456'
            storeFile file('spor-release.jks')
            storePassword 'spor123456'
        }
    }

"""
        if "signingConfigs {" not in content:
            content = content.replace("buildTypes {", signing_block + "buildTypes {")

        content = re.sub(
            r"signingConfig\s*=?\s*signingConfigs\.debug",
            "signingConfig signingConfigs.release",
            content
        )
        with open(app_gradle, "w", encoding="utf-8") as f:
            f.write(content)
        print("Patched release signing config in app/build.gradle")

    # 6. Enforce MainActivity.kt with package com.spor.mobile
    kotlin_base = "android/app/src/main/kotlin"
    target_kt_dir = os.path.join(kotlin_base, "com", "spor", "mobile")
    os.makedirs(target_kt_dir, exist_ok=True)
    target_kt_file = os.path.join(target_kt_dir, "MainActivity.kt")
    with open(target_kt_file, "w", encoding="utf-8") as f:
        f.write("package com.spor.mobile\n\nimport io.flutter.embedding.android.FlutterActivity\n\nclass MainActivity: FlutterActivity() {\n}\n")
    print(f"Created {target_kt_file} with package com.spor.mobile")

    # Remove any stray directories in kotlin folder not matching com/spor/mobile
    for root, dirs, files in os.walk(kotlin_base, topdown=False):
        for d in dirs:
            dir_path = os.path.join(root, d)
            rel = os.path.relpath(dir_path, kotlin_base).replace("\\", "/")
            if not ("com".startswith(rel) or "com/spor".startswith(rel) or rel == "com/spor/mobile"):
                shutil.rmtree(dir_path, ignore_errors=True)

if __name__ == "__main__":
    patch()

