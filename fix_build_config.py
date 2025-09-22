#!/usr/bin/env python3
"""
Fix ShareExtension build configuration
"""

import re

def fix_build_config():
    """Add missing build configuration for ShareExtension"""
    
    project_file = "Clipboard.xcodeproj/project.pbxproj"
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Add build configuration list for ShareExtension
    build_config_list = """
		5EC26EDF031149CC90C5184B /* Build configuration list for PBXNativeTarget "ShareExtension" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				5EC26EDE031149CC90C5184B /* Debug */,
				5EC26EDD031149CC90C5184B /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};"""
    
    # Add build configurations for ShareExtension
    share_extension_debug_config = """
		5EC26EDE031149CC90C5184B /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 4J6264AA5S;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = ShareExtension/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = "Save to Clipboard";
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				IPHONEOS_DEPLOYMENT_TARGET = 18.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.tamaraosseiran.Clipboard.ShareExtension;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};"""
    
    share_extension_release_config = """
		5EC26EDD031149CC90C5184B /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 4J6264AA5S;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = ShareExtension/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = "Save to Clipboard";
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				IPHONEOS_DEPLOYMENT_TARGET = 18.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.tamaraosseiran.Clipboard.ShareExtension;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};"""
    
    # Find the XCConfigurationList section and add the build configuration list
    config_list_pattern = r'(/* Begin XCConfigurationList section */.*?/* End XCConfigurationList section */)'
    config_list_match = re.search(config_list_pattern, content, re.DOTALL)
    
    if config_list_match:
        config_list_section = config_list_match.group(1)
        new_config_list_section = config_list_section.replace(
            "/* End XCConfigurationList section */",
            f"{build_config_list}\n/* End XCConfigurationList section */"
        )
        content = content.replace(config_list_section, new_config_list_section)
    
    # Find the XCBuildConfiguration section and add the build configurations
    build_config_pattern = r'(/* Begin XCBuildConfiguration section */.*?/* End XCBuildConfiguration section */)'
    build_config_match = re.search(build_config_pattern, content, re.DOTALL)
    
    if build_config_match:
        build_config_section = build_config_match.group(1)
        new_build_config_section = build_config_section.replace(
            "/* End XCBuildConfiguration section */",
            f"{share_extension_debug_config}\n{share_extension_release_config}\n/* End XCBuildConfiguration section */"
        )
        content = content.replace(build_config_section, new_build_config_section)
    
    # Write the modified content
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("ShareExtension build configuration added!")
    return True

if __name__ == "__main__":
    fix_build_config()
