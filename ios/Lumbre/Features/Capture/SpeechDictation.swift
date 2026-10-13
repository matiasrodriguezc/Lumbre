import AVFoundation
import Observation
import OSLog
import Speech

/// Dictado en el teléfono con `SFSpeechRecognizer` y `AVAudioEngine`. El audio no se guarda ni sale del teléfono
/// cuando el reconocimiento local está disponible (`requiresOnDeviceRecognition`).
@MainActor
@Observable
final class SpeechDictation {
    enum State: Equatable {
        case idle
        case starting
        case listening
        /// Falta el permiso del micrófono o del reconocimiento de voz.
        case denied
        /// El reconocimiento no está disponible (sin idioma, sin micrófono o sin red cuando hace falta).
        case unavailable
    }

    private(set) var state: State = .idle
    /// Lo que se reconoció en esta toma.
    private(set) var transcript = ""
    /// Se transcribe solo en el teléfono.
    private(set) var isOnDevice = false

    /// Se llama con cada resultado parcial.
    var onTranscript: (String) -> Void = { _ in }

    private let recognizer: SFSpeechRecognizer?
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let logger = Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "dictation")

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "es-AR"))
            ?? SFSpeechRecognizer()
    }

    var isListening: Bool { state == .listening || state == .starting }

    func toggle() async {
        if isListening {
            stop()
        } else {
            await start()
        }
    }

    func start() async {
        guard !isListening else { return }
        state = .starting
        transcript = ""
        guard await Self.requestSpeechPermission(), await Self.requestMicrophonePermission() else {
            state = .denied
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            state = .unavailable
            return
        }
        do {
            try begin(with: recognizer)
            state = .listening
        } catch {
            logger.error("dictation failed to start: \(error.localizedDescription, privacy: .public)")
            tearDown()
            state = .unavailable
        }
    }

    func stop() {
        guard isListening else { return }
        task?.finish()
        tearDown()
        state = .idle
    }

    // MARK: - Privado

    private func begin(with recognizer: SFSpeechRecognizer) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        isOnDevice = recognizer.supportsOnDeviceRecognition
        if isOnDevice {
            request.requiresOnDeviceRecognition = true
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw CocoaError(.featureUnsupported)
        }
        Self.installTap(on: input, format: format, request: request)
        engine.prepare()
        try engine.start()

        self.engine = engine
        self.request = request
        task = Self.recognize(with: recognizer, request: request) { [weak self] text, isFinal in
            Task { @MainActor in self?.receive(text, isFinal: isFinal) }
        }
    }

    private func receive(_ text: String?, isFinal: Bool) {
        if let text {
            transcript = text
            onTranscript(text)
        }
        if isFinal, isListening {
            tearDown()
            state = .idle
        }
    }

    private func tearDown() {
        if let engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        engine = nil
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // Los callbacks de audio y de reconocimiento llegan en otros hilos: se arman fuera del MainActor.

    private nonisolated static func installTap(on input: AVAudioInputNode, format: AVAudioFormat, request: SFSpeechAudioBufferRecognitionRequest) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    private nonisolated static func recognize(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        handler: @escaping @Sendable (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            handler(result?.bestTranscription.formattedString, result?.isFinal ?? (error != nil))
        }
    }

    private nonisolated static func requestSpeechPermission() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .denied, .restricted: return false
        default:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    private nonisolated static func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}
