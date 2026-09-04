#!/usr/bin/env python3
"""Applique le patch pbxproj WoopUITests (famille C0...) par ancres EXACTES.
Refuse d'ecrire si une ancre manque ou si un UUID C0 existe deja.
Usage: applique_patch.py <chemin project.pbxproj>"""
import sys

chemin = sys.argv[1]
src = open(chemin, encoding="utf-8").read()

if "C0000000" in src:
    print("REFUS : des UUID C0... existent deja"); sys.exit(2)

T = "\t"  # le pbxproj est indente en tabulations


def inserer(texte, ancre, bloc, avant=False):
    if ancre not in texte:
        print(f"ANCRE ABSENTE : {ancre[:60]!r}"); sys.exit(2)
    if texte.count(ancre) != 1:
        print(f"ANCRE AMBIGUE ({texte.count(ancre)} fois) : {ancre[:60]!r}"); sys.exit(2)
    return texte.replace(ancre, (bloc + ancre) if avant else (ancre + bloc))


# 1) PBXContainerItemProxy — apres le proxy WoopWidgets
p1 = f"""{T}{T}C0000000000000000000000D /* PBXContainerItemProxy */ = {{
{T}{T}{T}isa = PBXContainerItemProxy;
{T}{T}{T}containerPortal = A0000000000000000000000B /* Project object */;
{T}{T}{T}proxyType = 1;
{T}{T}{T}remoteGlobalIDString = A00000000000000000000006;
{T}{T}{T}remoteInfo = Woop;
{T}{T}}};
"""
src = inserer(src, "/* End PBXContainerItemProxy section */", p1, avant=True)

# 2) PBXFileReference — apres WoopWidgets.appex
p2 = f"""{T}{T}C00000000000000000000001 /* WoopUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = WoopUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
"""
src = inserer(src, "/* End PBXFileReference section */", p2, avant=True)

# 3) PBXFileSystemSynchronizedRootGroup — apres WoopShared
p3 = f"""{T}{T}C00000000000000000000002 /* WoopUITests */ = {{isa = PBXFileSystemSynchronizedRootGroup; explicitFileTypes = {{}}; explicitFolders = (); path = WoopUITests; sourceTree = "<group>"; }};
"""
src = inserer(src, "/* End PBXFileSystemSynchronizedRootGroup section */", p3, avant=True)

# 4a) groupe racine : la ligne AVANT Products
src = inserer(src,
    f"{T}{T}{T}{T}A00000000000000000000004 /* Products */,\n{T}{T}{T});\n{T}{T}{T}sourceTree = \"<group>\";\n{T}{T}}};\n{T}{T}A00000000000000000000004",
    "", avant=False)  # sonde d'existence seulement
src = src.replace(
    f"{T}{T}{T}{T}B00000000000000000000002 /* WoopWidgets */,\n{T}{T}{T}{T}A00000000000000000000004 /* Products */,",
    f"{T}{T}{T}{T}B00000000000000000000002 /* WoopWidgets */,\n{T}{T}{T}{T}C00000000000000000000002 /* WoopUITests */,\n{T}{T}{T}{T}A00000000000000000000004 /* Products */,",
    1)
# 4b) Products : le .xctest
src = src.replace(
    f"{T}{T}{T}{T}B00000000000000000000001 /* WoopWidgets.appex */,\n{T}{T}{T});\n{T}{T}{T}name = Products;",
    f"{T}{T}{T}{T}B00000000000000000000001 /* WoopWidgets.appex */,\n{T}{T}{T}{T}C00000000000000000000001 /* WoopUITests.xctest */,\n{T}{T}{T});\n{T}{T}{T}name = Products;",
    1)

