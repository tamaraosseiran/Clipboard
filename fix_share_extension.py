#!/usr/bin/env python3
"""
Simple script to add ShareExtension target to Xcode project
"""

import re
import uuid

def generate_uuid():
    """Generate a UUID for Xcode project"""
    return str(uuid.uuid4()).replace('-', '').upper()[:24]

def fix_share_extension():
    """Add ShareExtension target to the Xcode project"""
    
    project_file = "Clipboard.xcodeproj/project.pbxproj"
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Check if ShareExtension target already exists
    if "ShareExtension" in content:
        print("ShareExtension target already exists!")
        return True
    
    # Generate UUIDs
    target_uuid = generate_uuid()
    build_config_uuid = generate_uuid()
    sources_phase_uuid = generate_uuid()
    frameworks_phase_uuid = generate_uuid()
    resources_phase_uuid = generate_uuid()
    product_uuid = generate_uuid()
    swift_file_uuid = generate_uuid()
    storyboard_file_uuid = generate_uuid()
    icon_file_uuid = generate_uuid()
    
    # Find the main target section
    main_target_pattern = r'(016547732E62440700C46AD8 /\* Clipboard \*/ = \{[^}]*\};\s*)(016547872E62440800C46AD8 /\* ClipboardTests \*/)'
    match = re.search(main_target_pattern, content, re.DOTALL)
    
    if not match:
        print("Could not find main target section")
        return False
    
    # Create ShareExtension target
    share_extension_target = f"""
		{target_uuid} /* ShareExtension */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {build_config_uuid} /* Build configuration list for PBXNativeTarget "ShareExtension" */;
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
		}};
		"""
    
    # Insert ShareExtension target after main target
    new_content = content.replace(match.group(1), match.group(1) + share_extension_target)
    
    # Add to targets list
    targets_pattern = r'(targets = \(\s*016547732E62440700C46AD8 /\* Clipboard \*/,)'
    targets_match = re.search(targets_pattern, new_content)
    
    if targets_match:
        new_content = new_content.replace(
            targets_match.group(1),
            f"{targets_match.group(1)}\n\t\t\t{target_uuid} /* ShareExtension */,"
        )
    
    # Write the modified content
    with open(project_file, 'w') as f:
        f.write(new_content)
    
    print("ShareExtension target added successfully!")
    return True

if __name__ == "__main__":
    fix_share_extension()
