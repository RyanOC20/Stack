import os.log

struct Logger {
    private let logger = os.Logger(subsystem: "com.stack.app", category: "default")

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