# 5) PBXNativeTarget — apres WoopWidgets
p5 = f"""{T}{T}C00000000000000000000004 /* WoopUITests */ = {{
{T}{T}{T}isa = PBXNativeTarget;
{T}{T}{T}buildConfigurationList = C00000000000000000000005 /* Build configuration list for PBXNativeTarget "WoopUITests" */;
{T}{T}{T}buildPhases = (
{T}{T}{T}{T}C00000000000000000000008 /* Sources */,
{T}{T}{T}{T}C00000000000000000000009 /* Frameworks */,
{T}{T}{T}{T}C0000000000000000000000A /* Resources */,
{T}{T}{T});
{T}{T}{T}buildRules = (
{T}{T}{T});
{T}{T}{T}dependencies = (
{T}{T}{T}{T}C0000000000000000000000E /* PBXTargetDependency */,
{T}{T}{T});
{T}{T}{T}fileSystemSynchronizedGroups = (
{T}{T}{T}{T}C00000000000000000000002 /* WoopUITests */,
{T}{T}{T});
{T}{T}{T}name = WoopUITests;
{T}{T}{T}packageProductDependencies = (
{T}{T}{T});
{T}{T}{T}productName = WoopUITests;
{T}{T}{T}productReference = C00000000000000000000001 /* WoopUITests.xctest */;
{T}{T}{T}productType = "com.apple.product-type.bundle.ui-testing";
{T}{T}}};
"""
src = inserer(src, "/* End PBXNativeTarget section */", p5, avant=True)

# 6a) TargetAttributes
src = src.replace(
    f"{T}{T}{T}{T}{T}B00000000000000000000004 = {{\n{T}{T}{T}{T}{T}{T}CreatedOnToolsVersion = 26.0;\n{T}{T}{T}{T}{T}}};",
    f"{T}{T}{T}{T}{T}B00000000000000000000004 = {{\n{T}{T}{T}{T}{T}{T}CreatedOnToolsVersion = 26.0;\n{T}{T}{T}{T}{T}}};\n{T}{T}{T}{T}{T}C00000000000000000000004 = {{\n{T}{T}{T}{T}{T}{T}CreatedOnToolsVersion = 26.0;\n{T}{T}{T}{T}{T}{T}TestTargetID = A00000000000000000000006;\n{T}{T}{T}{T}{T}}};",
    1)
# 6b) targets
src = src.replace(
    f"{T}{T}{T}{T}B00000000000000000000004 /* WoopWidgets */,\n{T}{T}{T});\n{T}{T}}};\n/* End PBXProject section */",
    f"{T}{T}{T}{T}B00000000000000000000004 /* WoopWidgets */,\n{T}{T}{T}{T}C00000000000000000000004 /* WoopUITests */,\n{T}{T}{T});\n{T}{T}}};\n/* End PBXProject section */",
    1)

# 7) les trois build phases
p7s = f"""{T}{T}C00000000000000000000008 /* Sources */ = {{
{T}{T}{T}isa = PBXSourcesBuildPhase;
{T}{T}{T}buildActionMask = 2147483647;
{T}{T}{T}files = (
{T}{T}{T});
{T}{T}{T}runOnlyForDeploymentPostprocessing = 0;
{T}{T}}};
"""
src = inserer(src, "/* End PBXSourcesBuildPhase section */", p7s, avant=True)
p7f = f"""{T}{T}C00000000000000000000009 /* Frameworks */ = {{
{T}{T}{T}isa = PBXFrameworksBuildPhase;
{T}{T}{T}buildActionMask = 2147483647;
{T}{T}{T}files = (
{T}{T}{T});
{T}{T}{T}runOnlyForDeploymentPostprocessing = 0;
{T}{T}}};
"""
src = inserer(src, "/* End PBXFrameworksBuildPhase section */", p7f, avant=True)
p7r = f"""{T}{T}C0000000000000000000000A /* Resources */ = {{
{T}{T}{T}isa = PBXResourcesBuildPhase;
{T}{T}{T}buildActionMask = 2147483647;
{T}{T}{T}files = (
{T}{T}{T});
{T}{T}{T}runOnlyForDeploymentPostprocessing = 0;
{T}{T}}};
"""
src = inserer(src, "/* End PBXResourcesBuildPhase section */", p7r, avant=True)

