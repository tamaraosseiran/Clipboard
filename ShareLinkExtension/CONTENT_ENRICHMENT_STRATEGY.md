# Content Enrichment Strategy

## Current Approach: Enhanced Caption Parsing

### Priority Order for Place Detection

1. **Caption Text (Highest Priority)** ✅
   - Extracts place names from TikTok/Instagram captions via oEmbed API
   - Pattern matching for common formats:
     - 📍 emoji patterns: "📍childish bakery - carrollton, tx"
     - "at [Place Name]" patterns
     - "went to [Place Name]" patterns
     - Capitalized business names
   - **Why this works**: Users explicitly mention places in captions, even when location tags are wrong

2. **Apple's Natural Language Framework** ✅
   - On-device Named Entity Recognition (NER)
   - Extracts organizations, places, and person names
   - Free, private, fast

3. **Location Tags** (Lower Priority)
   - Only used if caption doesn't contain place name
   - Can be unreliable (as seen with wrong location tags)

### Improvements Made

- Enhanced 📍 emoji pattern matching to catch place names anywhere in caption
- Better handling of "place name - city" format
- More robust pattern matching for common place mention phrases
- Improved validation to filter out common words

## ✅ Implemented: On-Device AI Extraction

**Status: IMPLEMENTED** - Using Apple's free, on-device frameworks!

### Implementation Details

**✅ Vision Framework**: OCR for on-screen text in video frames
- Samples video frames every 2 seconds (max 10 frames)
- Uses `VNRecognizeTextRequest` for accurate text recognition
- Extracts place names, business names, addresses from on-screen text

**✅ Speech Framework**: Audio transcription
- Extracts audio track from video
- Transcribes spoken content (place names, descriptions)
- Handles authorization and availability checks

**✅ Natural Language Framework**: Already using this ✅
- Named Entity Recognition for organizations, places, persons

### How It Works

1. **When video file is shared**: `VideoContentExtractor` processes it
2. **OCR Extraction**: Samples frames → Vision OCR → extracts on-screen text
3. **Audio Transcription**: Extracts audio → Speech framework → transcribes
4. **Unified Pipeline**: All extracted text (caption + OCR + transcription) → `ContentEnricher.enrich()`
5. **Same Enrichment**: Feeds into existing place name extraction, category detection, location resolution

### Permissions Required

Add to `Info.plist`:
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>We transcribe video audio to extract place names and descriptions</string>
```

### Performance Considerations

- **OCR**: Processes max 10 frames (every 2 seconds) - fast enough for share extension
- **Transcription**: Limited to ~30 seconds of audio (share extension timeout)
- **Async Processing**: Both OCR and transcription run in parallel
- **Fallback**: If video processing takes too long, falls back to caption-only

**❌ Avoid (Cost, Privacy, Performance):**
- Cloud AI APIs (OpenAI, Google Vision, etc.)
- Third-party video analysis services
- Any service requiring video upload

### Architecture: Unified Enrichment Pipeline

All signals feed into the same `ContentEnricher.enrich()` pipeline:

```
Input Sources:
├── Caption Text (oEmbed API) ✅ Current
├── NLP Entities (Apple NL Framework) ✅ Current
├── Pattern Matching ✅ Current
├── OCR Text (Vision Framework) 🔮 Future
└── Audio Transcription (Speech Framework) 🔮 Future
         ↓
    ContentEnricher.enrich()
         ↓
    Unified EnrichedContent Output
```

### Implementation Notes

**Current Limitations:**
- Share extensions typically only receive URLs, not video files
- Video processing would require:
  1. Downloading video from URL (slow, expensive)
  2. Extracting frames (complex)
  3. Processing frames (time-consuming)
  4. Share extensions have limited execution time (~30 seconds)

**Recommendation:**
- **Phase 1 (Current)**: Enhanced caption parsing ✅
- **Phase 2 (If Needed)**: Add Vision OCR for image frames (if share extension receives images)
- **Phase 3 (Future)**: Consider video frame extraction only if caption parsing proves insufficient

## Testing Strategy

Test with real TikTok/Instagram shares:
1. Caption with 📍 emoji and place name
2. Caption with place name but wrong location tag
3. Caption with no place name (fallback to location tag)
4. Caption with multiple place mentions (should prioritize first/clearest)

## Success Metrics

- **Place name extraction accuracy**: Target > 85% for captions with place mentions
- **Category detection accuracy**: Target > 80% for food/restaurant content
- **User validation rate**: Users should rarely need to manually search for places
