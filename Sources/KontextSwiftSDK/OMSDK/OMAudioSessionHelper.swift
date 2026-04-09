import AVFAudio
import OSLog

/// Manages AVAudioSession for OMID device volume change tracking in HTML video ads.
///
/// The OMID native SDK automatically detects device volume changes, but requires
/// an active audio session with `.mixWithOthers` to observe `outputVolume` via KVO.
/// Without this, device volume change events are not delivered to verification scripts.
///
/// Reference: IAB OMSDK demo WebViewVideoController.swift
@MainActor
final class OMAudioSessionHelper {
    private var isActive = false

    /// Activates the audio session so the OMID SDK can observe device volume changes.
    /// Idempotent — calling multiple times has no effect.
    func activate() {
        guard !isActive else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
            isActive = true
        } catch {
            os_log(.error, "[OM] Failed to activate audio session: \(error)")
        }
    }

    /// Deactivates the audio session.
    func deactivate() {
        guard isActive else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            os_log(.error, "[OM] Failed to deactivate audio session: \(error)")
        }

        isActive = false
    }
}
