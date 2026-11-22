# Message Board Vault

CSC 4360 Homework 2 · Eziz Bagshiyev · Undergraduate track

## Android and Firebase setup

Install Flutter, an Android SDK/device, Firebase CLI, and FlutterFire CLI. In your Firebase project enable Email/Password Auth and create a Firestore database. Register Android with application ID `edu.gsu.bagshiyev.message_board` using `flutterfire configure --platforms=android --android-package-name=edu.gsu.bagshiyev.message_board`. Download its Android client configuration to `android/app/google-services.json` if the CLI did not place it there. The Gradle build applies Google Services when this file is present. Deploy the rules to your designated project with `firebase deploy --only firestore:rules --project YOUR_PROJECT_ID`.

Run `flutter pub get`, `flutter analyze`, and `flutter build apk --release`. Install `build/app/outputs/flutter-apk/app-release.apk` on Android and run the checks below. Test the identical APK you submit. The sample Android release configuration uses debug signing for course sideloading.

## Auth and Firestore

The splash waits for Firebase, then AuthService's stable auth stream chooses between signed-out entry and the profile gate. Registration creates an Auth account and routes to required name entry. The gate can finish a missing profile after a failed write or restart. Signing out removes the profile and message subscriptions through widget disposal.

| Path | Fields and writers | Access |
| --- | --- | --- |
| users/{uid} | The profile form supplies firstName and lastName. BoardService writes uid from Auth and role as member. Firestore resolves registrationDateTime. | Only the authenticated owner can create and read the record. |
| messages/{id} | BoardService writes text from the composer and authorUid from Auth. It derives authorName from the saved profile. Firestore resolves createdAt and editedAt. Owners can update only text and editedAt. | Signed-in users can read. The authenticated author creates, edits and deletes. Rules validate the display name against the author profile. |

A single ordered snapshots stream drives the board. The composer blocks repeated clicks during a write, and a transaction checks a stable document ID before creating it. Existing IDs make retries harmless. Transactions need an online connection. An unsuccessful post retains its draft and ID for a retry. A new draft is a new operation.

## Emulator, rules, and duplicate-write workflow

Start with `firebase emulators:start --only auth,firestore --project demo-message-board`. On an Android emulator run `flutter run --dart-define=FIREBASE_EMULATOR=true` (default host 10.0.2.2). For a physical device on the same network, configure emulator binding and supply `--dart-define=EMULATOR_HOST=YOUR_TEST_HOST`. Demo mode uses fictional client configuration and routes both services to the emulator before opening either stream.

Install rule-test dependencies with `npm install`. Run `firebase emulators:exec --only firestore --project demo-message-board "npm test"`. The suite seeds a fictional author and post through enforced rules, checks signed-out and cross-user denials, proves owner CRUD, and runs two concurrent transactions with the same ID. Use test projects only. For manual emulator evidence, register two test accounts and post sample messages from the app, then inspect localhost:4000.

## Release evidence checklist

Record device, APK version and hash. Capture splash, invalid input, registration, five profile fields, login/logout/relaunch, empty board, and create/read/edit/delete of one post. Keep another post in place while deleting. On a second signed-in client post a message and capture it appearing on the first client. Capture signed-out reads, forged creates and cross-user edit/delete denials, and count Firestore documents before and after a rapid double-post test. Give every screenshot an action, expected result, observed result and pass/fail. Include the release gate and choice spices 1, 2, and 4.

