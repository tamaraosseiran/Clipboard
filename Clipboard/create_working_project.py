#!/usr/bin/env python3
"""
Create a working Xcode project with ShareExtension properly configured
"""

import re
import uuid

def generate_uuid():
    """Generate a UUID for Xcode project"""
    return str(uuid.uuid4()).replace('-', '').upper()[:24]

def create_working_project():
    """Create a working project file with ShareExtension"""
    
    project_file = "Clipboard.xcodeproj/project.pbxproj"
    
    # Read the backup project file
    with open(project_file + ".backup", 'r') as f:
        content = f.read()
    
    # Remove the broken ShareExtension target
    content = re.sub(r'60D3E1B9FE0944D0B8BB9668 /\* ShareExtension \*/ = \{[^}]*\};\s*', '', content, flags=re.DOTALL)
    content = re.sub(r'60D3E1B9FE0944D0B8BB9668 /\* ShareExtension \*/,?\s*', '', content)
    
    # Generate UUIDs for ShareExtension
    target_uuid = generate_uuid()
    build_config_list_uuid = generate_uuid()
    debug_config_uuid = generate_uuid()
    release_config_uuid = generate_uuid()
    sources_phase_uuid = generate_uuid()
    frameworks_phase_uuid = generate_uuid()
    resources_phase_uuid = generate_uuid()
    product_uuid = generate_uuid()
    swift_file_uuid = generate_uuid()
    storyboard_file_uuid = generate_uuid()
    icon_file_uuid = generate_uuid()
    info_plist_uuid = generate_uuid()
    
    # Add ShareExtension target
    share_extension_target = f"""
		{target_uuid} /* ShareExtension */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {build_config_list_uuid} /* Build configuration list for PBXNativeTarget "ShareExtension" */;
			buildPhases = (
				{sources_phase_uuid} /* Sources */,
				{frameworks_phase_uuid} /* Frameworks */,
				{resources_phase_uuid} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = ShareExtension;
			productName = ShareExtension;
			productReference = {product_uuid} /* ShareExtension.appex */;
			productType = "com.apple.product-type.app-extension";
		}};"""
    
    # Insert ShareExtension target after main target
    main_target_pattern = r'(016547732E62440700C46AD8 /\* Clipboard \*/ = \{[^}]*\};\s*)(016547872E62440800C46AD8 /\* ClipboardTests \*/)'
    content = re.sub(main_target_pattern, r'\1' + share_extension_target + r'\n\t\t\2', content, flags=re.DOTALL)
    
    # Add to targets list
    targets_pattern = r'(targets = \(\s*016547732E62440700C46AD8 /\* Clipboard \*/,)'
    content = re.sub(targets_pattern, r'\1\n\t\t\t' + target_uuid + r' /* ShareExtension */,', content)
    
    # Add build phases
    sources_phase = f"""
		{sources_phase_uuid} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{swift_file_uuid} /* ShareViewController.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};"""
    
    frameworks_phase = f"""
		{frameworks_phase_uuid} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};"""
    
    resources_phase = f"""
		{resources_phase_uuid} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{storyboard_file_uuid} /* MainInterface.storyboard in Resources */,
				{icon_file_uuid} /* ShareExtensionIcon.png in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};"""
    
    # Add build phases to the appropriate sections
    content = re.sub(r'(/* End PBXSourcesBuildPhase section */)', sources_phase + r'\n\1', content)
    content = re.sub(r'(/* End PBXFrameworksBuildPhase section */)', frameworks_phase + r'\n\1', content)
    content = re.sub(r'(/* End PBXResourcesBuildPhase section */)', resources_phase + r'\n\1', content)
    
    # Add file references
    file_refs = f"""
		016547742E62440700C46AD8 /* Clipboard.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Clipboard.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{product_uuid} /* ShareExtension.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = ShareExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
		{swift_file_uuid} /* ShareViewController.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ShareViewController.swift; sourceTree = "<group>"; }};
		{storyboard_file_uuid} /* MainInterface.storyboard */ = {{isa = PBXFileReference; lastKnownFileType = file.storyboard; path = MainInterface.storyboard; sourceTree = "<group>"; }};
		{icon_file_uuid} /* ShareExtensionIcon.png */ = {{isa = PBXFileReference; lastKnownFileType = image.png; path = ShareExtensionIcon.png; sourceTree = "<group>"; }};
		{info_plist_uuid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};"""
    
    content = re.sub(r'(/* End PBXFileReference section */)', file_refs + r'\n\1', content)
    
    # Add build configuration list
    build_config_list = f"""
		{build_config_list_uuid} /* Build configuration list for PBXNativeTarget "ShareExtension" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_config_uuid} /* Debug */,
				{release_config_uuid} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};"""
    
    content = re.sub(r'(/* End XCConfigurationList section */)', build_config_list + r'\n\1', content)
    
    # Add build configurations
    debug_config = f"""
		{debug_config_uuid} /* Debug */ = {{
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
		}};"""
    
    release_config = f"""
		{release_config_uuid} /* Release */ = {{
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
    
    content = re.sub(r'(/* End XCBuildConfiguration section */)', debug_config + release_config + r'\n\1', content)
    
    # Write the new project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("Working project file created!")
    return True

if __name__ == "__main__":
    create_working_project()






