import XCTest

@testable import AppDelta

final class LocalizationTests: XCTestCase {
  private var previousLanguage: String?

  override func setUp() {
    super.setUp()
    previousLanguage = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
  }

  override func tearDown() {
    if let previousLanguage {
      UserDefaults.standard.set(previousLanguage, forKey: AppLanguage.storageKey)
    } else {
      UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
    }
    super.tearDown()
  }

  func testEnglishAndKoreanLabels() {
    UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
    XCTAssertEqual(L10n.text("Overview"), "Overview")
    XCTAssertEqual(DeltaCategory.signing.title, "Trust & Signing")

    UserDefaults.standard.set(AppLanguage.korean.rawValue, forKey: AppLanguage.storageKey)
    XCTAssertEqual(L10n.text("Overview"), "개요")
    XCTAssertEqual(DeltaCategory.signing.title, "신뢰 및 서명")
  }

  func testHTMLReportUsesSelectedLanguage() throws {
    let report = DeltaEngine().compare(
      before: TestFixtures.snapshot(),
      after: TestFixtures.snapshot(version: "2.0")
    )

    UserDefaults.standard.set(AppLanguage.korean.rawValue, forKey: AppLanguage.storageKey)
    let koreanHTML = String(
      decoding: try ReportExporter().data(for: report, format: .html), as: UTF8.self)
    XCTAssertTrue(koreanHTML.contains("<html lang=\"ko\">"))
    XCTAssertTrue(koreanHTML.contains("App Delta 보고서"))
    XCTAssertTrue(koreanHTML.contains("기준 버전"))

    UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
    let englishHTML = String(
      decoding: try ReportExporter().data(for: report, format: .html), as: UTF8.self)
    XCTAssertTrue(englishHTML.contains("<html lang=\"en\">"))
    XCTAssertTrue(englishHTML.contains("App Delta Report"))
    XCTAssertTrue(englishHTML.contains("Baseline"))
  }

  func testDynamicComponentLabelsAreLocalized() {
    UserDefaults.standard.set(AppLanguage.korean.rawValue, forKey: AppLanguage.storageKey)
    let component = AppSnapshot.Component(
      path: "Contents/MacOS/Fixture", kind: .executable, bytes: 100)
    let report = DeltaEngine().compare(
      before: TestFixtures.snapshot(),
      after: TestFixtures.snapshot(components: [component])
    )

    XCTAssertEqual(
      report.items.first { $0.id == "component:executable:Contents/MacOS/Fixture" }?.detail,
      "실행 파일 구성요소입니다.")
  }
}