# 8) PBXTargetDependency
p8 = f"""{T}{T}C0000000000000000000000E /* PBXTargetDependency */ = {{
{T}{T}{T}isa = PBXTargetDependency;
{T}{T}{T}target = A00000000000000000000006 /* Woop */;
{T}{T}{T}targetProxy = C0000000000000000000000D /* PBXContainerItemProxy */;
{T}{T}}};
"""
src = inserer(src, "/* End PBXTargetDependency section */", p8, avant=True)

# 9) XCBuildConfiguration : Debug + Release (COMPLETS tous les deux)
reglages = f"""{T}{T}{T}{T}CODE_SIGN_STYLE = Automatic;
{T}{T}{T}{T}CURRENT_PROJECT_VERSION = 1;
{T}{T}{T}{T}DEVELOPMENT_TEAM = V45F4LUU8D;
{T}{T}{T}{T}GENERATE_INFOPLIST_FILE = YES;
{T}{T}{T}{T}IPHONEOS_DEPLOYMENT_TARGET = 26.0;
{T}{T}{T}{T}MARKETING_VERSION = 1.0;
{T}{T}{T}{T}PRODUCT_BUNDLE_IDENTIFIER = fr.kathryn.woop.WoopUITests;
{T}{T}{T}{T}PRODUCT_NAME = "$(TARGET_NAME)";
{T}{T}{T}{T}SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
{T}{T}{T}{T}SWIFT_EMIT_LOC_STRINGS = NO;
{T}{T}{T}{T}SWIFT_VERSION = 5.0;
{T}{T}{T}{T}TARGETED_DEVICE_FAMILY = 1;
{T}{T}{T}{T}TEST_TARGET_NAME = Woop;
"""
p9 = (f"{T}{T}C00000000000000000000006 /* Debug */ = {{\n"
      f"{T}{T}{T}isa = XCBuildConfiguration;\n"
      f"{T}{T}{T}buildSettings = {{\n{reglages}{T}{T}{T}}};\n"
      f"{T}{T}{T}name = Debug;\n{T}{T}}};\n"
      f"{T}{T}C00000000000000000000007 /* Release */ = {{\n"
      f"{T}{T}{T}isa = XCBuildConfiguration;\n"
      f"{T}{T}{T}buildSettings = {{\n{reglages}{T}{T}{T}}};\n"
      f"{T}{T}{T}name = Release;\n{T}{T}}};\n")
src = inserer(src, "/* End XCBuildConfiguration section */", p9, avant=True)

# 10) XCConfigurationList
p10 = f"""{T}{T}C00000000000000000000005 /* Build configuration list for PBXNativeTarget "WoopUITests" */ = {{
{T}{T}{T}isa = XCConfigurationList;
{T}{T}{T}buildConfigurations = (
{T}{T}{T}{T}C00000000000000000000006 /* Debug */,
{T}{T}{T}{T}C00000000000000000000007 /* Release */,
{T}{T}{T});
{T}{T}{T}defaultConfigurationIsVisible = 0;
{T}{T}{T}defaultConfigurationName = Release;
{T}{T}}};
"""
src = inserer(src, "/* End XCConfigurationList section */", p10, avant=True)

# Verifs finales : chaque remplacement non-inserer a bien eu lieu
for temoin in ("C00000000000000000000002 /* WoopUITests */,",
               "C00000000000000000000001 /* WoopUITests.xctest */,",
               "TestTargetID = A00000000000000000000006;",
               "C00000000000000000000004 /* WoopUITests */,"):
    if temoin not in src:
        print(f"REMPLACEMENT MANQUE : {temoin}"); sys.exit(2)

open(chemin, "w", encoding="utf-8").write(src)
print("PATCH APPLIQUE")
