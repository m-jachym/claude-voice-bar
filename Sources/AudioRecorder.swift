import AVFoundation

class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private let outputURL = URL(fileURLWithPath: "/tmp/voice_input.wav")

    func startRecording() throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder?.record()
    }

    func stopRecording() -> URL {
        recorder?.stop()
        recorder = nil
        return outputURL
    }
}
