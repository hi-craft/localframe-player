import XCTest
import UIKit

final class LibraryPlaybackUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        if name.contains("testFullscreenPlaylistDrawer") { app.launchArguments.append("-ui-testing-long-title") }
        if name.contains("testLargeLibrary") { app.launchArguments.append("-ui-testing-large-library") }
        app.launch()
        XCTAssertTrue(app.buttons["tab.folders"].waitForExistence(timeout: 10))
        app.buttons["tab.folders"].tap()
        let source = app.buttons["source.本机测试"]
        XCTAssertTrue(source.waitForExistence(timeout: 15))
        // Cached entries appear before the asynchronous permission/metadata scan finishes.
        expectation(for: NSPredicate(format: "label CONTAINS %@", "本地"), evaluatedWith: source)
        waitForExpectations(timeout: 30)
    }

    override func tearDownWithError() throws {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
        app.terminate(); XCUIDevice.shared.orientation = .portrait
    }

    private func showAllVideos() {
        app.buttons["tab.categories"].tap()
        app.buttons["category.all"].tap()
        XCTAssertTrue(app.buttons["video.开场.mp4"].waitForExistence(timeout: 10))
    }

    private func openVideo() {
        app.buttons["source.本机测试"].tap()
        let video = app.buttons["video.开场.mp4"]
        XCTAssertTrue(video.waitForExistence(timeout: 10))
        video.tap()
        XCTAssertTrue(app.buttons["playback.toggle"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 15), "Fixture must actually play")
    }

    private func revealControls() {
        if app.buttons["playback.toggle"].exists { return }
        app.otherElements["playback.canvas"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(app.buttons["playback.toggle"].waitForExistence(timeout: 3))
    }

    private func pausePlayback() {
        for _ in 0..<2 {
            revealControls()
            if app.buttons["播放"].exists { return }
            app.buttons["playback.toggle"].tap()
            if app.buttons["播放"].waitForExistence(timeout: 2) { return }
        }
        XCTFail("The play button must confirm playback is paused")
    }

    // UIKit reports a raw numeric value on iPad and a percentage on iPhone.
    // All UI fixtures are 45 seconds long.
    private func progressSeconds(_ slider: XCUIElement) -> Double {
        if let value = slider.value as? NSNumber { return value.doubleValue }
        let value = slider.value as? String ?? ""
        let number = Double(value.replacingOccurrences(of: "%", with: "")) ?? 0
        return value.contains("%") ? number * 45 / 100 : number
    }

    private func waitForPortrait(_ portrait: Bool) {
        let predicate = NSPredicate { [unowned self] _, _ in
            let size = self.app.windows.element(boundBy: 0).frame.size
            return portrait ? size.height > size.width : size.width > size.height
        }
        expectation(for: predicate, evaluatedWith: app)
        waitForExpectations(timeout: 8)
    }

    func testSingleTapRevealsControlsAndButtonsStillWork() {
        openVideo()
        let toggle = app.buttons["playback.toggle"]
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: toggle)
        waitForExpectations(timeout: 8)
        revealControls()
        pausePlayback()
        XCTAssertTrue(app.buttons["播放"].waitForExistence(timeout: 3))
        app.buttons["播放"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 3))
        app.sliders["playback.progress"].adjust(toNormalizedSliderPosition: 0.25)
        XCTAssertTrue(app.buttons["暂停"].exists)
    }

    func testTimelineTapAndPreviewDragKeepPauseState() {
        openVideo()
        pausePlayback()
        let slider = app.sliders["playback.progress"]
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        expectation(for: NSPredicate { _, _ in abs(self.progressSeconds(slider) - 34) < 2.5 }, evaluatedWith: slider)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["播放"].exists)
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).tap()
        expectation(for: NSPredicate { _, _ in self.progressSeconds(slider) < 1.5 }, evaluatedWith: slider)
        waitForExpectations(timeout: 5)
        // Hold before and after movement so the preview can decode real video frames.
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.30, dy: 0.5))
            .press(forDuration: 2, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 2)
        expectation(for: NSPredicate { _, _ in
            let actual = self.progressSeconds(slider)
            print("PAUSED_DRAG_PROGRESS_SECONDS: \(actual), raw: \(slider.value ?? "nil")")
            return abs(actual - 27) < 2.5
        }, evaluatedWith: slider)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["播放"].exists, "Seeking must preserve paused state")
        let previewGone = app.staticTexts["playback.preview.time"].waitForNonExistence(timeout: 3)
        if !previewGone { print("PREVIEW AX AFTER RELEASE: \(app.debugDescription)") }
        XCTAssertTrue(previewGone, "The preview closes on release")
        let committed = XCTAttachment(screenshot: app.screenshot())
        committed.name = "Timeline committed paused seek"; committed.lifetime = .keepAlways; add(committed)
        app.buttons["播放"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 3))
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        expectation(for: NSPredicate { _, _ in self.progressSeconds(slider) < 17 }, evaluatedWith: slider)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["暂停"].exists, "Seeking must also preserve playing state")
    }

    func testTimelineFullscreenTapAndDrag() {
        openVideo()
        pausePlayback()
        app.buttons["全屏播放"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForPortrait(false)
        revealControls()
        if app.buttons["playlist.开场.mp4"].isHittable { app.buttons["显示或隐藏播放列表"].tap() }
        let slider = app.sliders["playback.progress"]
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        expectation(for: NSPredicate { _, _ in abs(self.progressSeconds(slider) - 34) < 2.5 }, evaluatedWith: slider)
        waitForExpectations(timeout: 5)
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.5))
            .press(forDuration: 2, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 2)
        expectation(for: NSPredicate { _, _ in abs(self.progressSeconds(slider) - 11) < 2.5 }, evaluatedWith: slider)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["播放"].exists)
        app.buttons["返回资料库"].tap()
        if UIDevice.current.userInterfaceIdiom == .phone { waitForPortrait(true) }
        XCTAssertTrue(app.buttons["video.开场.mp4"].waitForExistence(timeout: 5))
    }

    func testQuickSkipTimerLockAndVideoInfo() {
        openVideo()
        pausePlayback()
        let slider = app.sliders["playback.progress"]
        slider.adjust(toNormalizedSliderPosition: 0.2)
        let before = progressSeconds(slider)
        app.buttons["前进10秒"].tap()
        expectation(for: NSPredicate { _, _ in self.progressSeconds(slider) > before + 8 }, evaluatedWith: slider)
        waitForExpectations(timeout: 5)
        app.buttons["后退10秒"].tap()
        expectation(for: NSPredicate { _, _ in abs(self.progressSeconds(slider) - before) < 2 }, evaluatedWith: slider)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["播放"].exists)
        app.buttons["更多播放选项"].tap()
        app.buttons["15分钟后暂停"].tap()
        XCTAssertTrue(app.buttons["取消定时暂停"].waitForExistence(timeout: 3))
        let options = XCTAttachment(screenshot: app.screenshot())
        options.name = "Playback convenience options"; options.lifetime = .keepAlways; add(options)
        app.buttons["视频信息"].tap()
        XCTAssertTrue(app.staticTexts["video.info.path"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["开场.mp4"].exists)
        app.buttons["复制相对路径"].tap()
        XCTAssertTrue(app.buttons["已复制相对路径"].waitForExistence(timeout: 3))
        let info = XCTAttachment(screenshot: app.screenshot())
        info.name = "Video information"; info.lifetime = .keepAlways; add(info)
        app.navigationBars["视频信息"].buttons["播放选项"].tap()
        app.buttons["取消定时暂停"].tap()
        XCTAssertFalse(app.buttons["取消定时暂停"].exists)
        app.buttons["playback.options.lock"].tap()
        XCTAssertTrue(app.buttons["解锁播放控制"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["playback.toggle"].exists)
        let canvas = app.otherElements["playback.canvas"]
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).doubleTap()
        XCTAssertTrue(app.buttons["解锁播放控制"].exists)
        XCTAssertFalse(app.buttons["playback.toggle"].exists)
        let locked = XCTAttachment(screenshot: app.screenshot())
        locked.name = "Locked playback controls"; locked.lifetime = .keepAlways; add(locked)
        app.buttons["解锁播放控制"].tap()
        XCTAssertTrue(app.buttons["播放"].waitForExistence(timeout: 3), "Locked double-tap must not resume playback")
        app.buttons["更多播放选项"].tap()
        app.buttons["15分钟后暂停"].tap()
        app.buttons["完成"].tap()
        app.buttons["返回资料库"].tap()
        app.buttons["video.开场.mp4"].tap()
        XCTAssertTrue(app.buttons["更多播放选项"].waitForExistence(timeout: 10))
        app.buttons["更多播放选项"].tap()
        XCTAssertFalse(app.buttons["取消定时暂停"].exists, "Closing playback cancels the session timer")
    }

    func testVideoInfoIsAvailableWithoutStartingPlayback() {
        showAllVideos()
        app.buttons["video.开场.mp4"].press(forDuration: 1)
        app.buttons["视频信息"].tap()
        XCTAssertTrue(app.staticTexts["video.info.path"].waitForExistence(timeout: 3))
        let source = app.descendants(matching: .any).matching(identifier: "video.info.source").firstMatch
        XCTAssertTrue(source.label.contains("本机测试"))
        XCTAssertFalse(app.buttons["playback.toggle"].exists)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["video.开场.mp4"].waitForExistence(timeout: 3))
    }

    func testPlaylistThumbnailSelectionAndPullToRebuild() {
        showAllVideos()
        app.buttons["video.开场.mp4"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 15))
        pausePlayback()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@",
            "playlist.", "playlist.开场.mp4"))
        let row = rows.allElementsBoundByIndex.first(where: { $0.isHittable && $0.isEnabled })
        XCTAssertNotNil(row)
        guard let row else { return }
        let fileName = String(row.identifier.dropFirst("playlist.".count)).components(separatedBy: "/").last!
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts[fileName].waitForExistence(timeout: 5), "Tapping the thumbnail must select its video")
        revealControls()
        if app.buttons["暂停"].exists { pausePlayback() }
        let playlist = XCTAttachment(screenshot: app.screenshot())
        playlist.name = "Playlist first-frame thumbnails"; playlist.lifetime = .keepAlways; add(playlist)
        app.buttons["返回资料库"].tap()
        XCTAssertTrue(app.buttons["video.开场.mp4"].waitForExistence(timeout: 5))
        // Begin below the navigation bar; the scroll view frame includes the top safe area.
        let libraryScroll = app.scrollViews.element(boundBy: 0)
        libraryScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
            .press(forDuration: 0.05, thenDragTo: libraryScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.70)))
        let progress = app.descendants(matching: .any).matching(identifier: "library.reading-progress").firstMatch
        expectation(for: NSPredicate(format: "label CONTAINS %@", "索引重建完成"), evaluatedWith: progress)
        waitForExpectations(timeout: 30)
        app.buttons["tab.folders"].tap()
        app.buttons["source.离线硬盘"].tap()
        app.buttons["folder.已索引"].tap()
        XCTAssertTrue(app.buttons["video.已索引/离线片段.mp4"].waitForExistence(timeout: 5))
    }

    func testFullscreenExitAndLibraryReturnRestorePortrait() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else { throw XCTSkip("iPhone library orientation policy") }
        openVideo()
        for _ in 0..<3 {
            revealControls()
            app.buttons["全屏播放"].tap()
            waitForPortrait(false)
            XCUIDevice.shared.orientation = .landscapeLeft
            revealControls()
            if !app.buttons["播放"].exists { pausePlayback() }
            let fullscreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            fullscreen.name = "Cinema fullscreen controls"; fullscreen.lifetime = .keepAlways; add(fullscreen)
            app.buttons["退出全屏"].tap()
            waitForPortrait(true)
            revealControls()
            XCTAssertTrue(app.staticTexts["开场.mp4"].exists, "Rotation must keep the same video open")
            XCTAssertTrue(app.buttons["全屏播放"].exists)
        }
        XCUIDevice.shared.orientation = .portrait
        revealControls()
        app.buttons["全屏播放"].tap()
        waitForPortrait(false)
        XCUIDevice.shared.orientation = .landscapeLeft
        revealControls()
        app.buttons["返回资料库"].tap()
        waitForPortrait(true)
        XCTAssertTrue(app.buttons["video.开场.mp4"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForPortrait(true)
    }

    func testFullscreenAutoAdvanceThroughFinalVideoCanCloseAndPlayAgain() {
        app.buttons["tab.categories"].tap()
        app.buttons["category.available"].tap()
        app.buttons["video.开场.mp4"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 15))
        app.buttons["全屏播放"].tap()
        if UIDevice.current.userInterfaceIdiom == .phone { waitForPortrait(false) }
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForPortrait(false)

        // Seek near the end, then let VLC deliver each real end-of-media event.
        // A manual next/close while paused does not exercise this regression.
        for nextTitle in ["片段二.mp4", "片段三.mp4"] {
            revealControls()
            app.sliders["playback.progress"].adjust(toNormalizedSliderPosition: 0.92)
            XCTAssertTrue(app.staticTexts[nextTitle].waitForExistence(timeout: 15),
                          "Playback must automatically advance to \(nextTitle)")
            XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 10))
        }
        revealControls()
        XCTAssertFalse(app.buttons["下一个视频"].isEnabled)
        app.sliders["playback.progress"].adjust(toNormalizedSliderPosition: 0.92)
        XCTAssertTrue(app.buttons["播放"].waitForExistence(timeout: 15),
                      "The final video must finish before closing")
        XCTAssertGreaterThan(progressSeconds(app.sliders["playback.progress"]), 43)
        app.buttons["返回资料库"].tap()
        if UIDevice.current.userInterfaceIdiom == .phone { waitForPortrait(true) }
        XCTAssertTrue(app.buttons["video.开场.mp4"].waitForExistence(timeout: 8))
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.staticTexts["settings.version"].waitForExistence(timeout: 5),
                      "The library must remain responsive after closing an ended queue")
        app.buttons["tab.categories"].tap()
        app.buttons["video.开场.mp4"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 15),
                      "A fresh playback session must still start")
    }

    func testLargeLibraryFinalEpisodeCloseAndCachedRelaunch() {
        app.buttons["source.本机测试"].tap()
        let folder = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "folder.第")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 10))
        let path = String(folder.identifier.dropFirst("folder.".count))
        folder.tap()
        let video = app.buttons["video.\(path)/视频028.mp4"]
        let last = app.buttons["video.\(path)/视频030.mp4"]
        for _ in 0..<10 where !last.isHittable { app.scrollViews.firstMatch.swipeUp() }
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(video.isHittable)
        // iOS 26's floating search field can overlap the bottom card's center.
        video.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["30 部视频"].exists)
        app.buttons["全屏播放"].tap()
        if UIDevice.current.userInterfaceIdiom == .phone { waitForPortrait(false) }
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForPortrait(false)
        for title in ["视频029.mp4", "视频030.mp4"] {
            revealControls()
            app.sliders["playback.progress"].adjust(toNormalizedSliderPosition: 0.92)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 15))
            XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 10))
        }
        revealControls()
        XCTAssertFalse(app.buttons["下一个视频"].isEnabled)
        app.sliders["playback.progress"].adjust(toNormalizedSliderPosition: 0.92)
        XCTAssertTrue(app.buttons["播放"].waitForExistence(timeout: 15))
        app.buttons["返回资料库"].tap()
        if UIDevice.current.userInterfaceIdiom == .phone { waitForPortrait(true) }
        // Rotation can change the lazy grid's scroll offset and evict video 028.
        // Verify the actual return destination, then perform a new navigation action.
        XCTAssertTrue(app.navigationBars[path].waitForExistence(timeout: 8))
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.staticTexts["settings.version"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-testing-reuse-library"]
        let launchStarted = Date()
        app.launch()
        app.buttons["tab.folders"].tap()
        let source = app.buttons["source.本机测试"]
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "本地"), evaluatedWith: source)
        waitForExpectations(timeout: 10)
        print("CACHED_3000_LAUNCH_TO_READY_SECONDS: \(Date().timeIntervalSince(launchStarted))")
        XCTAssertTrue(source.label.replacingOccurrences(of: ",", with: "").contains("3000"))
    }

    func testLargeLibraryRootQueueCanCloseAfterFinalEpisode() {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-testing-reuse-library", "-ui-testing-large-queue-tail"]
        app.launch()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "3,?000 部视频")).firstMatch.exists)
        app.buttons["全屏播放"].tap()
        if UIDevice.current.userInterfaceIdiom == .phone { waitForPortrait(false) }
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForPortrait(false)
        for title in ["视频029.mp4", "视频030.mp4"] {
            revealControls()
            app.sliders["playback.progress"].adjust(toNormalizedSliderPosition: 0.92)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 15))
            XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 10))
        }
        revealControls()
        XCTAssertFalse(app.buttons["下一个视频"].isEnabled)
        app.sliders["playback.progress"].adjust(toNormalizedSliderPosition: 0.92)
        XCTAssertTrue(app.buttons["播放"].waitForExistence(timeout: 15))
        app.buttons["返回资料库"].tap()
        if UIDevice.current.userInterfaceIdiom == .phone { waitForPortrait(true) }
        XCTAssertTrue(app.buttons["tab.settings"].waitForExistence(timeout: 8))
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.staticTexts["settings.version"].waitForExistence(timeout: 5))
    }

    func testThreeLevelFoldersAndOfflineIndexRemainBrowseable() {
        app.buttons["source.本机测试"].tap()
        app.buttons["folder.二级目录"].tap()
        XCTAssertTrue(app.buttons["video.二级目录/片段二.mp4"].waitForExistence(timeout: 5))
        app.buttons["folder.二级目录/三级目录"].tap()
        XCTAssertTrue(app.buttons["video.二级目录/三级目录/片段三.mp4"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["source.离线硬盘"].tap()
        XCTAssertTrue(app.buttons["source.reauthorize"].waitForExistence(timeout: 5))
        app.buttons["folder.已索引"].tap()
        XCTAssertTrue(app.buttons["video.已索引/离线片段.mp4"].waitForExistence(timeout: 5))
        app.buttons["video.已索引/离线片段.mp4"].tap()
        XCTAssertTrue(app.alerts["提示"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["playback.canvas"].exists)
    }

    func testSearchKeepsRootSectionsAndFindsNestedVideo() {
        app.buttons["tab.home"].tap()
        app.buttons["home.search"].tap()
        let search = app.textFields["library.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap(); search.typeText("片段三")
        XCTAssertTrue(app.buttons["video.二级目录/三级目录/片段三.mp4"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["video.开场.mp4"].exists)
        app.buttons["清除搜索"].tap()
        XCTAssertTrue(app.buttons["video.开场.mp4"].waitForExistence(timeout: 3))
        app.buttons["取消搜索"].tap()
        XCTAssertTrue(app.buttons["home.featured.play"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["library.search"].exists)
        app.buttons["home.sources"].tap()
        XCTAssertTrue(app.buttons["source.本机测试"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["source.离线硬盘"].exists)
    }

    func testDoubleTapRateAndQueueControls() {
        showAllVideos()
        let first = app.buttons["video.开场.mp4"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 10))
        let canvas = app.otherElements["playback.canvas"]
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).doubleTap()
        XCTAssertTrue(app.buttons["播放"].waitForExistence(timeout: 3))
        app.buttons["播放"].tap()
        app.buttons["1×"].tap()
        let speed = XCTAttachment(screenshot: app.screenshot())
        speed.name = "Playback speed panel"; speed.lifetime = .keepAlways; add(speed)
        app.buttons["1.5×"].tap()
        XCTAssertTrue(app.buttons["1.5×"].waitForExistence(timeout: 3))
        app.buttons["下一个视频"].tap()
        XCTAssertTrue(app.staticTexts["片段二.mp4"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["上一个视频"].isEnabled)
        app.buttons["上一个视频"].tap()
        XCTAssertTrue(app.staticTexts["开场.mp4"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["上一个视频"].isEnabled)
    }

    func testBackgroundPausesAndRequiresManualResume() {
        openVideo()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["播放"].waitForExistence(timeout: 5))
        app.buttons["播放"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 5))
    }
    func testCanvasSeekGesture() {
        openVideo()
        pausePlayback()
        let slider = app.sliders["playback.progress"]
        slider.adjust(toNormalizedSliderPosition: 0.1)
        let before = progressSeconds(slider)
        let canvas = app.otherElements["playback.canvas"]
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.22))
            .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.22)))
        expectation(for: NSPredicate { _, _ in self.progressSeconds(slider) > before + 5 }, evaluatedWith: slider)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["播放"].exists)
    }

    func testTabletRotationKeepsControlsAvailable() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad rotation") }
        openVideo()
        pausePlayback()
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForPortrait(false)
        revealControls()
        app.buttons["播放"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 3))
        app.buttons["返回资料库"].tap()
        waitForPortrait(false)
        XCTAssertTrue(app.buttons["video.开场.mp4"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        waitForPortrait(true)
    }

    func testTabsCategoriesSettingsAndRetainedFolderNavigation() {
        app.buttons["source.本机测试"].tap()
        app.buttons["folder.二级目录"].tap()
        app.buttons["tab.categories"].tap()
        XCTAssertTrue(app.buttons["category.available"].waitForExistence(timeout: 3))
        let categories = XCTAttachment(screenshot: app.screenshot())
        categories.name = "Library categories"; categories.lifetime = .keepAlways; add(categories)
        app.buttons["category.offline"].tap()
        XCTAssertTrue(app.buttons["video.已索引/离线片段.mp4"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["video.开场.mp4"].exists)
        app.buttons["video.已索引/离线片段.mp4"].tap()
        XCTAssertTrue(app.alerts["提示"].waitForExistence(timeout: 3))
        app.alerts["提示"].buttons["知道了"].tap()
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.staticTexts["settings.version"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["settings.version"].label.contains("0.2.1 (12)"))
        app.buttons["settings.clear-cache"].tap()
        XCTAssertTrue(app.buttons["settings.clear-cache"].waitForExistence(timeout: 3))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "已清除"), evaluatedWith: app.buttons["settings.clear-cache"])
        waitForExpectations(timeout: 10)
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "Library settings"; settings.lifetime = .keepAlways; add(settings)
        app.buttons["tab.folders"].tap()
        XCTAssertTrue(app.buttons["video.二级目录/片段二.mp4"].waitForExistence(timeout: 5), "Each tab retains its own folder position")
        app.buttons["tab.categories"].tap()
        XCTAssertTrue(app.buttons["video.已索引/离线片段.mp4"].waitForExistence(timeout: 5), "Category navigation survives tab changes")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["category.largeFiles"].tap()
        XCTAssertTrue(app.staticTexts["暂无符合条件的视频"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["category.format.MP4"].tap()
        XCTAssertTrue(app.buttons["video.开场.mp4"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["video.已索引/离线片段.mp4"].exists)
    }

    func testFullscreenPlaylistAndDirectLockControls() {
        showAllVideos()
        app.buttons["video.开场.mp4"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 15))
        pausePlayback()
        app.buttons["全屏播放"].tap()
        if UIDevice.current.userInterfaceIdiom == .phone {
            waitForPortrait(false)
            XCUIDevice.shared.orientation = .landscapeLeft
            waitForPortrait(false)
        }
        revealControls()
        let playlist = app.buttons["playlist.开场.mp4"]
        if playlist.isHittable { app.buttons["显示或隐藏播放列表"].tap() }
        XCTAssertFalse(playlist.isHittable)
        app.buttons["显示或隐藏播放列表"].tap()
        XCTAssertTrue(playlist.waitForExistence(timeout: 3))
        XCTAssertTrue(playlist.isHittable)
        app.buttons["锁定播放控制"].tap()
        let unlock = app.buttons["解锁播放控制"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 3))
        XCTAssertTrue(unlock.isHittable, "Unlock must remain usable beside a display cutout")
        XCTAssertFalse(playlist.isHittable)
        let locked = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        locked.name = "Fullscreen locked controls"; locked.lifetime = .keepAlways; add(locked)
        unlock.tap()
        XCTAssertTrue(app.buttons["播放"].waitForExistence(timeout: 3))
        app.buttons["显示或隐藏播放列表"].tap()
        let fullscreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        fullscreen.name = "Cinema fullscreen controls"; fullscreen.lifetime = .keepAlways; add(fullscreen)
        app.buttons["返回资料库"].tap()
        XCTAssertTrue(app.buttons["video.开场.mp4"].waitForExistence(timeout: 5))
    }

    func testGuideAndFolderManagementKeepLibraryConnections() {
        let folders = XCTAttachment(screenshot: app.screenshot())
        folders.name = "Library folders"; folders.lifetime = .keepAlways; add(folders)
        app.buttons["管理文件夹"].tap()
        XCTAssertTrue(app.staticTexts["连接你的收藏"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["添加目录"].exists)
        let manager = XCTAttachment(screenshot: app.screenshot())
        manager.name = "Folder management"; manager.lifetime = .keepAlways; add(manager)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["source.本机测试"].exists)
        XCTAssertTrue(app.buttons["source.离线硬盘"].exists)
        app.buttons["tab.settings"].tap()
        app.buttons["settings.guide"].tap()
        XCTAssertTrue(app.staticTexts["轻触，即刻掌控"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["settings.version"].waitForExistence(timeout: 3))
    }

    func testHomeHeroLayoutAndBrowseShortcuts() {
        app.buttons["tab.home"].tap()
        let hero = app.descendants(matching: .any).matching(identifier: "home.featured").firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home.browse.all"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["home.search"].frame.minY, hero.frame.minY + 20,
                                    "Home navigation reserves space above its controls")
        XCTAssertLessThan(app.buttons["home.browse.all"].frame.minY, app.buttons["home.featured.play"].frame.minY)
        XCTAssertTrue(app.buttons["home.featured.play"].isHittable)
        XCTAssertTrue(app.staticTexts["home.library-title"].isHittable, "The first shelf appears on the initial screen")
        XCTAssertFalse(app.textFields["library.search"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Immersive home"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["home.browse.available"].tap()
        XCTAssertTrue(app.buttons["video.开场.mp4"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["video.已索引/离线片段.mp4"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["home.sources"].tap()
        app.buttons["source.本机测试"].tap()
        XCTAssertTrue(app.buttons["folder.二级目录"].waitForExistence(timeout: 5))
    }

    func testHomeBottomRemainsAboveTabs() {
        app.buttons["tab.home"].tap()
        let scroll = app.scrollViews["home.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0..<4 { scroll.swipeUp(velocity: .fast) }
        let last = app.buttons.matching(identifier: "video.已索引/离线片段.mp4").allElementsBoundByIndex.last!
        XCTAssertTrue(last.isHittable)
        let tabs = app.buttons["tab.home"]
        let bottom = XCTAttachment(screenshot: app.screenshot())
        bottom.name = "Home bottom above tabs"; bottom.lifetime = .keepAlways; add(bottom)
        XCTAssertLessThanOrEqual(last.frame.maxY, tabs.frame.minY - 8,
                                 "The last shelf must scroll completely above the tab bar")
        for _ in 0..<4 { scroll.swipeDown(velocity: .fast) }
        XCTAssertTrue(app.buttons["home.browse.all"].isHittable)
        XCTAssertTrue(app.buttons["home.featured.play"].isHittable)
    }

    func testFullscreenPlaylistDrawer() {
        showAllVideos()
        app.buttons["video.开场.mp4"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 15))
        pausePlayback()
        app.buttons["全屏播放"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForPortrait(false)
        revealControls()
        let row = app.buttons["playlist.开场.mp4"]
        if row.isHittable { app.buttons["显示或隐藏播放列表"].tap() }
        let canvas = app.otherElements["playback.canvas"]
        let slider = app.sliders["playback.progress"]
        let before = progressSeconds(slider)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.42))
            .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.42)))
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(row.isHittable, "Swiping left from the right edge opens the playlist")
        XCTAssertEqual(progressSeconds(slider), before, accuracy: 1.5, "Opening the playlist must not seek")
        let sidebar = app.otherElements["playback.playlist"]
        let title = app.staticTexts["playlist.title.二级目录/风景纪实 第一集 山川与城市的光影旅程.mp4"]
        if !title.isHittable { app.scrollViews["playback.playlist.scroll"].swipeUp() }
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(title.frame.width, 140, "Long titles must retain readable width beside the cover")
        XCTAssertLessThanOrEqual(title.frame.maxX, sidebar.frame.maxX)
        let subtitle = app.staticTexts["playlist.subtitle.二级目录/风景纪实 第一集 山川与城市的光影旅程.mp4"]
        XCTAssertTrue(subtitle.isHittable)
        let opened = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        opened.name = "Compact fullscreen playlist"; opened.lifetime = .keepAlways; add(opened)
        Thread.sleep(forTimeInterval: 1)
        sidebar.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.45))
            .press(forDuration: 0.05, thenDragTo: sidebar.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45)))
        XCTAssertTrue(sidebar.waitForNonExistence(timeout: 3), "Swiping right closes the playlist")
        XCTAssertTrue(app.staticTexts["开场.mp4"].exists, "Closing the drawer must not select a row")
        XCTAssertTrue(app.buttons["播放"].exists)
        // The same edge gesture is disabled while playback controls are locked.
        app.buttons["锁定播放控制"].tap()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.42))
            .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.42)))
        XCTAssertFalse(row.exists)
        app.buttons["解锁播放控制"].tap()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.42))
            .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.42)))
        XCTAssertTrue(sidebar.waitForExistence(timeout: 3))
        let next = app.buttons["playlist.二级目录/风景纪实 第一集 山川与城市的光影旅程.mp4"]
        if !next.isHittable { app.scrollViews["playback.playlist.scroll"].swipeUp() }
        next.tap()
        XCTAssertTrue(app.staticTexts["风景纪实 第一集 山川与城市的光影旅程.mp4"].waitForExistence(timeout: 5),
                      "A tap still selects a video after swiping the drawer")
        revealControls()
        app.buttons["返回资料库"].tap()
        if UIDevice.current.userInterfaceIdiom == .phone { waitForPortrait(true) }
    }

    func testFeaturedPlaybackReturnsToHomeWithTabs() {
        app.buttons["tab.home"].tap()
        XCTAssertTrue(app.buttons["home.featured.play"].waitForExistence(timeout: 10))
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "Cinema home"; home.lifetime = .keepAlways; add(home)
        app.buttons["home.featured.info"].tap()
        XCTAssertTrue(app.staticTexts["video.info.path"].waitForExistence(timeout: 3))
        app.buttons["完成"].tap()
        app.buttons["home.featured.play"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["tab.home"].isHittable, "Library tabs cannot be tapped through playback")
        app.buttons["返回资料库"].tap()
        XCTAssertTrue(app.buttons["home.featured.play"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.settings"].isHittable)
        waitForPortrait(true)
    }

}
