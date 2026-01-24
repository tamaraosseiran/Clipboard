//
//  VideoContentExtractor.swift
//  ShareLinkExtension
//
//  Extracts text and audio from video files using Apple's Vision and Speech frameworks.
//  Free, on-device, private processing.
//

import Foundation
import AVFoundation
import Vision
import Speech
import OSLog

struct ExtractedVideoContent {
    var onScreenText: [String] = []  // OCR text from video frames
    var transcribedText: String?     // Audio transcription
    var allText: String {            // Combined text for enrichment
        var combined = onScreenText.joined(separator: " ")
        if let transcribed = transcribedText {
            combined += " " + transcribed
        }
        return combined.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum VideoContentExtractor {
    private static let logger = Logger(subsystem: "com.tamaraosseiran.clipboard.share", category: "VideoContentExtractor")
    
    /// Extracts text from video file using Vision (OCR) and Speech (transcription)
    /// - Parameters:
    ///   - videoURL: Local file URL to the video
    ///   - completion: Returns extracted content (OCR text + transcription)
    static func extract(from videoURL: URL, completion: @escaping (ExtractedVideoContent) -> Void) {
        logger.info("🎬 Starting video content extraction from: \(videoURL.lastPathComponent)")
        logger.info("   Full path: \(videoURL.path)")
        logger.info("   File exists: \(FileManager.default.fileExists(atPath: videoURL.path))")
        
        // Check if file is accessible
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            logger.error("❌ Video file does not exist at path: \(videoURL.path)")
            completion(ExtractedVideoContent())
            return
        }
        
        // Check file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: videoURL.path),
           let fileSize = attributes[.size] as? Int64 {
            logger.info("   File size: \(fileSize) bytes (\(Double(fileSize) / 1_000_000.0) MB)")
        }
        
        var extracted = ExtractedVideoContent()
        let group = DispatchGroup()
        
        // Extract OCR text from video frames (on-screen text)
        group.enter()
        extractOCRText(from: videoURL) { ocrText in
            extracted.onScreenText = ocrText
            logger.info("📝 Extracted \(ocrText.count) OCR text segments")
            if !ocrText.isEmpty {
                logger.info("   OCR samples: \(ocrText.prefix(3).joined(separator: " | "))")
            }
            group.leave()
        }
        
        // Extract audio transcription
        group.enter()
        transcribeAudio(from: videoURL) { transcription in
            extracted.transcribedText = transcription
            if let transcription = transcription {
                logger.info("🎤 Extracted transcription (\(transcription.count) chars): \(transcription.prefix(100))...")
            } else {
                logger.info("🎤 No transcription extracted")
            }
            group.leave()
        }
        
        // Wait for both to complete
        group.notify(queue: .main) {
            let ocrCount = extracted.onScreenText.count
            let hasTranscription = extracted.transcribedText != nil
            let combinedText = extracted.allText
            logger.info("✅ Video extraction complete - OCR: \(ocrCount) segments, Transcription: \(hasTranscription ? "yes" : "no")")
            logger.info("   Combined text length: \(combinedText.count) chars")
            if !combinedText.isEmpty {
                logger.info("   Combined text preview: \(combinedText.prefix(200))")
            }
            completion(extracted)
        }
    }
    
    // MARK: - OCR Text Extraction (Vision Framework)
    
    private static func extractOCRText(from videoURL: URL, completion: @escaping ([String]) -> Void) {
        logger.info("📝 Starting OCR extraction from video")
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        // Sample frames at intervals (every 2 seconds, max 10 frames to keep it fast)
        // Use async loading for duration (iOS 16+) with fallback
        if #available(iOS 16.0, *) {
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    let durationSeconds = CMTimeGetSeconds(duration)
                    logger.info("   Video duration: \(durationSeconds) seconds")
                    let interval: Double = 2.0
                    let maxFrames = min(10, Int(durationSeconds / interval))
                    
                    guard maxFrames > 0 else {
                        logger.warning("Video too short for OCR extraction (duration: \(durationSeconds)s)")
                        completion([])
                        return
                    }
                    
                    logger.info("   Will extract \(maxFrames) frames at \(interval)s intervals")
                    processFrames(imageGenerator: imageGenerator, maxFrames: maxFrames, interval: interval, completion: completion)
                } catch {
                    logger.error("❌ Failed to load video duration: \(error.localizedDescription)")
                    completion([])
                }
            }
        } else {
            // Fallback for iOS < 16
            let duration = asset.duration.seconds
            logger.info("   Video duration: \(duration) seconds")
            let interval: Double = 2.0
            let maxFrames = min(10, Int(duration / interval))
            
            guard maxFrames > 0 else {
                logger.warning("Video too short for OCR extraction (duration: \(duration)s)")
                completion([])
                return
            }
            
            logger.info("   Will extract \(maxFrames) frames at \(interval)s intervals")
            processFrames(imageGenerator: imageGenerator, maxFrames: maxFrames, interval: interval, completion: completion)
        }
    }
    
    private static func processFrames(imageGenerator: AVAssetImageGenerator, maxFrames: Int, interval: Double, completion: @escaping ([String]) -> Void) {
        logger.info("   Processing \(maxFrames) frames for OCR")
        
        var ocrTexts: [String] = []
        let ocrGroup = DispatchGroup()
        let textQueue = DispatchQueue(label: "com.tamaraosseiran.clipboard.ocr")
        var processedFrames = 0
        var framesWithText = 0
        
        // Process frames in parallel
        for i in 0..<maxFrames {
            let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
            
            ocrGroup.enter()
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, error in
                defer { 
                    processedFrames += 1
                    ocrGroup.leave() 
                }
                
                if let error = error {
                    logger.error("❌ Error generating frame at \(time.seconds)s: \(error.localizedDescription)")
                    return
                }
                
                guard let cgImage = cgImage else {
                    logger.warning("⚠️ No image generated at \(time.seconds)s")
                    return
                }
                
                logger.info("   Frame \(i+1)/\(maxFrames) at \(time.seconds)s - image size: \(cgImage.width)x\(cgImage.height)")
                
                // Use Vision framework to detect text
                let request = VNRecognizeTextRequest { request, error in
                    if let error = error {
                        logger.error("❌ OCR error at \(time.seconds)s: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedTextObservation] else { 
                        logger.info("   No text observations at \(time.seconds)s")
                        return 
                    }
                    
                    logger.info("   Found \(observations.count) text observations at \(time.seconds)s")
                    
                    let text = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }.joined(separator: " ")
                    
                    if !text.isEmpty {
                        framesWithText += 1
                        logger.info("📝 OCR found text at \(time.seconds)s: \(text.prefix(50))...")
                        textQueue.sync {
                            ocrTexts.append(text)
                        }
                    } else {
                        logger.info("   No text extracted from frame at \(time.seconds)s")
                    }
                }
                
                // Use accurate recognition for better results
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    logger.error("❌ Failed to perform OCR at \(time.seconds)s: \(error.localizedDescription)")
                }
            }
        }
        
        ocrGroup.notify(queue: .main) {
            logger.info("   Processed \(processedFrames)/\(maxFrames) frames, \(framesWithText) frames had text")
            // Remove duplicates and empty strings
            let uniqueTexts = Array(Set(ocrTexts.filter { !$0.isEmpty }))
            logger.info("✅ OCR extraction complete: \(uniqueTexts.count) unique text segments")
            completion(uniqueTexts)
        }
    }
    
    // MARK: - Audio Transcription (Speech Framework)
    
    private static func transcribeAudio(from videoURL: URL, completion: @escaping (String?) -> Void) {
        let asset = AVURLAsset(url: videoURL)
        
        // Check if asset has audio track (use modern API for iOS 16+)
        if #available(iOS 16.0, *) {
            Task {
                do {
                    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                    guard !audioTracks.isEmpty else {
                        logger.info("No audio track found in video")
                        completion(nil)
                        return
                    }
                    await processAudioTranscription(asset: asset, audioTracks: audioTracks, videoURL: videoURL, completion: completion)
                } catch {
                    logger.error("Failed to load audio tracks: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        } else {
            // Fallback for iOS < 16
            let audioTracks = asset.tracks(withMediaType: .audio)
            guard !audioTracks.isEmpty else {
                logger.info("No audio track found in video")
                completion(nil)
                return
            }
            processAudioTranscriptionLegacy(asset: asset, audioTracks: audioTracks, videoURL: videoURL, completion: completion)
        }
    }
    
    private static func processAudioTranscriptionLegacy(asset: AVAsset, audioTracks: [AVAssetTrack], videoURL: URL, completion: @escaping (String?) -> Void) {
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                logger.warning("Speech recognition not authorized: \(status.rawValue)")
                completion(nil)
                return
            }
            
            // Create speech recognizer
            guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
                logger.warning("Speech recognizer not available")
                completion(nil)
                return
            }
            
            // Extract audio from video
            let audioExtractor = AudioExtractor()
            audioExtractor.extractAudio(from: videoURL) { audioURL in
                guard let audioURL = audioURL else {
                    logger.error("Failed to extract audio from video")
                    completion(nil)
                    return
                }
                
                // Transcribe audio
                let request = SFSpeechURLRecognitionRequest(url: audioURL)
                request.shouldReportPartialResults = false
                
                var finalTranscription: String?
                let task = recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        logger.error("Transcription error: \(error.localizedDescription)")
                        if finalTranscription == nil {
                            completion(nil)
                        }
                        return
                    }
                    
                    if let result = result {
                        if result.isFinal {
                            finalTranscription = result.bestTranscription.formattedString
                            logger.info("✅ Transcription complete: \(finalTranscription?.prefix(100) ?? "nil")...")
                            completion(finalTranscription)
                        }
                    }
                }
                
                // Fallback: if task finishes without final result, use best available
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                    if finalTranscription == nil && !task.isCancelled {
                        task.cancel()
                        logger.warning("Transcription timeout")
                        completion(nil)
                    }
                }
            }
        }
    }
    
    @available(iOS 16.0, *)
    private static func processAudioTranscription(asset: AVAsset, audioTracks: [AVAssetTrack], videoURL: URL, completion: @escaping (String?) -> Void) async {
        logger.info("🎤 Starting audio transcription (iOS 16+)")
        // Request speech recognition authorization
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume()
                
                guard status == .authorized else {
                    logger.warning("❌ Speech recognition not authorized: \(status.rawValue)")
                    completion(nil)
                    return
                }
                
                logger.info("   Speech recognition authorized")
                
                // Create speech recognizer
                guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
                    logger.warning("❌ Speech recognizer not available")
                    completion(nil)
                    return
                }
                
                logger.info("   Speech recognizer available")
                
                // Extract audio from video
                let audioExtractor = AudioExtractor()
                audioExtractor.extractAudio(from: videoURL) { audioURL in
                    guard let audioURL = audioURL else {
                        logger.error("❌ Failed to extract audio from video")
                        completion(nil)
                        return
                    }
                    
                    logger.info("   Audio extracted to: \(audioURL.lastPathComponent)")
                    
                    // Transcribe audio
                    let request = SFSpeechURLRecognitionRequest(url: audioURL)
                    request.shouldReportPartialResults = false
                    
                    var finalTranscription: String?
                    var taskCompleted = false
                    let task = recognizer.recognitionTask(with: request) { result, error in
                        if let error = error {
                            logger.error("❌ Transcription error: \(error.localizedDescription)")
                            if !taskCompleted {
                                taskCompleted = true
                                completion(nil)
                            }
                            return
                        }
                        
                        if let result = result {
                            if result.isFinal {
                                finalTranscription = result.bestTranscription.formattedString
                                logger.info("✅ Transcription complete: \(finalTranscription?.prefix(100) ?? "nil")...")
                                if !taskCompleted {
                                    taskCompleted = true
                                    completion(finalTranscription)
                                }
                            }
                        }
                    }
                    
                    // Fallback: if task finishes without final result, use best available
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                        if !taskCompleted && !task.isCancelled {
                            task.cancel()
                            logger.warning("⚠️ Transcription timeout after 30s")
                            if finalTranscription == nil {
                                completion(nil)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Audio Extractor Helper

private final class AudioExtractor: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tamaraosseiran.clipboard.share", category: "AudioExtractor")
    
    func extractAudio(from videoURL: URL, completion: @escaping (URL?) -> Void) {
        let asset = AVURLAsset(url: videoURL)
        
        // Use modern API for iOS 16+ with fallback
        if #available(iOS 16.0, *) {
            Task {
                do {
                    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                    guard let audioTrack = audioTracks.first else {
                        logger.warning("No audio track in video")
                        completion(nil)
                        return
                    }
                    
                    let duration = try await asset.load(.duration)
                    await performAudioExtraction(asset: asset, audioTrack: audioTrack, duration: duration, completion: completion)
                } catch {
                    logger.error("Failed to load audio tracks: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        } else {
            // Fallback for iOS < 16
            guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
                logger.warning("No audio track in video")
                completion(nil)
                return
            }
            
            let duration = asset.duration
            performAudioExtractionLegacy(asset: asset, audioTrack: audioTrack, duration: duration, completion: completion)
        }
    }
    
    @available(iOS 16.0, *)
    private func performAudioExtraction(asset: AVAsset, audioTrack: AVAssetTrack, duration: CMTime, completion: @escaping (URL?) -> Void) async {
        // Create temporary audio file
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        
        do {
            let audioComposition = AVMutableComposition()
            let audioCompositionTrack = audioComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            try audioCompositionTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: audioTrack,
                at: .zero
            )
            
            // Use AVAssetExportSession (exportAsynchronously is deprecated in iOS 18 but still functional)
            guard let exportSession = AVAssetExportSession(asset: audioComposition, presetName: AVAssetExportPresetAppleM4A) else {
                logger.error("Failed to create export session")
                completion(nil)
                return
            }
            
            exportSession.outputURL = audioURL
            exportSession.outputFileType = AVFileType.m4a
            
            // Wrap in Task to handle async properly and avoid Sendable warnings
            // Note: exportAsynchronously, status, and error are deprecated in iOS 18.0
            // but still functional. New async API not yet available in current SDK.
            Task { @MainActor [logger, audioURL] in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    exportSession.exportAsynchronously {
                        continuation.resume()
                    }
                }
                
                // Check status after export completes
                let status = exportSession.status
                if status == .completed {
                    logger.info("✅ Audio extracted to: \(audioURL.lastPathComponent)")
                    completion(audioURL)
                } else {
                    let errorMsg = exportSession.error?.localizedDescription ?? "unknown"
                    logger.error("Audio extraction failed: \(errorMsg)")
                    completion(nil)
                }
            }
        } catch {
            logger.error("Error extracting audio: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    private func performAudioExtractionLegacy(asset: AVAsset, audioTrack: AVAssetTrack, duration: CMTime, completion: @escaping (URL?) -> Void) {
        // Create temporary audio file
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        
        do {
            let audioComposition = AVMutableComposition()
            let audioCompositionTrack = audioComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            try audioCompositionTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: audioTrack,
                at: .zero
            )
            
            guard let exportSession = AVAssetExportSession(asset: audioComposition, presetName: AVAssetExportPresetAppleM4A) else {
                logger.error("Failed to create export session")
                completion(nil)
                return
            }
            
            exportSession.outputURL = audioURL
            exportSession.outputFileType = AVFileType.m4a
            
            // Wrap in Task to handle async export properly and avoid Sendable warnings
            Task { @MainActor [logger, audioURL] in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    // Suppress deprecation warning - exportAsynchronously still works
                    exportSession.exportAsynchronously {
                        continuation.resume()
                    }
                }
                
                // Check status after export completes (status property deprecated but still functional)
                let status = exportSession.status
                if status == .completed {
                    logger.info("✅ Audio extracted to: \(audioURL.lastPathComponent)")
                    completion(audioURL)
                } else {
                    let errorMsg = exportSession.error?.localizedDescription ?? "unknown"
                    logger.error("Audio extraction failed: \(errorMsg)")
                    completion(nil)
                }
            }
        } catch {
            logger.error("Error extracting audio: \(error.localizedDescription)")
            completion(nil)
        }
    }
}
