# potendays

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



## 로컬 실행 설정

1. `.env.example` 파일을 복사해서 `.env` 파일을 만듭니다.

PowerShell:

```powershell
copy .env.example .env
```

Mac/Linux:

```bash
cp .env.example .env
```

2. `.env` 파일에 각자 필요한 설정값을 입력합니다.

예시:

```env
GOOGLE_CLIENT_ID=your_google_client_id
```

3. 패키지를 설치합니다.

```bash
flutter pub get
```

4. 앱을 실행합니다.

```bash
flutter run
```

## Firebase 설정

보안상 아래 파일은 GitHub에 포함하지 않습니다.

- `.env`
- `android/app/google-services.json`
- `lib/firebase_options.dart`

실행 전 Firebase Console에서 `google-services.json`을 내려받아 아래 위치에 넣어주세요.

```text
android/app/google-services.json
```

또는 FlutterFire CLI를 사용해 다음 명령어로 `firebase_options.dart`를 생성해주세요.

```bash
flutterfire configure
```

## 팀원 실행 안내

Firebase 관련 설정 파일은 GitHub에 올라가지 않으므로, 팀원은 Firebase 프로젝트 권한을 받은 뒤 각자 설정 파일을 생성해야 합니다.

필요한 파일:

```text
.env
android/app/google-services.json
lib/firebase_options.dart
```

위 파일들이 준비된 후 `flutter pub get`을 실행하고 앱을 실행하면 됩니다.