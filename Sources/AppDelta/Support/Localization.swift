import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
  case system
  case english
  case korean

  static let storageKey = "appDelta.language"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .system: "시스템 설정 / System"
    case .english: "English"
    case .korean: "한국어"
    }
  }

  var effectiveCode: String {
    switch self {
    case .english: "en"
    case .korean: "ko"
    case .system:
      Locale.preferredLanguages.first?.lowercased().hasPrefix("ko") == true ? "ko" : "en"
    }
  }

  var locale: Locale { Locale(identifier: effectiveCode) }

  static var current: AppLanguage {
    let value = UserDefaults.standard.string(forKey: storageKey) ?? AppLanguage.system.rawValue
    return AppLanguage(rawValue: value) ?? .system
  }
}

enum L10n {
  static func text(_ english: String) -> String {
    guard AppLanguage.current.effectiveCode == "ko" else { return english }
    return korean[english] ?? english
  }

  static func format(_ english: String, _ arguments: CVarArg...) -> String {
    String(format: text(english), locale: AppLanguage.current.locale, arguments: arguments)
  }

  private static let korean: [String: String] = [
    "%@ artifact": "%@ 아티팩트",
    "%@ component.": "%@ 구성요소입니다.",
    "%@: %@": "%@: %@",
    ", executable": ", 실행 가능",
    "Added": "추가됨",
    "Adjust the category, search, or severity filter.": "카테고리, 검색어 또는 중요도 필터를 조정하세요.",
    "All changes": "모든 변경",
    "Allows a sandboxed app to initiate network connections.": "샌드박스 앱이 외부 네트워크 연결을 시작할 수 있게 합니다.",
    "Allows a sandboxed app to listen for incoming network connections.":
      "샌드박스 앱이 들어오는 네트워크 연결을 수신할 수 있게 합니다.",
    "Allows a sandboxed app to request audio input access. It does not prove audio is recorded.":
      "샌드박스 앱이 마이크 접근을 요청할 수 있게 합니다. 실제 녹음을 의미하지는 않습니다.",
    "Allows a sandboxed app to request camera access. It does not prove the camera is used.":
      "샌드박스 앱이 카메라 접근을 요청할 수 있게 합니다. 실제 사용을 의미하지는 않습니다.",
    "Allows a sandboxed app to request control of other applications through Apple Events.":
      "샌드박스 앱이 Apple Events를 통해 다른 앱의 제어를 요청할 수 있게 합니다.",
    "Allows creation of executable memory for just-in-time compilation.":
      "JIT 컴파일을 위한 실행 가능 메모리 생성을 허용합니다.",
    "Allows debuggers to attach to the process and is normally disabled in distribution builds.":
      "디버거가 프로세스에 연결할 수 있게 하며 배포 빌드에서는 일반적으로 비활성화됩니다.",
    "Allows the app to activate bundled system extensions with user approval.":
      "사용자 승인 후 포함된 시스템 확장을 활성화할 수 있게 합니다.",
    "Analysis notes": "분석 참고 사항",
    "Analyze": "분석",
    "Analyze Again": "다시 분석",
    "Application": "애플리케이션",
    "Application Name": "애플리케이션 이름",
    "App language": "앱 언어",
    "App Sandbox": "앱 샌드박스",
    "App Extension": "앱 확장",
    "Apple Events Automation": "Apple Events 자동화",
    "App Delta does not determine whether an app is safe or malicious. It reports observable changes in signing, declared capabilities, bundled components, package contents, and files.":
      "App Delta는 앱의 안전성이나 악성 여부를 판정하지 않습니다. 서명, 선언된 권한, 포함된 구성요소, 패키지 내용 및 파일에서 관찰된 변경만 보여줍니다.",
    "App Delta does not determine whether an application is safe or malicious. It reports changes in signatures, declared capabilities, bundled code, package contents, and file metadata.":
      "App Delta는 애플리케이션의 안전성이나 악성 여부를 판정하지 않습니다. 서명, 선언된 권한, 포함된 코드, 패키지 내용 및 파일 메타데이터의 변경만 보여줍니다.",
    "App Delta Report": "App Delta 보고서",
    "Artifacts": "아티팩트",
    "Attention and important": "주의 및 중요",
    "Background & Login": "백그라운드 및 로그인",
    "Baseline": "기준 버전",
    "BASELINE": "기준 버전",
    "Build": "빌드",
    "Building comparison…": "비교 결과 생성 중…",
    "Bundle Identifier": "번들 식별자",
    "Bundle Size": "번들 크기",
    "Camera Capability": "카메라 권한",
    "Cancel": "취소",
    "Candidate": "비교 대상",
    "CANDIDATE": "비교 대상",
    "Certificate Chain": "인증서 체인",
    "Capabilities": "권한",
    "Change": "변경",
    "Changes": "변경 사항",
    "Changed": "변경됨",
    "Choose": "선택",
    "Choose Baseline Artifact": "기준 아티팩트 선택",
    "Choose Baseline…": "기준 버전 선택…",
    "Choose Candidate Artifact": "비교 대상 아티팩트 선택",
    "Choose Candidate…": "비교 대상 선택…",
    "Choose a .app, .dmg, .pkg, or .mpkg artifact.": ".app, .dmg, .pkg 또는 .mpkg 아티팩트를 선택하세요.",
    "Choose…": "선택…",
    "Clear": "지우기",
    "Code signature entitlements": "코드 서명 권한",
    "Comparison": "비교",
    "Compare Artifacts": "아티팩트 비교",
    "Compare signatures, declared capabilities, privacy descriptions, background helpers, embedded components, and files — entirely on this Mac.":
      "서명, 선언된 권한, 개인정보 보호 설명, 백그라운드 도우미, 포함된 구성요소와 파일을 이 Mac에서만 비교합니다.",
    "Components": "구성요소",
    "Category": "카테고리",
    "Directory": "디렉터리",
    "Debug Task Access": "디버그 작업 접근",
    "Declared required-reason APIs or collected-data metadata changed. This declaration is not evidence of runtime use.":
      "필수 사유 API 또는 수집 데이터 메타데이터 선언이 변경되었습니다. 이 선언은 실제 사용의 증거가 아닙니다.",
    "Declares a temporary sandbox exception. Its presence does not establish how the app uses it.":
      "임시 샌드박스 예외를 선언합니다. 선언만으로 앱의 실제 사용 방식을 알 수는 없습니다.",
    "Declares one or more Network Extension capabilities such as VPN or traffic filtering.":
      "VPN 또는 트래픽 필터링 같은 하나 이상의 Network Extension 기능을 선언합니다.",
    "Detailed values and evidence appear here.": "세부 값과 근거가 여기에 표시됩니다.",
    "Disk Image": "디스크 이미지",
    "Drop .app, .dmg, or .pkg": ".app, .dmg 또는 .pkg를 놓으세요",
    "Evidence": "근거",
    "Executable": "실행 파일",
    "Export": "내보내기",
    "Export App Delta Report": "App Delta 보고서 내보내기",
    "Export HTML Report…": "HTML 보고서 내보내기…",
    "Export JSON…": "JSON 내보내기…",
    "File inventory metadata changed. Timestamps are intentionally ignored.":
      "파일 목록 메타데이터가 변경되었습니다. 시간 정보는 의도적으로 비교하지 않습니다.",
    "Files": "파일",
    "Framework": "프레임워크",
    "Filter": "필터",
    "Gatekeeper Assessment": "Gatekeeper 평가",
    "Gatekeeper Diagnostic": "Gatekeeper 진단",
    "Gatekeeper Source": "Gatekeeper 출처",
    "Generated %@ · %d observable changes": "%@ 생성 · 관찰된 변경 %d개",
    "Generated locally by App Delta. No artifact data was uploaded.":
      "App Delta가 이 Mac에서 생성했습니다. 아티팩트 데이터는 업로드되지 않았습니다.",
    "Hardened Runtime": "Hardened Runtime",
    "HTML Report…": "HTML 보고서…",
    "Important": "중요",
    "Important only": "중요 항목만",
    "Incoming Network Connections": "들어오는 네트워크 연결",
    "Inspector": "세부 정보",
    "Interpretation boundary:": "해석 범위:",
    "Inspecting baseline…": "기준 버전 분석 중…",
    "Inspecting candidate…": "비교 대상 분석 중…",
    "Installer Package": "설치 패키지",
    "Item": "항목",
    "JIT-Compiled Code": "JIT 컴파일 코드",
    "JSON…": "JSON…",
    "Language": "언어",
    "Launch Agent": "LaunchAgent",
    "Launch Daemon": "LaunchDaemon",
    "Library": "라이브러리",
    "Login Item": "로그인 항목",
    "Library Validation Disabled": "라이브러리 검증 비활성화",
    "Limits access to system resources and user data unless additional capabilities are declared.":
      "추가 권한이 선언되지 않은 경우 시스템 자원과 사용자 데이터 접근을 제한합니다.",
    "Microphone Capability": "마이크 권한",
    "Minimum macOS": "최소 macOS",
    "Minimum severity": "최소 중요도",
    "Network Extension": "네트워크 확장",
    "Nested Application": "중첩 애플리케이션",
    "New version to inspect": "검사할 새 버전",
    "No matching changes": "조건에 맞는 변경 없음",
    "No diagnostic text was returned.": "진단 메시지가 반환되지 않았습니다.",
    "Not applicable": "해당 없음",
    "Not present": "없음",
    "Observable changes": "관찰된 변경",
    "Observable metadata changed between the selected artifacts.":
      "선택한 아티팩트 사이에서 관찰 가능한 메타데이터가 변경되었습니다.",
    "Outgoing Network Connections": "외부 네트워크 연결",
    "Overview": "개요",
    "Previous or trusted version": "이전 또는 신뢰하는 버전",
    "Privacy": "개인정보 보호",
    "Privacy declaration": "개인정보 보호 선언",
    "Privacy manifest": "개인정보 보호 매니페스트",
    "Privacy manifest: %@": "개인정보 보호 매니페스트: %@",
    "Plugin": "플러그인",
    "Regular": "일반 파일",
    "Removed": "제거됨",
    "Replace…": "바꾸기…",
    "Report": "보고서",
    "Search changes": "변경 사항 검색",
    "See what changed inside a Mac app": "Mac 앱 내부에서 무엇이 바뀌었는지 확인하세요",
    "Select a change": "변경 항목을 선택하세요",
    "Selected apps are inspected, never launched or uploaded.": "선택한 앱은 분석만 하며 실행하거나 업로드하지 않습니다.",
    "Settings": "설정",
    "Show or hide the detail inspector": "세부 정보 영역 표시 또는 숨기기",
    "Signature Verification": "서명 검증",
    "Signing Identifier": "서명 식별자",
    "Swap": "서로 바꾸기",
    "Swap baseline and candidate": "기준 버전과 비교 대상 바꾸기",
    "Swap Baseline and Candidate": "기준 버전과 비교 대상 바꾸기",
    "System Extension Installation": "시스템 확장 설치",
    "Symbolic Link": "심볼릭 링크",
    "Team Identifier": "팀 식별자",
    "The candidate declares this value.": "비교 대상이 이 값을 선언합니다.",
    "The candidate no longer declares this value.": "비교 대상에서 이 값 선언이 제거되었습니다.",
    "The report could not be exported: %@": "보고서를 내보내지 못했습니다: %@",
    "This is a declaration in Info.plist and does not prove the protected resource is used.":
      "Info.plist의 선언이며 보호된 자원의 실제 사용을 의미하지는 않습니다.",
    "This report describes observable metadata and declarations. It does not establish runtime behavior or intent.":
      "이 보고서는 관찰 가능한 메타데이터와 선언을 설명합니다. 실제 동작이나 의도를 단정하지 않습니다.",
    "Toggle Inspector": "세부 정보 표시 전환",
    "Trust & Signing": "신뢰 및 서명",
    "Unchanged": "변경 없음",
    "Unavailable": "확인 불가",
    "Unsigned Executable Memory": "서명되지 않은 실행 메모리",
    "URL scheme": "URL 스킴",
    "Version": "버전",
    "Xpc Service": "XPC 서비스",
    "directory": "디렉터리",
    "other": "기타",
    "or choose a local artifact": "또는 로컬 아티팩트를 선택하세요",
    "regular": "일반 파일",
    "symbolicLink": "심볼릭 링크",
    "Accepted": "승인됨",
    "Rejected": "거부됨",
    "A declared code-signing entitlement changed. App Delta reports the declaration, not runtime behavior.":
      "코드 서명 권한 선언이 변경되었습니다. App Delta는 실제 동작이 아니라 선언 내용만 보여줍니다.",
    "A package payload path was rejected because it could escape the package root.":
      "패키지 루트 밖으로 벗어날 수 있는 payload 경로를 거부했습니다.",
    "A path outside the application bundle was ignored.": "애플리케이션 번들 밖의 경로를 무시했습니다.",
    "Installer package": "설치 패키지",
    "Installer packages are analyzed as package metadata rather than mounted applications.":
      "설치 패키지는 마운트된 애플리케이션이 아니라 패키지 메타데이터로 분석합니다.",
    "Installer packages are compared from signed package metadata and payload paths. Package scripts and payload executables are never run.":
      "설치 패키지는 서명된 패키지 메타데이터와 payload 경로만 비교합니다. 패키지 스크립트와 payload 실행 파일은 절대 실행하지 않습니다.",
    "Package metadata entry %@ could not be read.": "패키지 메타데이터 항목 %@을(를) 읽을 수 없습니다.",
    "Package metadata entry %@ exceeded the size limit.": "패키지 메타데이터 항목 %@이(가) 크기 제한을 초과했습니다.",
    "Package metadata entry %@ was malformed XML.": "패키지 메타데이터 항목 %@의 XML 형식이 올바르지 않습니다.",
    "Package identifier and version were not present in root package metadata.":
      "루트 패키지 메타데이터에 식별자와 버전이 없습니다.",
    "Package identifier and version were unavailable because its metadata archive could not be listed.":
      "메타데이터 아카이브 목록을 읽지 못해 패키지 식별자와 버전을 확인할 수 없습니다.",
    "Paths deeper than %@ components were skipped.": "%@단계보다 깊은 경로를 건너뛰었습니다.",
    "Privacy manifest %@ could not be parsed: %@": "개인정보 보호 매니페스트 %@을(를) 분석하지 못했습니다: %@",
    "Relaxes Hardened Runtime library validation so code signed by other teams may be loaded.":
      "다른 팀이 서명한 코드를 불러올 수 있도록 Hardened Runtime의 라이브러리 검증을 완화합니다.",
    "Relaxes Hardened Runtime protection for executable memory.":
      "실행 가능 메모리에 대한 Hardened Runtime 보호를 완화합니다.",
    "Signature verified.": "서명이 검증되었습니다.",
    "Some package identity fields were unavailable.": "일부 패키지 식별 정보를 확인할 수 없습니다.",
    "Some file content hashes were unavailable or exceeded the %@ safety budget. Those files are compared by metadata only.":
      "일부 파일 내용 해시를 확인할 수 없거나 %@ 안전 한도를 초과했습니다. 해당 파일은 메타데이터만 비교합니다.",
    "The disk image contains multiple applications. App Delta selected %@.":
      "디스크 이미지에 여러 애플리케이션이 있어 %@을(를) 선택했습니다.",
    "The file inventory was truncated at %@ entries.": "파일 목록을 %@개 항목에서 잘랐습니다.",
    "The package payload list was truncated at %@ entries.": "패키지 payload 목록을 %@개 항목에서 잘랐습니다.",
    "Unknown": "알 수 없음",
    "Unsupported artifact: %@": "지원하지 않는 아티팩트: %@",
    "The artifact could not be read: %@": "아티팩트를 읽을 수 없습니다: %@",
    "Invalid property list: %@": "올바르지 않은 property list: %@",
    "No macOS application was found in %@.": "%@에서 macOS 애플리케이션을 찾지 못했습니다.",
    "More than one application was found: %@.": "애플리케이션이 여러 개 발견되었습니다: %@.",
    "%@ failed: %@": "%@ 실패: %@",
    "%@ did not finish within the time limit.": "%@ 명령이 제한 시간 안에 끝나지 않았습니다.",
    "%@ produced more output than App Delta allows.": "%@ 명령의 출력이 App Delta 허용량을 초과했습니다.",
    "The scan stopped at its safety limit: %@": "안전 한도에서 분석을 중단했습니다: %@",
    "Unsafe path was rejected: %@": "안전하지 않은 경로를 거부했습니다: %@",
    "%@ %@ is saved as the baseline. Update the app, then compare its current version.":
      "%@ %@을(를) 기준점으로 저장했습니다. 앱을 업데이트한 뒤 현재 버전과 비교하세요.",
    "%@ · saved %@": "%@ · %@ 저장",
    "App Delta Help": "App Delta 도움말",
    "Are selected files uploaded?": "선택한 파일이 업로드되나요?",
    "Baseline is the previous or trusted state. Candidate is the new state you want to inspect. App Delta reports what changed from Baseline to Candidate.":
      "기준 버전은 이전 상태 또는 신뢰하는 상태이고, 비교 대상은 확인하려는 새로운 상태입니다. App Delta는 기준 버전에서 비교 대상으로 무엇이 바뀌었는지 보여줍니다.",
    "Before updating, choose Prepare App Update and select the installed app. App Delta saves a compact analysis snapshot and keeps the same app path as Candidate. Run the app's update normally, return to App Delta, and compare. You can restore the snapshot later from Saved Baselines.":
      "업데이트하기 전에 ‘앱 업데이트 비교 준비’를 선택하고 설치된 앱을 고르세요. App Delta가 작은 분석 기준점을 저장하고 같은 앱 경로를 비교 대상으로 유지합니다. 평소처럼 앱을 업데이트한 뒤 App Delta로 돌아와 비교하세요. 저장된 기준점은 나중에도 다시 선택할 수 있습니다.",
    "Choose a macOS application to preserve before updating.":
      "업데이트 전에 보관할 macOS 애플리케이션을 선택하세요.",
    "Delete": "삭제",
    "Delete saved baseline": "저장된 기준점 삭제",
    "Delete this saved baseline?": "이 저장된 기준점을 삭제할까요?",
    "Does a new capability prove the app used it?": "새 권한이 실제 사용을 의미하나요?",
    "Does App Delta launch apps or installer scripts?": "App Delta가 앱이나 설치 스크립트를 실행하나요?",
    "Done": "완료",
    "How do I compare an app before and after its built-in update?":
      "앱 자체 업데이트 전후를 어떻게 비교하나요?",
    "How do I share a comparison?": "비교 결과를 어떻게 공유하나요?",
    "Is a saved baseline a backup of the application?": "저장된 기준점은 앱 백업인가요?",
    "No saved baselines": "저장된 기준점 없음",
    "No. Analysis and saved baselines stay on this Mac. App Delta has no account, analytics SDK, upload service, or database.":
      "아닙니다. 분석 결과와 저장된 기준점은 이 Mac에만 남습니다. App Delta에는 계정, 분석 SDK, 업로드 서비스 또는 데이터베이스가 없습니다.",
    "No. Entitlements, privacy descriptions, and manifests are declarations. App Delta explains observable metadata changes but does not claim runtime behavior or malicious intent.":
      "아닙니다. entitlement, 개인정보 설명과 매니페스트는 선언 정보입니다. App Delta는 관찰 가능한 메타데이터 변경을 설명할 뿐 실제 동작이나 악의적 의도를 단정하지 않습니다.",
    "No. It is an analysis snapshot used only for comparison. It cannot reinstall or restore the old application. To recover an old build, keep its DMG, use Time Machine, or download an older vendor release.":
      "아닙니다. 비교에만 사용하는 분석 기준점입니다. 이전 앱을 재설치하거나 복구할 수 없습니다. 이전 빌드를 복구하려면 DMG를 보관하거나 Time Machine 또는 공급자의 이전 릴리스를 사용하세요.",
    "No. Selected apps are read as files. DMGs are attached read-only, and package scripts and payload executables are never run.":
      "아닙니다. 선택한 앱은 파일로만 읽습니다. DMG는 읽기 전용으로 연결하며 패키지 스크립트와 payload 실행 파일은 절대 실행하지 않습니다.",
    "Prepare an app before updating to save its current state.":
      "업데이트 전에 앱의 현재 상태를 기준점으로 저장하세요.",
    "Prepare App Update Comparison": "앱 업데이트 비교 준비",
    "Prepare App Update…": "앱 업데이트 비교 준비…",
    "Preserve Baseline": "기준점 저장",
    "Saved baseline · %@": "저장된 기준점 · %@",
    "Saved Baselines": "저장된 기준점",
    "Saved Baselines…": "저장된 기준점…",
    "Search help": "도움말 검색",
    "Stored only on this Mac.": "이 Mac에만 저장됩니다.",
    "The baseline could not be saved: %@": "기준점을 저장하지 못했습니다: %@",
    "The saved analysis for %@ will be removed.": "%@의 저장된 분석 기록이 삭제됩니다.",
    "The saved baseline could not be deleted: %@": "저장된 기준점을 삭제하지 못했습니다: %@",
    "The saved baseline could not be loaded: %@": "저장된 기준점을 불러오지 못했습니다: %@",
    "These are analysis snapshots, not copies of the original applications.":
      "원본 앱 복사본이 아니라 분석 기준점입니다.",
    "They are JSON analysis records in your user Library under Application Support/App Delta/Baselines. Delete them from Saved Baselines in the app.":
      "사용자 라이브러리의 Application Support/App Delta/Baselines에 JSON 분석 기록으로 저장됩니다. 앱의 ‘저장된 기준점’에서 삭제할 수 있습니다.",
    "Understand changes between two macOS app builds.": "두 macOS 앱 빌드의 변경점을 이해하세요.",
    "Use": "사용",
    "What are Baseline and Candidate?": "기준 버전과 비교 대상은 무엇인가요?",
    "What if the app was already updated?": "앱이 이미 업데이트됐다면 어떻게 하나요?",
    "Where are saved baselines stored?": "저장된 기준점은 어디에 있나요?",
    "Why can Gatekeeper results differ between Macs?": "Mac마다 Gatekeeper 결과가 다른 이유는 무엇인가요?",
    "App Delta cannot reconstruct files that were already replaced. Use a previous DMG, a vendor or GitHub release, or a Time Machine copy as Baseline. Prepare App Update before the next update.":
      "App Delta는 이미 교체된 파일을 복원할 수 없습니다. 이전 DMG, 공급자 또는 GitHub 릴리스, Time Machine 복사본을 기준 버전으로 사용하세요. 다음 업데이트 전에는 ‘앱 업데이트 비교 준비’를 실행하세요.",
    "Application identity could not be confirmed": "애플리케이션 식별 정보를 확인할 수 없습니다",
    "At least one identifier is unavailable. Check the application names and sources before interpreting the result.":
      "하나 이상의 식별자를 확인할 수 없습니다. 결과를 해석하기 전에 애플리케이션 이름과 출처를 확인하세요.",
    "Back to Sources": "선택 화면으로 돌아가기",
    "Comparing %@ with %@ is supported, but packaging differences may produce many file and component changes.":
      "%@와 %@ 비교를 지원하지만 패키징 차이로 인해 파일과 구성요소 변경이 많이 표시될 수 있습니다.",
    "Different artifact formats selected": "서로 다른 아티팩트 형식을 선택했습니다",
    "Different formats and identifiers detected": "서로 다른 형식과 식별자가 감지되었습니다",
    "Different formats selected: %@ and %@. Comparison is supported, but packaging differences may appear as broad changes.":
      "서로 다른 형식을 선택했습니다: %@ 및 %@. 비교는 지원하지만 패키징 차이가 광범위한 변경으로 표시될 수 있습니다.",
    "Export a self-contained HTML report for people to read or JSON for automation. Reports are generated locally and use the currently selected language.":
      "사람이 읽을 수 있는 독립형 HTML 보고서나 자동화용 JSON을 내보내세요. 보고서는 로컬에서 생성되며 현재 선택한 언어를 사용합니다.",
    "Gatekeeper reflects the current Mac's trust policy, network availability, and cached notarization state. App Delta keeps accepted, rejected, and unavailable results separate.":
      "Gatekeeper는 현재 Mac의 신뢰 정책, 네트워크 상태와 캐시된 공증 상태를 반영합니다. App Delta는 승인, 거부, 확인 불가 결과를 분리해 표시합니다.",
    "Return to the artifact selection screen": "아티팩트 선택 화면으로 돌아갑니다",
    "The identifiers are %@ and %@. Confirm that these are the intended versions before interpreting the result.":
      "식별자는 %@ 및 %@입니다. 결과를 해석하기 전에 의도한 버전이 맞는지 확인하세요.",
    "These appear to be different applications": "서로 다른 애플리케이션으로 보입니다",
  ]
}
