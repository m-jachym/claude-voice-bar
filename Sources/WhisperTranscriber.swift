import Foundation

class WhisperTranscriber {
    private let whisperBin = "/opt/homebrew/bin/whisper-cli"
    private let model = "\(NSHomeDirectory())/.local/share/whisper/ggml-small.bin"

    func transcribe(audioPath: URL) -> String? {
        let outputBase = audioPath.deletingPathExtension().path
        let txtPath = audioPath.deletingPathExtension().appendingPathExtension("txt")
        try? FileManager.default.removeItem(at: txtPath)

        let task = Process()
        task.launchPath = whisperBin
        task.arguments = [
            "--model", model,
            "--language", "pl",
            "--output-txt",
            "--no-timestamps",
            "-of", outputBase,
            "-f", audioPath.path
        ]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            NSLog("whisper-cpp failed: \(error)")
            return nil
        }

        guard task.terminationStatus == 0 else {
            NSLog("whisper-cpp exited with status \(task.terminationStatus)")
            return nil
        }

        return try? String(contentsOf: txtPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
