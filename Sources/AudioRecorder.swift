import AVFoundation

class AudioRecorder {
    private var engine = AVAudioEngine()
    private var file: AVAudioFile?
    private let outputURL = URL(fileURLWithPath: "/tmp/voice_input.wav")

    func startRecording() throws {
        engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        // Whisper expects 16kHz mono — we record in native format and convert
        let recordFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )!

        file = try AVAudioFile(forWriting: outputURL, settings: recordFormat.settings)

        // Install tap in native format, then convert on write
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let file = self.file else { return }
            guard let converter = AVAudioConverter(from: inputFormat, to: recordFormat) else { return }

            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * recordFormat.sampleRate / inputFormat.sampleRate
            )
            guard let converted = AVAudioPCMBuffer(pcmFormat: recordFormat, frameCapacity: frameCapacity) else { return }

            var error: NSError?
            var inputDone = false
            converter.convert(to: converted, error: &error) { _, outStatus in
                if inputDone {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                inputDone = true
                outStatus.pointee = .haveData
                return buffer
            }

            if error == nil {
                try? file.write(from: converted)
            }
        }

        try engine.start()
    }

    func stopRecording() -> URL {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil
        return outputURL
    }
}
