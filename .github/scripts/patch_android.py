import os
import re

def patch():
    # 1. Add location & internet permissions to AndroidManifest.xml
    manifest_path = "android/app/src/main/AndroidManifest.xml"
    if os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            content = f.read()
        perms = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
"""
        if "android.permission.ACCESS_FINE_LOCATION" not in content:
            content = content.replace("<application", perms + "    <application")
            with open(manifest_path, "w", encoding="utf-8") as f:
                f.write(content)
        print("Patched AndroidManifest.xml")

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

    # 3. Upgrade compileSdkVersion to 34 in app/build.gradle
    app_gradle = "android/app/build.gradle"
    if os.path.exists(app_gradle):
        with open(app_gradle, "r", encoding="utf-8") as f:
            content = f.read()
        content = re.sub(r"compileSdk(?:Version)?\s*=?\s*\d+", "compileSdkVersion 34", content)
        content = re.sub(r"targetSdk(?:Version)?\s*=?\s*\d+", "targetSdkVersion 34", content)
        with open(app_gradle, "w", encoding="utf-8") as f:
            f.write(content)
        print("Patched compileSdkVersion 34 in app/build.gradle")

if __name__ == "__main__":
    patch()
