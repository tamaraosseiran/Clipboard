# Spots Share Extension

## Overview

The Spots Share Extension allows users to save places from Safari, TikTok, and other apps directly to the Spots app. When sharing content, users can tap "Spots" in the share sheet to open a custom interface that extracts relevant information (URLs, metadata, images, videos) and lets users save it with custom details.

## Architecture

### Files

- **ShareViewController.swift**: Main extension entry point that hosts a SwiftUI view
- **ShareParser.swift**: Extracts URL, text, movie, and image data from share context
- **MetadataFetcher.swift**: Fetches OpenGraph metadata and parses HTML for titles/images
- **SharedStore.swift**: Persists pending spots to App Group UserDefaults
- **Info.plist**: Extension configuration with permissive activation rule (TRUEPREDICATE)

### Key Configuration

**Info.plist Settings:**
- `NSExtensionPointIdentifier`: `com.apple.share-services`
- `NSExtensionPrincipalClass`: `$(PRODUCT_MODULE_NAME).ShareViewController`
- `NSExtensionActivationRule`: `TRUEPREDICATE` (allows extension to activate for any shareable content)

**App Group:**
- Identifier: `group.com.tamaraosseiran.clipboard`
- Used for sharing data between extension and main app

## Share Flow

1. **User initiates share**: From Safari or TikTok → tap Share → select "Spots"
2. **Extension launches**: ShareViewController creates SwiftUI root view
3. **Loading state**: Shows "Reading content…" spinner
4. **Parsing**: ShareParser extracts content from NSItemProviders
   - Priority order: URL → Text (with URL detection) → Movie → Image
5. **Metadata fetching**: If URL found, MetadataFetcher:
   - Fetches HTML page
   - Extracts OpenGraph title and image
   - Attempts address detection from text
6. **UI state**: Shows prefilled form with:
   - Name (from OpenGraph title or URL host)
   - Address (detected or empty)
   - Source URL (read-only)
   - Preview (if images/videos found)
7. **Save**: User taps Save → data persisted to App Group → extension dismisses
8. **Main app**: Reads pending spot from App Group on next launch

## Testing

### From Safari

1. Open any webpage in Safari
2. Tap Share button
3. Select "Spots" from share sheet
4. **Expected**: Sheet opens immediately, shows loading, then prefilled:
   - Name: OpenGraph title or page title
   - Source URL: The shared URL
   - Preview: OG image if available
5. Tap Save
6. Open main Spots app → verify the spot appears

### From TikTok

1. Open TikTok app
2. Find a video to share
3. Tap Share → More → "Spots"
4. **Expected**: Sheet opens immediately (no silent failure)
5. **If TikTok shared text with URL**: URL detected, metadata fetched
6. **If TikTok shared video file**: Video file listed under Preview; user can add name/address manually
7. Tap Save → verify in main app

### Edge Cases

- **No parseable content**: Sheet opens with error message, user can still manually enter details
- **Network failure**: Metadata fetch fails gracefully, basic info still shown
- **Text-only share**: URL extracted via NSDataDetector, or plain text saved for manual entry

## Troubleshooting

### Extension doesn't appear in share sheet

- Verify `NSExtensionActivationRule` is set to `TRUEPREDICATE`
- Check that extension target is included in the scheme
- Rebuild and reinstall on device

### Extension opens but shows error

- Check Console logs (filter by subsystem: `com.tamaraosseiran.clipboard.share`)
- Verify App Group is configured in both main app and extension entitlements
- Ensure network permissions (HTTPS) are allowed (default OK)

### Data not appearing in main app

- Verify App Group identifier matches in both targets
- Check that main app reads from `pending_spot` key in UserDefaults
- Ensure SharedStore.savePending() completed successfully (check logs)

## Logging

The extension uses OSLog with subsystem `com.tamaraosseiran.clipboard.share`. View logs in Console.app or Xcode:

```
log stream --predicate 'subsystem == "com.tamaraosseiran.clipboard.share"'
```

Key log events:
- Extension launch
- Item provider types detected
- Parsing results
- Metadata fetch results
- Save operations

## Future Enhancements

- Combine data from multiple providers (e.g., URL + video file)
- Geocoding integration for address → coordinates
- Thumbnail generation for video files
- Preview images in UI (currently just shows filenames)
- Support for multiple spots in one share operation

