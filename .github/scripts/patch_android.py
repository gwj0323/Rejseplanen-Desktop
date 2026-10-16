import os
import re
import shutil

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

    # 2. Upgrade AGP to 8.7.2 and Kotlin version to 1.9.24 in settings.gradle and build.gradle
    settings_gradle = "android/settings.gradle"
    if os.path.exists(settings_gradle):
        with open(settings_gradle, "r", encoding="utf-8") as f:
            s_content = f.read()
        s_content = re.sub(
            r'id\s*[\'"]com\.android\.application[\'"]\s*version\s*[\'"][^\'"]+[\'"]',
            'id "com.android.application" version "8.7.2"',
            s_content
        )
        s_content = re.sub(
            r'id\s*[\'"]org\.jetbrains\.kotlin\.android[\'"]\s*version\s*[\'"][^\'"]+[\'"]',
            'id "org.jetbrains.kotlin.android" version "1.9.24"',
            s_content
        )
        with open(settings_gradle, "w", encoding="utf-8") as f:
            f.write(s_content)
        print("Patched AGP 8.7.2 and Kotlin 1.9.24 in android/settings.gradle")

    build_gradle = "android/build.gradle"
    if os.path.exists(build_gradle):
        with open(build_gradle, "r", encoding="utf-8") as f:
            b_content = f.read()
        b_content = re.sub(
            r"classpath\s*['\"]com\.android\.tools\.build:gradle:[^'\"]+['\"]",
            "classpath 'com.android.tools.build:gradle:8.7.2'",
            b_content
        )
        b_content = re.sub(
            r"ext\.kotlin_version\s*=\s*['\"][^'\"]+['\"]",
            "ext.kotlin_version = '1.9.24'",
            b_content
        )
        b_content = re.sub(
            r'id\s*[\'"]org\.jetbrains\.kotlin\.android[\'"]\s*version\s*[\'"][^\'"]+[\'"]',
            'id "org.jetbrains.kotlin.android" version "1.9.24"',
            b_content
        )
        b_content = re.sub(
            r'id\s*[\'"]com\.android\.application[\'"]\s*version\s*[\'"][^\'"]+[\'"]',
            'id "com.android.application" version "8.7.2"',
            b_content
        )
        with open(build_gradle, "w", encoding="utf-8") as f:
            f.write(b_content)
        print("Patched AGP 8.7.2 and Kotlin 1.9.24 in android/build.gradle")

    # 3. Upgrade Gradle wrapper to 8.9 (required for AGP 8.7)
    gw_path = "android/gradle/wrapper/gradle-wrapper.properties"
    os.makedirs(os.path.dirname(gw_path), exist_ok=True)
    if os.path.exists(gw_path):
        with open(gw_path, "r", encoding="utf-8") as f:
            gw_content = f.read()
        gw_content = re.sub(
            r'distributionUrl=.*',
            r'distributionUrl=https\://services.gradle.org/distributions/gradle-8.9-all.zip',
            gw_content
        )
        with open(gw_path, "w", encoding="utf-8") as f:
            f.write(gw_content)
    else:
        with open(gw_path, "w", encoding="utf-8") as f:
            f.write("distributionBase=GRADLE_USER_HOME\n"
                    "distributionPath=wrapper/dists\n"
                    "zipStoreBase=GRADLE_USER_HOME\n"
                    "zipStorePath=wrapper/dists\n"
                    "distributionUrl=https\\://services.gradle.org/distributions/gradle-8.9-all.zip\n")
    print("Patched gradle-wrapper.properties to Gradle 8.9")

    # 4. Upgrade compileSdkVersion to 36, targetSdkVersion to 36, minSdkVersion to 32 (Android 12L)
    app_gradle = "android/app/build.gradle"
    if os.path.exists(app_gradle):
        with open(app_gradle, "r", encoding="utf-8") as f:
            content = f.read()
        content = re.sub(r'compileSdk(?:Version)?\s*=?\s*[^\r\n]+', "compileSdkVersion 36", content)
        content = re.sub(r'targetSdk(?:Version)?\s*=?\s*[^\r\n]+', "targetSdkVersion 36", content)
        content = re.sub(r'minSdk(?:Version)?\s*=?\s*[^\r\n]+', "minSdkVersion 32", content)

        # Enforce com.spor.mobile namespace and applicationId
        content = re.sub(r'namespace\s*=?\s*["\'][^"\']+["\']', 'namespace "com.spor.mobile"', content)
        content = re.sub(r'applicationId\s*=?\s*["\'][^"\']+["\']', 'applicationId "com.spor.mobile"', content)

        # Upgrade Java & JVM target to 17
        content = re.sub(
            r'sourceCompatibility\s*=?\s*[^\r\n]+',
            'sourceCompatibility = JavaVersion.VERSION_17',
            content
        )
        content = re.sub(
            r'targetCompatibility\s*=?\s*[^\r\n]+',
            'targetCompatibility = JavaVersion.VERSION_17',
            content
        )
        if "jvmTarget" in content:
            content = re.sub(
                r'jvmTarget\s*=\s*[^\r\n]+',
                "jvmTarget = '17'",
                content
            )
        elif "kotlinOptions {" in content:
            content = content.replace("kotlinOptions {", "kotlinOptions {\n        jvmTarget = '17'")
        else:
            content += "\nandroid.kotlinOptions {\n    jvmTarget = '17'\n}\n"

        # Explicitly enforce JVM 17 on all KotlinCompile tasks
        kotlin_compile_block = """
tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
    kotlinOptions {
        jvmTarget = "17"
    }
}
"""
        if "tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile)" not in content:
            content += kotlin_compile_block
        # Enable core library desugaring for flutter_local_notifications
        if "coreLibraryDesugaringEnabled" not in content:
            if "compileOptions {" in content:
                content = content.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true")

        if "desugar_jdk_libs" not in content:
            if "dependencies {" in content:
                content = content.replace("dependencies {", "dependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'")
            else:
                content += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"

        if "checkReleaseBuilds false" not in content:
            lint_block = """    lintOptions {
        checkReleaseBuilds false
        abortOnError false
    }

"""
            if "buildTypes {" in content:
                content = content.replace("buildTypes {", lint_block + "buildTypes {")

        if "multiDexEnabled" not in content and "defaultConfig {" in content:
            content = content.replace("defaultConfig {", "defaultConfig {\n        multiDexEnabled true")

        with open(app_gradle, "w", encoding="utf-8") as f:
            f.write(content)
        print("Patched compileSdkVersion 36, targetSdkVersion 36, minSdkVersion 32 (Android 12L), Java 17, desugaring in app/build.gradle")
        print("Verified compileSdk in build.gradle:", re.findall(r'compileSdk[^\r\n]*', content))
        print("Verified targetSdk in build.gradle:", re.findall(r'targetSdk[^\r\n]*', content))
        print("Verified minSdk in build.gradle:", re.findall(r'minSdk[^\r\n]*', content))
        print("Verified desugaring in build.gradle:", "coreLibraryDesugaring" in content and "desugar_jdk_libs" in content)

    # 5. Ensure gradle.properties suppresses unsupported compileSdk warning
    gradle_props = "android/gradle.properties"
    props = ""
    if os.path.exists(gradle_props):
        with open(gradle_props, "r", encoding="utf-8") as f:
            props = f.read()
    if "android.suppressUnsupportedCompileSdk" not in props:
        props += "\nandroid.suppressUnsupportedCompileSdk=36\n"
    else:
        props = re.sub(r'android\.suppressUnsupportedCompileSdk=.*', 'android.suppressUnsupportedCompileSdk=36', props)
    if "android.useAndroidX=true" not in props:
        props += "\nandroid.useAndroidX=true\n"
    with open(gradle_props, "w", encoding="utf-8") as f:
        f.write(props)
    print("Ensured android.suppressUnsupportedCompileSdk=36 in gradle.properties")

    # 6. Ensure local.properties defines flutter.compileSdkVersion=36 etc.
    local_props = "android/local.properties"
    lp = ""
    if os.path.exists(local_props):
        with open(local_props, "r", encoding="utf-8") as f:
            lp = f.read()
    lp = re.sub(r'flutter\.compileSdkVersion=.*', 'flutter.compileSdkVersion=36', lp)
    lp = re.sub(r'flutter\.targetSdkVersion=.*', 'flutter.targetSdkVersion=36', lp)
    lp = re.sub(r'flutter\.minSdkVersion=.*', 'flutter.minSdkVersion=32', lp)
    if 'flutter.compileSdkVersion' not in lp:
        lp += "\nflutter.compileSdkVersion=36\nflutter.targetSdkVersion=36\nflutter.minSdkVersion=32\n"
    with open(local_props, "w", encoding="utf-8") as f:
        f.write(lp)
    print("Ensured flutter.compileSdkVersion=36, targetSdkVersion=36, minSdkVersion=32 in local.properties")

    # 7. Configure release keystore (from CI secret base64 or local keystores/spor-release.jks)
    import base64
    keystore_dest = "android/app/spor-release.jks"
    keystore_b64 = os.environ.get("ANDROID_KEYSTORE_BASE64", "").strip()

    has_keystore = False
    if keystore_b64:
        try:
            os.makedirs("android/app", exist_ok=True)
            with open(keystore_dest, "wb") as f:
                f.write(base64.b64decode(keystore_b64))
            print("Successfully decoded release keystore from ANDROID_KEYSTORE_BASE64 secret.")
            has_keystore = True
        except Exception as e:
            print(f"ERROR: Failed to decode ANDROID_KEYSTORE_BASE64: {e}")
    else:
        # Fall back to local file if present (for offline development)
        for cand in ["keystores/spor-release.jks", "../.github/keystores/spor-release.jks", "android/app/spor-release.jks"]:
            if os.path.exists(cand):
                cand_abs = os.path.abspath(cand)
                dest_abs = os.path.abspath(keystore_dest)
                if cand_abs != dest_abs:
                    os.makedirs("android/app", exist_ok=True)
                    shutil.copy2(cand, keystore_dest)
                    print(f"Copied local release keystore from {cand} to {keystore_dest}")
                else:
                    print(f"Using existing keystore at {keystore_dest}")
                has_keystore = True
                break
        if not has_keystore:
            print("NOTICE: No release keystore found (neither secret nor local file).")

    # 8. Patch signingConfigs and buildTypes in app/build.gradle
    if os.path.exists(app_gradle):
        with open(app_gradle, "r", encoding="utf-8") as f:
            content = f.read()

        signing_block = """    signingConfigs {
        release {
            if (file('spor-release.jks').exists()) {
                keyAlias (System.getenv("ANDROID_KEY_ALIAS") ?: "spor")
                keyPassword (System.getenv("ANDROID_KEY_PASSWORD") ?: "spor123456")
                storeFile file('spor-release.jks')
                storePassword (System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: "spor123456")
            } else {
                keyAlias 'androiddebugkey'
                keyPassword 'android'
                storeFile file("${System.getProperty('user.home')}/.android/debug.keystore")
                storePassword 'android'
            }
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

    # 9. Enforce MainActivity.kt with package com.spor.mobile
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
