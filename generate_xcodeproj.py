#!/usr/bin/env python3
import os
import uuid
import sys

def gen_id():
    # Xcode uses 24-char hex strings for IDs
    return uuid.uuid4().hex[:24].upper()

def main():
    project_dir = os.path.dirname(os.path.abspath(__file__))
    sources_dir = os.path.join(project_dir, "Sources", "Fortress")
    
    if not os.path.exists(sources_dir):
        print(f"Error: Sources directory not found at {sources_dir}")
        sys.exit(1)
        
    print("Scanning project files...")
    swift_files = []
    all_files = []
    for root, dirs, files in os.walk(sources_dir):
        for f in files:
            if f.endswith(".swift") or f.endswith(".entitlements"):
                rel_path = os.path.relpath(os.path.join(root, f), project_dir)
                all_files.append(rel_path)
                if f.endswith(".swift"):
                    swift_files.append(rel_path)
                
    print(f"Found {len(swift_files)} Swift source files, {len(all_files) - len(swift_files)} other configuration files.")
    
    # Generate UUIDs for all elements
    proj_id = gen_id()
    main_group_id = gen_id()
    sources_group_id = gen_id()
    products_group_id = gen_id()
    target_id = gen_id()
    target_ref_id = gen_id()
    sources_build_phase_id = gen_id()
    frameworks_build_phase_id = gen_id()
    resources_build_phase_id = gen_id()
    
    config_list_target_id = gen_id()
    config_list_project_id = gen_id()
    
    debug_config_target_id = gen_id()
    release_config_target_id = gen_id()
    debug_config_project_id = gen_id()
    release_config_project_id = gen_id()
    
    app_product_id = gen_id()
    
    # File refs and build files
    file_refs = {}
    build_files = {}
    
    for f in all_files:
        file_refs[f] = gen_id()
    for f in swift_files:
        build_files[f] = gen_id()
        
    # Group construction
    # We will put all files in the "Sources/Fortress" group recursively.
    # Group hierarchy mapping:
    group_ids = {"Sources": sources_group_id}
    
    # Generate keys for folders
    for f in all_files:
        parts = os.path.dirname(f).split(os.sep)
        curr = ""
        for part in parts:
            if not part: continue
            prev = curr
            curr = os.path.join(curr, part) if curr else part
            if curr not in group_ids:
                group_ids[curr] = gen_id()

    # Generate the pbxproj content
    out = []
    out.append("// !$*UTF8*$!")
    out.append("{")
    out.append("\tarchiveVersion = 1;")
    out.append("\tclasses = {")
    out.append("\t};")
    out.append("\tobjectVersion = 56;")
    out.append("\tobjects = {")
    out.append("")
    
    # PBXBuildFile
    out.append("/* Begin PBXBuildFile section */")
    for f in swift_files:
        out.append(f"\t\t{build_files[f]} /* {os.path.basename(f)} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {os.path.basename(f)} */; }};")
    out.append("/* End PBXBuildFile section */")
    out.append("")
    
    # PBXFileReference
    out.append("/* Begin PBXFileReference section */")
    out.append(f"\t\t{app_product_id} /* Fortress.app */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.application\"; includeInIndex = 0; path = \"Fortress.app\"; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for f in all_files:
        name = os.path.basename(f)
        file_type = "source.swift" if f.endswith(".swift") else "text.plist.entitlements"
        out.append(f"\t\t{file_refs[f]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = \"{file_type}\"; name = \"{name}\"; path = \"{f}\"; sourceTree = SOURCE_ROOT; }};")
    out.append("/* End PBXFileReference section */")
    out.append("")
    
    # PBXFrameworksBuildPhase
    out.append("/* Begin PBXFrameworksBuildPhase section */")
    out.append(f"\t\t{frameworks_build_phase_id} /* Frameworks */ = {{")
    out.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")
    out.append("/* End PBXFrameworksBuildPhase section */")
    out.append("")
    
    # PBXGroup
    out.append("/* Begin PBXGroup section */")
    
    # Root Group
    out.append(f"\t\t{main_group_id} = {{")
    out.append("\t\t\tisa = PBXGroup;")
    out.append("\t\t\tchildren = (")
    out.append(f"\t\t\t\t{group_ids['Sources']} /* Sources */,")
    out.append(f"\t\t\t\t{products_group_id} /* Products */,")
    out.append("\t\t\t);")
    out.append("\t\t\tsourceTree = \"<group>\";")
    out.append("\t\t};")
    
    # Products Group
    out.append(f"\t\t{products_group_id} /* Products */ = {{")
    out.append("\t\t\tisa = PBXGroup;")
    out.append("\t\t\tchildren = (")
    out.append(f"\t\t\t\t{app_product_id} /* Fortress.app */,")
    out.append("\t\t\t);")
    out.append("\t\t\tname = Products;")
    out.append("\t\t\tsourceTree = \"<group>\";")
    out.append("\t\t};")
    
    # Subgroups
    for path, gid in sorted(group_ids.items(), key=lambda x: len(x[0])):
        # Find children of this path
        children = []
        # Find subfolders
        for subpath, subgid in group_ids.items():
            if os.path.dirname(subpath) == path:
                children.append(f"\t\t\t\t{subgid} /* {os.path.basename(subpath)} */,")
        # Find files directly in this path
        for f in all_files:
            if os.path.dirname(f) == path:
                children.append(f"\t\t\t\t{file_refs[f]} /* {os.path.basename(f)} */,")
                
        out.append(f"\t\t{gid} /* {os.path.basename(path)} */ = {{")
        out.append("\t\t\tisa = PBXGroup;")
        out.append("\t\t\tchildren = (")
        for child in children:
            out.append(child)
        out.append("\t\t\t);")
        out.append(f"\t\t\tname = \"{os.path.basename(path)}\";")
        if path == "Sources":
            out.append("\t\t\tpath = Sources;")
        out.append("\t\t\tsourceTree = \"<group>\";")
        out.append("\t\t};")
        
    out.append("/* End PBXGroup section */")
    out.append("")
    
    # PBXNativeTarget
    out.append("/* Begin PBXNativeTarget section */")
    out.append(f"\t\t{target_id} /* Fortress */ = {{")
    out.append("\t\t\tisa = PBXNativeTarget;")
    out.append(f"\t\t\tbuildConfigurationList = {config_list_target_id} /* Build configuration list for PBXNativeTarget \"Fortress\" */;")
    out.append("\t\t\tbuildPhases = (")
    out.append(f"\t\t\t\t{sources_build_phase_id} /* Sources */,")
    out.append(f"\t\t\t\t{frameworks_build_phase_id} /* Frameworks */,")
    out.append(f"\t\t\t\t{resources_build_phase_id} /* Resources */,")
    out.append("\t\t\t);")
    out.append("\t\t\tbuildRules = (")
    out.append("\t\t\t);")
    out.append("\t\t\tdependencies = (")
    out.append("\t\t\t);")
    out.append("\t\t\tname = Fortress;")
    out.append("\t\t\tproductName = Fortress;")
    out.append(f"\t\t\tproductReference = {app_product_id} /* Fortress.app */;")
    out.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    out.append("\t\t};")
    out.append("/* End PBXNativeTarget section */")
    out.append("")
    
    # PBXProject
    out.append("/* Begin PBXProject section */")
    out.append(f"\t\t{proj_id} /* Project object */ = {{")
    out.append("\t\t\tisa = PBXProject;")
    out.append("\t\t\tattributes = {")
    out.append("\t\t\t\tBuildIndependentTargetsInParallel = YES;")
    out.append("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    out.append("\t\t\t\tLastUpgradeCheck = 1500;")
    out.append("\t\t\t\tTargetAttributes = {")
    out.append(f"\t\t\t\t\t{target_id} = {{")
    out.append("\t\t\t\t\t\tCreatedOnToolsVersion = \"15.0\";")
    out.append("\t\t\t\t\t\tDevelopmentTeam = \"\";")
    out.append("\t\t\t\t\t};")
    out.append("\t\t\t\t};")
    out.append("\t\t\t};")
    out.append(f"\t\t\tbuildConfigurationList = {config_list_project_id} /* Build configuration list for PBXProject \"Fortress\" */;")
    out.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    out.append("\t\t\tdevelopmentRegion = en;")
    out.append("\t\t\thasScannedForEncodings = 0;")
    out.append("\t\t\tknownRegions = (")
    out.append("\t\t\t\ten,")
    out.append("\t\t\t\tBase,")
    out.append("\t\t\t);")
    out.append(f"\t\t\tmainGroup = {main_group_id};")
    out.append(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    out.append("\t\t\tprojectDirPath = \"\";")
    out.append("\t\t\tprojectRoot = \"\";")
    out.append("\t\t\ttargets = (")
    out.append(f"\t\t\t\t{target_id} /* Fortress */,")
    out.append("\t\t\t);")
    out.append("\t\t};")
    out.append("/* End PBXProject section */")
    out.append("")
    
    # PBXResourcesBuildPhase
    out.append("/* Begin PBXResourcesBuildPhase section */")
    out.append(f"\t\t{resources_build_phase_id} /* Resources */ = {{")
    out.append("\t\t\tisa = PBXResourcesBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")
    out.append("/* End PBXResourcesBuildPhase section */")
    out.append("")
    
    # PBXSourcesBuildPhase
    out.append("/* Begin PBXSourcesBuildPhase section */")
    out.append(f"\t\t{sources_build_phase_id} /* Sources */ = {{")
    out.append("\t\t\tisa = PBXSourcesBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    for f in swift_files:
        out.append(f"\t\t\t\t{build_files[f]} /* {os.path.basename(f)} in Sources */,")
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")
    out.append("/* End PBXSourcesBuildPhase section */")
    out.append("")
    
    # XCBuildConfiguration
    out.append("/* Begin XCBuildConfiguration section */")
    out.append(f"\t\t{debug_config_project_id} /* Debug */ = {{")
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    out.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    out.append("\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
    out.append("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
    out.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    out.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    out.append("\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
    out.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    out.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
    out.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
    out.append("\t\t\t\tENABLE_TESTABILITY = YES;")
    out.append("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;")
    out.append("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
    out.append("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
    out.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
    out.append("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
    out.append("\t\t\t\t\t\"DEBUG=1\",")
    out.append("\t\t\t\t\t\"$(inherited)\",")
    out.append("\t\t\t\t);")
    out.append("\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;")
    out.append("\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;")
    out.append("\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;")
    out.append("\t\t\t\tGCC_WARN_UNINITIALIZED_ACTUAL = YES_AGGRESSIVE;")
    out.append("\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;")
    out.append("\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;")
    out.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
    out.append("\t\t\t\tMTL_FAST_MATH = YES;")
    out.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
    out.append("\t\t\t\tSDKROOT = macosx;")
    out.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = \"26.0\";")
    out.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = \"26.0\";")
    out.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
    out.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
    out.append("\t\t\t};")
    out.append("\t\t\tname = Debug;")
    out.append("\t\t};")
    
    out.append(f"\t\t{release_config_project_id} /* Release */ = {{")
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    out.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    out.append("\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
    out.append("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
    out.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    out.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    out.append("\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
    out.append("\t\t\t\tCOPY_PHASE_STRIP = YES;")
    out.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
    out.append("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
    out.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
    out.append("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;")
    out.append("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
    out.append("\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;")
    out.append("\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;")
    out.append("\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;")
    out.append("\t\t\t\tGCC_WARN_UNINITIALIZED_ACTUAL = YES_AGGRESSIVE;")
    out.append("\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;")
    out.append("\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;")
    out.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
    out.append("\t\t\t\tMTL_FAST_MATH = YES;")
    out.append("\t\t\t\tSDKROOT = macosx;")
    out.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = \"26.0\";")
    out.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = \"26.0\";")
    out.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    out.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
    out.append("\t\t\t};")
    out.append("\t\t\tname = Release;")
    out.append("\t\t};")
    
    out.append(f"\t\t{debug_config_target_id} /* Debug */ = {{")
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    out.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
    out.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    out.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    out.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
    out.append("\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = Fortress;")
    out.append("\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = \"public.app-category.developer-tools\";")
    out.append("\t\t\t\tINFOPLIST_KEY_NSFaceIDUsageDescription = \"Fortress uses Face ID to securely unlock your vault.\";")
    out.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    out.append("\t\t\t\t\t\"$(inherited)\",")
    out.append("\t\t\t\t\t\"@executable_path/Frameworks\",")
    out.append("\t\t\t\t);")
    out.append("\t\t\t\tMARKETING_VERSION = \"1.0\";")
    out.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"com.fortress.app\";")
    out.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    out.append("\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator xros xrsimulator\";")
    out.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
    # out.append("\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"Sources/Fortress/Fortress.entitlements\";")
    out.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = \"26.0\";")
    out.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = \"26.0\";")
    out.append("\t\t\t\tSWIFT_VERSION = \"5.9\";")
    out.append("\t\t\t};")
    out.append("\t\t\tname = Debug;")
    out.append("\t\t};")
    
    out.append(f"\t\t{release_config_target_id} /* Release */ = {{")
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    out.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
    out.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    out.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    out.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
    out.append("\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = Fortress;")
    out.append("\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = \"public.app-category.developer-tools\";")
    out.append("\t\t\t\tINFOPLIST_KEY_NSFaceIDUsageDescription = \"Fortress uses Face ID to securely unlock your vault.\";")
    out.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    out.append("\t\t\t\t\t\"$(inherited)\",")
    out.append("\t\t\t\t\t\"@executable_path/Frameworks\",")
    out.append("\t\t\t\t);")
    out.append("\t\t\t\tMARKETING_VERSION = \"1.0\";")
    out.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"com.fortress.app\";")
    out.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    out.append("\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator xros xrsimulator\";")
    out.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
    # out.append("\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"Sources/Fortress/Fortress.entitlements\";")
    out.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = \"26.0\";")
    out.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = \"26.0\";")
    out.append("\t\t\t\tSWIFT_VERSION = \"5.9\";")
    out.append("\t\t\t};")
    out.append("\t\t\tname = Release;")
    out.append("\t\t};")
    out.append("/* End XCBuildConfiguration section */")
    out.append("")
    
    # XCConfigurationList
    out.append("/* Begin XCConfigurationList section */")
    out.append(f"\t\t{config_list_project_id} /* Build configuration list for PBXProject \"Fortress\" */ = {{")
    out.append("\t\t\tisa = XCConfigurationList;")
    out.append("\t\t\tbuildConfigurations = (")
    out.append(f"\t\t\t\t{debug_config_project_id} /* Debug */,")
    out.append(f"\t\t\t\t{release_config_project_id} /* Release */,")
    out.append("\t\t\t);")
    out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    out.append("\t\t\tdefaultConfigurationName = Release;")
    out.append("\t\t};")
    
    out.append(f"\t\t{config_list_target_id} /* Build configuration list for PBXNativeTarget \"Fortress\" */ = {{")
    out.append("\t\t\tisa = XCConfigurationList;")
    out.append("\t\t\tbuildConfigurations = (")
    out.append(f"\t\t\t\t{debug_config_target_id} /* Debug */,")
    out.append(f"\t\t\t\t{release_config_target_id} /* Release */,")
    out.append("\t\t\t);")
    out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    out.append("\t\t\tdefaultConfigurationName = Release;")
    out.append("\t\t};")
    out.append("/* End XCConfigurationList section */")
    
    out.append("\t};")
    out.append(f"\trootObject = {proj_id} /* Project object */;")
    out.append("}")
    
    # Write files
    xcodeproj_dir = os.path.join(project_dir, "Fortress.xcodeproj")
    os.makedirs(xcodeproj_dir, exist_ok=True)
    
    pbxproj_path = os.path.join(xcodeproj_dir, "project.pbxproj")
    with open(pbxproj_path, "w") as f:
        f.write("\n".join(out))
    print(f"Generated {pbxproj_path}")
    
    # Write Workspace file
    workspace_dir = os.path.join(xcodeproj_dir, "project.xcworkspace")
    os.makedirs(workspace_dir, exist_ok=True)
    workspace_path = os.path.join(workspace_dir, "contents.xcworkspacedata")
    workspace_content = """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""
    with open(workspace_path, "w") as f:
        f.write(workspace_content)
    print(f"Generated {workspace_path}")
    print("Xcode project generated successfully!")

if __name__ == "__main__":
    main()
