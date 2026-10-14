import os
import re

def patch():
    # 1. Patch Info.plist with location permissions and app display name
    info_plist_path = "ios/Runner/Info.plist"
    if os.path.exists(info_plist_path):
        with open(info_plist_path, "r", encoding="utf-8") as f:
            content = f.read()

        ios_entries = """\t<key>CFBundleDisplayName</key>
\t<string>Spor</string>
\t<key>NSLocationWhenInUseUsageDescription</key>
\t<string>Spor bruger din placering til at finde stoppesteder og stationer i nærheden.</string>
\t<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
\t<string>Spor bruger din placering til at finde stoppesteder og levere rejseopdateringer.</string>
\t<key>NSCalendarsUsageDescription</key>
\t<string>Spor bruger din kalender til at tilføje rejser og påmindelser.</string>
\t<key>NSCalendarsWriteOnlyAccessUsageDescription</key>
\t<string>Spor bruger din kalender til at tilføje rejser og påmindelser.</string>
\t<key>NSCalendarsFullAccessUsageDescription</key>
\t<string>Spor bruger din kalender til at tilføje rejser og påmindelser.</string>
"""
        if "NSLocationWhenInUseUsageDescription" not in content:
            # Insert right before </dict></plist>
            content = content.replace("</dict>\n</plist>", ios_entries + "</dict>\n</plist>")
            if "</dict>\n</plist>" not in content:
                content = content.replace("</dict></plist>", ios_entries + "</dict></plist>")
            content = re.sub(r'<key>CFBundleName</key>\s*<string>[^<]*</string>', '<key>CFBundleName</key>\n\t<string>Spor</string>', content)
            with open(info_plist_path, "w", encoding="utf-8") as f:
                f.write(content)
            print("Patched ios/Runner/Info.plist with location, calendar permissions and display name Spor")

    # 2. Patch Podfile to enforce iOS deployment target >= 13.0
    podfile_path = "ios/Podfile"
    if os.path.exists(podfile_path):
        with open(podfile_path, "r", encoding="utf-8") as f:
            pod_content = f.read()

        # Uncomment or update platform line
        pod_content = re.sub(
            r"#?\s*platform\s*:ios\s*,\s*['\"][^'\"]+['\"]",
            "platform :ios, '13.0'",
            pod_content
        )
        if "platform :ios" not in pod_content:
            pod_content = "platform :ios, '13.0'\n" + pod_content

        # Ensure post_install sets IPHONEOS_DEPLOYMENT_TARGET
        deployment_target_snippet = """
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end"""

        if "IPHONEOS_DEPLOYMENT_TARGET" not in pod_content and "flutter_additional_ios_build_settings" in pod_content:
            pod_content = pod_content.replace(
                "flutter_additional_ios_build_settings(target)",
                "flutter_additional_ios_build_settings(target)" + deployment_target_snippet
            )

        with open(podfile_path, "w", encoding="utf-8") as f:
            f.write(pod_content)
        print("Patched ios/Podfile with iOS 13.0 deployment target")

    # 3. Copy custom Spor iOS AppIcon to ios/Runner/Assets.xcassets/AppIcon.appiconset
    import shutil
    src_appicon = "assets/ios/AppIcon.appiconset"
    dst_appicon = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    if os.path.exists(src_appicon):
        os.makedirs(dst_appicon, exist_ok=True)
        for f in os.listdir(src_appicon):
            src_file = os.path.join(src_appicon, f)
            dst_file = os.path.join(dst_appicon, f)
            if os.path.isfile(src_file):
                shutil.copy2(src_file, dst_file)
        print("Copied custom Spor iOS app icons to ios/Runner/Assets.xcassets/AppIcon.appiconset")

    # 4. Enforce PRODUCT_BUNDLE_IDENTIFIER in project.pbxproj to com.spor.mobile
    pbxproj_path = "ios/Runner.xcodeproj/project.pbxproj"
    if os.path.exists(pbxproj_path):
        with open(pbxproj_path, "r", encoding="utf-8") as f:
            pbx_content = f.read()
        pbx_content = re.sub(
            r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*[^;]+;',
            'PRODUCT_BUNDLE_IDENTIFIER = com.spor.mobile;',
            pbx_content
        )
        with open(pbxproj_path, "w", encoding="utf-8") as f:
            f.write(pbx_content)
        print("Patched PRODUCT_BUNDLE_IDENTIFIER to com.spor.mobile in project.pbxproj")

if __name__ == "__main__":
    patch()
