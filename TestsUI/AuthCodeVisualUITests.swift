import XCTest

final class AuthCodeVisualUITests: XCTestCase {
    @MainActor
    func testCredentialSheetsAtSmallestTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-auth-session",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXS"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["main-tab-profile"].waitForExistence(timeout: 30))
        app.buttons["main-tab-profile"].tap()
        app.buttons["Sign in"].tap()
        let form = app.scrollViews["auth-form"]
        XCTAssertTrue(form.waitForExistence(timeout: 10))
        XCTAssertTrue(form.buttons["Sign in"].isHittable)
        let login = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        login.name = "Sign in smallest text"
        login.lifetime = .keepAlways
        add(login)
        form.buttons["Sign up"].tap()
        XCTAssertTrue(app.staticTexts["Create account"].waitForExistence(timeout: 5))
        XCTAssertTrue(form.buttons["Create account"].isHittable)
        let terms = form.switches["I agree to the terms and privacy policy."]
        XCTAssertTrue(terms.exists)
        XCTAssertEqual(terms.value as? String, "0")
        XCTAssertGreaterThanOrEqual(terms.frame.height, 44 * form.frame.width / app.frame.width - 0.5)
        terms.tap()
        XCTAssertEqual(terms.value as? String, "1")
        terms.tap()
        XCTAssertEqual(terms.value as? String, "0")
        let signup = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        signup.name = "Create account smallest text"
        signup.lifetime = .keepAlways
        add(signup)
    }

    @MainActor
    func testCredentialSheetsExplainNextStepAndPreservePasswordOnVisibilityToggle() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-auth-session"]
        app.launch()
        XCTAssertTrue(app.buttons["main-tab-profile"].waitForExistence(timeout: 30))
        app.buttons["main-tab-profile"].tap()
        app.buttons["Sign in"].tap()
        let form = app.scrollViews["auth-form"]
        XCTAssertTrue(form.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["View your bookings and trip updates."].exists)
        XCTAssertFalse(app.staticTexts["Nexus Travel"].exists)
        let sheetScale = form.frame.width / app.frame.width
        let bottomGap = form.frame.maxY - form.buttons["Sign up"].frame.maxY
        XCTAssertLessThanOrEqual(bottomGap, 40 * sheetScale + 0.5)
        let login = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        login.name = "Polished sign in"
        login.lifetime = .keepAlways
        add(login)

        let password = form.secureTextFields["Password"]
        password.tap()
        password.typeText("Testing123")
        let show = form.buttons["Show password"]
        let scale = form.frame.width / app.frame.width
        XCTAssertGreaterThanOrEqual(show.frame.height, 48 * scale - 0.5)
        show.tap()
        XCTAssertEqual(form.textFields["Password"].value as? String, "Testing123")
        form.buttons["Hide password"].tap()
        XCTAssertTrue(form.secureTextFields["Password"].exists)
        form.buttons["Show password"].tap()
        XCTAssertEqual(form.textFields["Password"].value as? String, "Testing123")
        form.swipeUp()
        form.buttons["Sign up"].tap()
        XCTAssertTrue(app.staticTexts["Create account"].waitForExistence(timeout: 5))
        form.swipeDown()
        XCTAssertTrue(app.staticTexts["We’ll email you a code to verify your account."].exists)
        XCTAssertFalse(app.staticTexts["Nexus Travel"].exists)
        let signup = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        signup.name = "Polished create account"
        signup.lifetime = .keepAlways
        add(signup)
    }

    @MainActor
    func testCredentialSheetsKeepActionsReachableAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-auth-session",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["main-tab-profile"].waitForExistence(timeout: 30))
        app.buttons["main-tab-profile"].tap()
        app.buttons["Sign in"].tap()
        let form = app.scrollViews["auth-form"]
        XCTAssertTrue(form.waitForExistence(timeout: 10))
        XCTAssertLessThanOrEqual(app.buttons["Close"].frame.height, 48)
        let header = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        header.name = "Sign in accessibility header"
        header.lifetime = .keepAlways
        add(header)
        form.swipeUp()
        XCTAssertTrue(form.buttons["Sign in"].isHittable)
        XCTAssertTrue(form.buttons["Sign up"].isHittable)
        let login = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        login.name = "Sign in accessibility"
        login.lifetime = .keepAlways
        add(login)
        form.buttons["Sign up"].tap()
        XCTAssertTrue(app.staticTexts["Create account"].waitForExistence(timeout: 5))
        form.swipeUp()
        form.swipeUp()
        XCTAssertTrue(form.buttons["Create account"].isHittable)
        XCTAssertTrue(form.buttons["Sign in"].isHittable)
        let signup = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        signup.name = "Signup accessibility"
        signup.lifetime = .keepAlways
        add(signup)
    }

    @MainActor
    func testCredentialSheetsUseAuthControlSizeAndInlineValidation() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-auth-session"]
        app.launch()
        XCTAssertTrue(app.buttons["main-tab-profile"].waitForExistence(timeout: 30))
        app.buttons["main-tab-profile"].tap()
        app.buttons["Sign in"].tap()
        let form = app.scrollViews["auth-form"]
        XCTAssertTrue(form.waitForExistence(timeout: 10))
        // Native inset sheets scale their accessibility frames with sheet width.
        let loginScale = form.frame.width / app.frame.width
        XCTAssertGreaterThanOrEqual(form.buttons["Sign in"].frame.height, 60 * loginScale - 0.5)
        XCTAssertGreaterThanOrEqual(form.buttons["Forgot password?"].frame.height, 44 * loginScale - 0.5)
        form.buttons["Sign in"].tap()
        XCTAssertTrue(app.staticTexts["Please enter a valid email address."].waitForExistence(timeout: 5))
        XCTAssertTrue(form.buttons["Sign in"].isHittable)
        let login = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        login.name = "Sign in inline validation"
        login.lifetime = .keepAlways
        add(login)
        app.buttons["Sign up"].tap()
        XCTAssertTrue(app.staticTexts["Create account"].waitForExistence(timeout: 5))
        let signupScale = form.frame.width / app.frame.width
        XCTAssertGreaterThanOrEqual(form.buttons["Create account"].frame.height, 60 * signupScale - 0.5)
        form.buttons["Create account"].tap()
        form.swipeUp()
        XCTAssertTrue(form.buttons["Create account"].isHittable)
        let signup = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        signup.name = "Signup inline validation"
        signup.lifetime = .keepAlways
        add(signup)
    }

    @MainActor
    func testPasswordRecoveryReusesRoundedAuthSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-auth-session"]
        app.launch()
        XCTAssertTrue(app.buttons["main-tab-profile"].waitForExistence(timeout: 30))
        app.buttons["main-tab-profile"].tap()
        XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 10))
        app.buttons["Sign in"].tap()
        XCTAssertTrue(app.buttons["Forgot password?"].waitForExistence(timeout: 10))
        app.buttons["Forgot password?"].tap()
        XCTAssertTrue(app.staticTexts["Reset password"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Nexus Travel"].exists)
        XCTAssertTrue(app.buttons["Back to sign in"].exists)
        XCTAssertTrue(app.buttons["Send code"].isHittable)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Password recovery request"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testEmailCodeStatesRenderWithoutNetwork() {
        let states = ["entry", "submitting", "invalid", "expired", "rateLimited", "success"]
        for state in states {
            let app = XCUIApplication()
            app.launchArguments = ["--auth-preview=\(state)"]
            app.launch()
            XCTAssertTrue(app.staticTexts["Verify your email"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["Change email"].exists)
            XCTAssertTrue(app.buttons["Back to sign in"].exists)
            XCTAssertTrue(app.buttons["Verify email"].exists)
            // Compact sheets use the shared 16-point bottom spacing token.
            XCTAssertLessThanOrEqual(app.buttons["Back to sign in"].frame.maxY, app.frame.maxY - 16)
            XCTAssertFalse(app.staticTexts["Nexus Travel"].exists)
            XCTAssertTrue(app.textFields["Six-digit email code"].exists)
            let image = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: image)
            attachment.name = "Email code \(state)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }

    @MainActor
    func testEmailCodeSheetKeepsActionsAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--auth-preview=entry",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Verify your email"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Six-digit email code"].exists)
        XCTAssertTrue(app.buttons["Verify email"].exists)
        XCTAssertTrue(app.buttons["Back to sign in"].exists)
        XCTAssertGreaterThanOrEqual(app.buttons["Change email"].frame.minY, app.staticTexts["afiz@example.com"].frame.maxY)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Email code accessibility"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.scrollViews["auth-code-sheet"].swipeUp()
        XCTAssertTrue(app.buttons["Verify email"].isHittable)
        XCTAssertTrue(app.buttons["Back to sign in"].isHittable)
    }

    @MainActor
    func testEmailCodeWithKeyboardKeepsVerificationReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--auth-preview=entry"]
        app.launch()
        let input = app.textFields["Six-digit email code"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("123456")
        XCTAssertEqual(input.value as? String, "123456")
        app.scrollViews["auth-code-sheet"].swipeUp()
        XCTAssertTrue(app.buttons["Verify email"].isHittable)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Email code keyboard"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
