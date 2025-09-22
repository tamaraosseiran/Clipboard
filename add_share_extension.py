#!/usr/bin/env python3
"""
Script to add ShareExtension target to Xcode project
"""

import re
import uuid

def generate_uuid():
    """Generate a UUID for Xcode project"""
    return str(uuid.uuid4()).replace('-', '').upper()[:24]

def add_share_extension_target(project_file):
    """Add ShareExtension target to the Xcode project"""
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Generate UUIDs for the new target
    target_uuid = generate_uuid()
    build_phase_uuid = generate_uuid()
    build_file_uuid = generate_uuid()
    group_uuid = generate_uuid()
    file_ref_uuid = generate_uuid()
    info_plist_uuid = generate_uuid()
    storyboard_uuid = generate_uuid()
    swift_file_uuid = generate_uuid()
    icon_uuid = generate_uuid()
    
    # Find the main target UUID
    main_target_match = re.search(r'Clipboard.*=.*{.*isa = PBXNativeTarget;.*name = Clipboard;.*productName = Clipboard;.*productReference = ([A-F0-9]{24});', content, re.DOTALL)
    if not main_target_match:
        print("Could not find main target")
        return False
    
    main_target_uuid = main_target_match.group(1)
    
    # Add ShareExtension target to the targets list
    targets_section = re.search(r'(/* Begin PBXNativeTarget section */.*?/* End PBXNativeTarget section */)', content, re.DOTALL)
    if targets_section:
        target_section = targets_section.group(1)
        
        # Add ShareExtension target
        share_extension_target = f"""
		016547732E62440700C46AD8 /* Clipboard */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = 0165478A2E62440800C46AD8 /* Build configuration list for PBXNativeTarget "Clipboard" */;
			buildPhases = (
				016547702E62440700C46AD8 /* Sources */,
				016547712E62440700C46AD8 /* Frameworks */,
				016547722E62440700C46AD8 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = Clipboard;
			productName = Clipboard;
			productReference = {main_target_uuid};
			productType = "com.apple.product-type.application";
		}};
		{target_uuid} /* ShareExtension */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {build_phase_uuid} /* Build configuration list for PBXNativeTarget "ShareExtension" */;
			buildPhases = (
				{build_file_uuid} /* Sources */,
				{group_uuid} /* Frameworks */,
				{file_ref_uuid} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = ShareExtension;
			productName = ShareExtension;
			productReference = {icon_uuid};
			productType = "com.apple.product-type.app-extension";
		}};"""
        
        # Replace the targets section
        new_targets_section = target_section.replace(
            "/* End PBXNativeTarget section */",
            f"{share_extension_target}\n/* End PBXNativeTarget section */"
        )
        content = content.replace(target_section, new_targets_section)
    
    # Add build phases for ShareExtension
    build_phases_section = re.search(r'(/* Begin PBXSourcesBuildPhase section */.*?/* End PBXSourcesBuildPhase section */)', content, re.DOTALL)
    if build_phases_section:
        phases_section = build_phases_section.group(1)
        
        share_extension_phases = f"""
		{build_file_uuid} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{swift_file_uuid} /* ShareViewController.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{group_uuid} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{file_ref_uuid} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{storyboard_uuid} /* MainInterface.storyboard in Resources */,
				{icon_uuid} /* ShareExtensionIcon.png in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};"""
        
        new_phases_section = phases_section.replace(
            "/* End PBXSourcesBuildPhase section */",
            f"{share_extension_phases}\n/* End PBXSourcesBuildPhase section */"
        )
        content = content.replace(phases_section, new_phases_section)
    
    # Write the modified content back
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("ShareExtension target added successfully!")
    return True

if __name__ == "__main__":
    add_share_extension_target("Clipboard.xcodeproj/project.pbxproj")
