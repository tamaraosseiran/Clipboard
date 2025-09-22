#!/usr/bin/env python3
"""
Complete the ShareExtension target configuration
"""

import re
import uuid

def generate_uuid():
    """Generate a UUID for Xcode project"""
    return str(uuid.uuid4()).replace('-', '').upper()[:24]

def complete_share_extension():
    """Complete the ShareExtension target configuration"""
    
    project_file = "Clipboard.xcodeproj/project.pbxproj"
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Generate UUIDs for missing components
    build_config_uuid = generate_uuid()
    sources_phase_uuid = generate_uuid()
    frameworks_phase_uuid = generate_uuid()
    resources_phase_uuid = generate_uuid()
    product_uuid = generate_uuid()
    swift_file_uuid = generate_uuid()
    storyboard_file_uuid = generate_uuid()
    icon_file_uuid = generate_uuid()
    info_plist_uuid = generate_uuid()
    
    # Add build phases
    build_phases_section = re.search(r'(/* Begin PBXSourcesBuildPhase section */.*?/* End PBXSourcesBuildPhase section */)', content, re.DOTALL)
    if build_phases_section:
        phases_section = build_phases_section.group(1)
        
        share_extension_phases = f"""
		{sources_phase_uuid} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{swift_file_uuid} /* ShareViewController.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{frameworks_phase_uuid} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{resources_phase_uuid} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{storyboard_file_uuid} /* MainInterface.storyboard in Resources */,
				{icon_file_uuid} /* ShareExtensionIcon.png in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};"""
        
        new_phases_section = phases_section.replace(
            "/* End PBXSourcesBuildPhase section */",
            f"{share_extension_phases}\n/* End PBXSourcesBuildPhase section */"
        )
        content = content.replace(phases_section, new_phases_section)
    
    # Add file references
    file_refs_section = re.search(r'(/* Begin PBXFileReference section */.*?/* End PBXFileReference section */)', content, re.DOTALL)
    if file_refs_section:
        refs_section = file_refs_section.group(1)
        
        share_extension_refs = f"""
		016547742E62440700C46AD8 /* Clipboard.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Clipboard.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{product_uuid} /* ShareExtension.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = ShareExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
		{swift_file_uuid} /* ShareViewController.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ShareViewController.swift; sourceTree = "<group>"; }};
		{storyboard_file_uuid} /* MainInterface.storyboard */ = {{isa = PBXFileReference; lastKnownFileType = file.storyboard; path = MainInterface.storyboard; sourceTree = "<group>"; }};
		{icon_file_uuid} /* ShareExtensionIcon.png */ = {{isa = PBXFileReference; lastKnownFileType = image.png; path = ShareExtensionIcon.png; sourceTree = "<group>"; }};
		{info_plist_uuid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};"""
        
        new_refs_section = refs_section.replace(
            "/* End PBXFileReference section */",
            f"{share_extension_refs}\n/* End PBXFileReference section */"
        )
        content = content.replace(refs_section, new_refs_section)
    
    # Add build configuration
    build_config_section = re.search(r'(/* Begin XCBuildConfiguration section */.*?/* End XCBuildConfiguration section */)', content, re.DOTALL)
    if build_config_section:
        config_section = build_config_section.group(1)
        
        share_extension_config = f"""
		{build_config_uuid} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
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
			}};
			name = Debug;
		}};
		{generate_uuid()} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
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
			}};
			name = Release;
		}};"""
        
        new_config_section = config_section.replace(
            "/* End XCBuildConfiguration section */",
            f"{share_extension_config}\n/* End XCBuildConfiguration section */"
        )
        content = content.replace(config_section, new_config_section)
    
    # Write the modified content
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("ShareExtension configuration completed!")
    return True

if __name__ == "__main__":
    complete_share_extension()
