import os
import re

def patch():
    # 1. Add permissions to AndroidManifest.xml
    manifest_path = "android/app/src/main/AndroidManifest.xml"
    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            content = f.read()

        permissions_to_add = [
            '<uses-permission android:name="android.permission.INTERNET"/>',
            '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>',
            '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>',
            '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
            '<uses-permission android:name="android.permission.VIBRATE"/>',
            '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>',
            '<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>',
            '<uses-feature android:name="android.hardware.location.gps" android:required="false"/>',
            '<uses-feature android:name="android.hardware.location.network" android:required="false"/>',
        ]

        missing_perms = [p for p in permissions_to_add if p not in content]
        if missing_perms:
            block = "    " + "\n    ".join(missing_perms) + "\n"
            content = content.replace("<application", block + "    <application")
            with open(manifest_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Patched {len(missing_perms)} permissions in AndroidManifest.xml")
        else:
            print("All permissions already present in AndroidManifest.xml")

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

    # 3. Update android/app/build.gradle
    app_gradle = "android/app/build.gradle"
    if os.path.exists(app_gradle):
        with open(app_gradle, "r", encoding="utf-8") as f:
            content = f.read()

        # compileSdk & targetSdk to 34
        content = re.sub(r"compileSdk(?:Version)?\s*=?\s*(\d+|flutter\.compileSdkVersion)", "compileSdkVersion 34", content)
        content = re.sub(r"targetSdk(?:Version)?\s*=?\s*(\d+|flutter\.targetSdkVersion)", "targetSdkVersion 34", content)

        # multiDexEnabled true in defaultConfig
        if "multiDexEnabled" not in content:
            content = re.sub(
                r"(defaultConfig\s*\{)",
                r"\1\n        multiDexEnabled true",
                content,
            )

        # coreLibraryDesugaringEnabled true in compileOptions
        if "coreLibraryDesugaringEnabled" not in content:
            if "compileOptions {" in content:
                content = re.sub(
                    r"(compileOptions\s*\{)",
                    r"\1\n        coreLibraryDesugaringEnabled true",
                    content,
                )
            else:
                # add compileOptions if not present
                compile_options_block = """    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
"""
                content = re.sub(r"(android\s*\{)", r"\1\n" + compile_options_block, content)

        # desugar_jdk_libs in dependencies
        if "desugar_jdk_libs" not in content:
            desugar_dep = "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n"
            if "dependencies {" in content:
                content = re.sub(
                    r"(dependencies\s*\{)",
                    r"\1\n" + desugar_dep,
                    content,
                )
            else:
                content += f"\ndependencies {{\n{desugar_dep}}}\n"

        with open(app_gradle, "w", encoding="utf-8") as f:
            f.write(content)
        print("Patched compileSdk, multiDex, and desugaring in app/build.gradle")

if __name__ == "__main__":
    patch()
