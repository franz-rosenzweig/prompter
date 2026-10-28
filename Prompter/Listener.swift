import AVFoundation
import Speech

/// The microphone: its loudness for Voice mode, and the words the recognizer hears for
/// Follow mode. Recognition runs on this Mac when the language allows it.
@MainActor final class Listener {
    /// 0...1, about 20 times a second.
    var onLevel: ((Float) -> Void)?
    /// The words of the current utterance so far, normalized like the script's.
    var onHeard: (([String]) -> Void)?
    /// Something went wrong that the user should see, in a few words.
    var onProblem: ((String?) -> Void)?

    private let engine = AVAudioEngine()
    private let feed = Feed()
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var taskStarted = Date.distantPast
    private var quietSince: Date?
    private var failures = 0
    private var generation = 0      // which task's callbacks still count
    private var starts = 0          // a newer start() wins over one still waiting for permission
    private var hints: [String] = []
    private(set) var running = false

    /// Audio arrives on the audio thread; the request it goes into changes on the main one.
    private final class Feed: @unchecked Sendable {
        private let lock = NSLock()
        private var request: SFSpeechAudioBufferRecognitionRequest?
        private var lastLevel = Date.distantPast
        func set(_ r: SFSpeechAudioBufferRecognitionRequest?) { lock.withLock { request = r } }
        func append(_ b: AVAudioPCMBuffer) { lock.withLock { request }?.append(b) }
        func shouldReportLevel() -> Bool {
            lock.withLock {
                guard Date().timeIntervalSince(lastLevel) > 0.045 else { return false }
                lastLevel = Date()
                return true
            }
        }
    }

    func start(recognize: Bool, hints: [String]) async {
        stop()
        starts += 1
        let me = starts
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            onProblem?("Microphone off: System Settings › Privacy › Microphone")
            return
        }
        if recognize {
            let status = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
            guard me == starts else { return }
            guard status == .authorized else {
                onProblem?("Speech recognition off: System Settings › Privacy › Speech Recognition")
                return
            }
            let id = Pref.d.string(forKey: Pref.language) ?? ""
            recognizer = id.isEmpty ? SFSpeechRecognizer() : SFSpeechRecognizer(locale: Locale(identifier: id))
            guard recognizer != nil else {
                onProblem?("No recognizer for \(id.isEmpty ? Locale.current.identifier : id)")
                return
            }
            self.hints = hints
        }

        guard me == starts else { return }
        let input = engine.inputNode
        input.removeTap(onBus: 0)       // a bus takes one tap; a second one throws
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            onProblem?("No microphone")
            return
        }
        let feed = self.feed
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            feed.append(buffer)
            guard feed.shouldReportLevel(), let level = Listener.level(of: buffer) else { return }
            DispatchQueue.main.async { self?.heard(level: level) }
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            onProblem?("Microphone: \(error.localizedDescription)")
            return
        }
        running = true
        failures = 0
        onProblem?(nil)
        if recognize { startTask() }
    }

    func stop() {
        starts += 1
        guard running || task != nil else { return }
        running = false
        endTask()
        recognizer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    // MARK: Recognition

    private func startTask() {
        guard running, let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = false
        request.contextualStrings = hints
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        feed.set(request)
        taskStarted = Date()
        generation += 1
        let gen = generation
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let words = result.map { Script.keys($0.bestTranscription.formattedString) }
            let done = error != nil || result?.isFinal == true
            DispatchQueue.main.async {
                guard let self, gen == self.generation else { return }
                if let words, !words.isEmpty { self.failures = 0; self.onHeard?(words) }
                if done { self.restart(failed: error != nil && words == nil) }
            }
        }
    }

    private func endTask() {
        generation += 1
        feed.set(nil)
        task?.cancel()
        task = nil
    }

    /// A task ends on its own after a long pause or an error; a new one picks up the next words.
    private func restart(failed: Bool) {
        guard running, task != nil else { return }
        endTask()
        if failed && Date().timeIntervalSince(taskStarted) < 1 {
            failures += 1
            if failures >= 5 { onProblem?("Speech recognition keeps stopping"); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.startTask() }
        } else {
            startTask()
        }
    }

    private func heard(level: Float) {
        guard running else { return }
        onLevel?(level)
        // A long task gets slow; start a fresh one in the next pause, or after a minute anyway.
        guard task != nil else { return }
        let age = Date().timeIntervalSince(taskStarted)
        if level < 0.3 {
            if quietSince == nil { quietSince = Date() }
        } else {
            quietSince = nil
        }
        if (age > 20 && (quietSince.map { Date().timeIntervalSince($0) > 0.7 } ?? false)) || age > 55 {
            quietSince = nil
            endTask()
            startTask()
        }
    }

    /// Loudness as 0...1: -60 dB and quieter is 0, full scale is 1.
    nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Float? {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return nil }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        let db = 20 * log10(max(rms, 1e-7))
        return min(1, max(0, (db + 60) / 60))
    }
}
