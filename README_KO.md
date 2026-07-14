# App Delta

<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="App Delta 아이콘">
</p>

App Delta는 두 macOS 앱 빌드 사이에서 **실제로 관찰되는 변경점**을 로컬에서
비교하는 네이티브 도구입니다. 검사 대상 앱이나 설치 스크립트를 실행하지 않고,
어떤 내용도 외부 서버로 업로드하지 않습니다.

> App Delta는 앱이 안전한지, 악성인지 판정하지 않습니다. 서명·선언·구성요소·
> 파일에서 확인된 차이를 근거와 함께 보여주는 도구입니다.

[English](README.md) · [구현 계획](IMPLEMENTATION_PLAN.md)

[최신 macOS 프리뷰 다운로드](https://github.com/JongHyun070105/app-delta/releases)

![새로 추가된 macOS 권한을 비교하는 App Delta](docs/app-delta.jpg)

## 비교 항목

- 앱 이름, 번들 ID, 버전, 빌드, 최소 macOS, SDK, 전체 크기
- 코드 서명 유효성, 인증서 체인, Team ID, Hardened Runtime, App Sandbox,
  Gatekeeper 결과
- 코드 서명 entitlement와 각 권한의 의미
- `Info.plist` 개인정보 사용 설명 및 `PrivacyInfo.xcprivacy`
- 로그인 항목, LaunchAgent, LaunchDaemon 같은 백그라운드 구성
- 실행 파일, 프레임워크, XPC, 확장, 플러그인, 중첩 앱, 동적 라이브러리
- 파일 종류·크기·실행 권한·제한된 SHA-256 내용 지문

## 다운로드와 설치

[GitHub Releases](https://github.com/JongHyun070105/app-delta/releases)에서
범용 macOS DMG를 내려받아 연 뒤 **AppDelta**를 **응용 프로그램**으로 드래그하세요.
Apple Silicon과 Intel Mac을 모두 지원합니다.

> 현재 GitHub 바이너리는 ad-hoc 서명이며 Apple 공증을 받지 않은 Preview입니다.
> macOS에서 앱을 Control-클릭한 뒤 **열기**를 선택해야 할 수 있습니다. 일반적인
> 더블클릭 설치를 제공하려면 Developer ID 인증서와 Apple 공증이 필요합니다.

## 소스에서 빌드와 실행

macOS 14 이상과 Xcode 16 이상이 필요합니다.

```bash
git clone https://github.com/JongHyun070105/app-delta.git
cd app-delta
./script/build_and_run.sh
```

개발 및 검증 명령:

```bash
swift test
./script/build_and_run.sh --verify
./script/build_and_run.sh --package
./script/create_demo_fixtures.sh
```

## 사용법

1. 이전 버전을 **Baseline**에 넣습니다.
2. 새 버전을 **Candidate**에 넣습니다.
3. **Compare Artifacts**를 누릅니다.
4. 카테고리·검색·중요도 필터를 이용하고, 항목을 선택해 전후 값과 근거 경로를
   확인합니다.
5. 필요한 경우 독립 실행형 HTML 또는 JSON 보고서를 내보냅니다.

### 앱 자체 업데이트 전후 비교

앱 자체 업데이트는 기존 번들을 교체하기 때문에 이전 버전이 사라집니다.
업데이트하기 전에 **앱 업데이트 비교 준비…**를 누르고 설치된 앱을 선택하세요.
App Delta는 앱 복사본이 아닌 작은 분석 기준점만 저장하고 같은 앱 경로를 비교
대상으로 유지합니다. 평소처럼 업데이트한 뒤 App Delta로 돌아와 비교하세요.
저장된 기준점은 **저장된 기준점…**에서 다시 사용할 수 있습니다.

이미 업데이트가 끝났다면 교체된 파일을 복원할 수 없습니다. 이전 DMG, 공급자나
GitHub의 이전 릴리스 또는 Time Machine 복사본을 기준 버전으로 사용해야 합니다.

**도움말 → App Delta 도움말**에서 검색 가능한 Q&A를 볼 수 있습니다.

### 언어 변경

기본값은 Mac의 언어 설정을 따르며 한국어와 영어를 지원합니다. 툴바의 지구본,
앱의 **Language** 메뉴 또는 **App Delta → 설정**에서 즉시 바꿀 수 있습니다.
언어를 바꿔도 현재 비교 결과는 유지되며, 이후 내보내는 HTML 보고서에도 선택한
언어가 적용됩니다.

## 안전 경계

- `.app`은 읽기만 합니다.
- `.dmg`는 검증 후 Finder에 노출하지 않고 읽기 전용으로 마운트하며, 분석이
  끝나면 즉시 해제하고 임시 디렉터리를 지웁니다.
- `.pkg`와 `.mpkg`는 설치하거나 임의로 압축 해제하지 않습니다. 서명 정보와
  제한된 payload 경로만 확인하므로 설치 스크립트가 실행되지 않습니다.
- 심볼릭 링크를 따라가지 않으며, 항목 수·경로 깊이·명령 시간과 출력·해시
  처리량에 상한이 있습니다.
- 내보낸 HTML은 앱에서 가져온 문자열을 이스케이프하고 제한적인 CSP를 넣습니다.

Gatekeeper 결과는 현재 Mac의 정책과 캐시 상태를 반영할 수 있습니다. 승인,
거부, 확인 불가 상태와 진단 근거를 서로 구분하고 어떤 상태도 악성 판정으로
바꾸지 않습니다.

## v1 제한 사항

- DMG에 여러 앱이 있으면 가장 얕은 경로의 첫 앱을 선택하고 그 사실을 메모로
  표시합니다.
- 패키지는 의도적으로 메타데이터와 payload 경로까지만 비교합니다.
- 파일 내용 해시는 아티팩트당 512 MB에서 멈추며 이후 파일은 메타데이터만
  비교합니다.
- Preview DMG는 ad-hoc 서명이고 공증되지 않았습니다. 안정적인 공개 배포에는
  Developer ID 서명과 Apple 공증이 필요합니다.

[MIT License](LICENSE)
