import XCTest

/// Walks through the demo and saves a screenshot of every section for the user guide. Not a test
/// of anything: run it with `TEST_RUNNER_SHOTS=<dir>` to get the images (see CLAUDE.md).
final class GuideScreenshots: XCTestCase {
    private var app: XCUIApplication!
    private var directory: URL!

    override func setUp() {
        continueAfterFailure = true
        let path = ProcessInfo.processInfo.environment["SHOTS"] ?? NSTemporaryDirectory() + "guide-shots"
        directory = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launch()
    }

    func testWalkthrough() {
        let tabs = app.tabBars.buttons
        sleep(1)

        // Events: quick events, a track and a flush so the counters show something.
        app.buttons["Track"].firstMatch.tap()
        shot("snackbar")
        sleep(3)
        app.buttons["Flush"].firstMatch.tap()
        sleep(2)
        shot("events_0")
        swipeShots("events", from: 1, count: 4)

        // Identity.
        tabs["Identity"].tap()
        sleep(1)
        shot("identity_0")
        app.swipeUp()
        shot("identity_1")
        app.swipeUp()
        shot("identity_2")

        // Capture.
        tabs["Capture"].tap()
        sleep(1)
        shot("capture_0")
        app.buttons["ScreenNamed controller"].firstMatch.tap()
        sleep(1)
        shot("product")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        app.buttons["Plain controller"].firstMatch.tap()
        sleep(1)
        shot("legacy")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        swipeShots("capture", from: 1, count: 4)
        app.buttons["GET with ids and a token"].firstMatch.tap()
        sleep(2)
        shot("capture_results")

        // Server.
        tabs["Server"].tap()
        sleep(2)
        shot("server_0")
        swipeShots("server", from: 1, count: 3)
        // Received events: refresh and open the first one.
        let refresh = app.buttons["Refresh"].firstMatch
        if refresh.exists {
            refresh.tap()
            sleep(2)
            shot("server_events")
            let first = app.staticTexts["Session Started"].firstMatch
            if first.exists {
                first.tap()
                sleep(1)
                shot("server_event_open")
            }
        }
        app.swipeUp()
        app.swipeUp()
        let load = app.buttons["Load the last requests"].firstMatch
        if load.exists {
            load.tap()
            sleep(2)
            shot("server_requests")
        }

        // Logs.
        tabs["Logs"].tap()
        sleep(1)
        shot("logs_0")
        app.buttons["SDK log"].firstMatch.tap()
        sleep(1)
        shot("logs_sdklog")
        app.buttons["warn+"].firstMatch.tap()
        sleep(1)
        shot("logs_sdklog_warn")

        // Settings.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        shot("settings_0")
        swipeShots("settings", from: 1, count: 5)
    }

    private func swipeShots(_ name: String, from index: Int, count: Int) {
        for i in 0..<count {
            app.swipeUp()
            usleep(600_000)
            shot("\(name)_\(index + i)")
        }
    }

    private func shot(_ name: String) {
        let image = XCUIScreen.main.screenshot().pngRepresentation
        try? image.write(to: directory.appendingPathComponent("\(name).png"))
    }
}
