# Homework 2 evidence worksheet

Eziz Bagshiyev · CSC 4360 · Undergraduate track  
Preparation date: November 22, 2026  
Exact APK build, Android device, and repository URL: pending.

## Release readiness and choice tasks

| Test action | Expected result | Observed result |
| --- | --- | --- |
| Launch the installed release APK | Splash gives way to signed-out form | Pending |
| Submit malformed email or a short password | Form shows a validation message | Pending |
| Register and complete the profile | Board opens and Firestore shows uid, firstName, lastName, role, and registrationDateTime | Pending |
| Sign out, sign in, force-stop, and relaunch | Login succeeds and the session survives normal restart | Pending |
| Open a clean board, then create a message | Empty state gives way to one post | Pending |
| Edit and delete your message with a second post present | Text changes, then only that post disappears | Pending |
| Post from a second signed-in client | First client sees the post without refreshing | Pending |
| Read while signed out, then edit and delete as another account | Firestore denies each action | Pending |
| Attempt a forged authorUid | Firestore denies the create | Pending |
| Rapidly tap Post twice | Only one document appears | Pending |
| Go offline, post, then reconnect and retry | Transaction needs a connection and the draft remains available to retry | Pending |
| Choice 1: Run both emulators using demo-message-board | Test users and messages appear in the Emulator UI | Blocked here: Firestore could not establish a loopback connection |
| Choice 2: Run npm test under the Firestore emulator | Owner CRUD passes and denied cases are rejected | Test source prepared, execution pending |
| Choice 4: Run the concurrent same-ID test | Two transactions leave one document | Test source prepared, execution pending |

Add numbered screen captures with the action, expected result, observed result, and pass/fail. Use fictional accounts in captures.

## Reflection prompts

1. **Expectation vs obtained**. Compare your expectation for the two-step account/profile flow with what the release APK did. Analyze why the profile gate matters if Auth succeeds before Firestore writes the profile.
2. **Debug evidence and alternatives**. Describe a failure you observed, identify the relevant service and evidence, and explain how you ruled out an alternative cause. The emulator's loopback failure is an environment observation and does not prove anything about Firestore authorization.
3. **Improvement plan**. Identify the next improvement and a regression check. One candidate is a visible retry action when the profile stream fails.
4. **Privacy and placement**. Explain why profile fields live in an owner-only document. The display name copied to messages is visible to other signed-in users, so decide whether that identity exposure fits the app.
5. **Cloud vs device**. Compare server persistence of messages with the transient composer draft and the locally persisted Firebase Auth session. Use your restart and offline checks to justify the placement.
6. **Scale and maintainability**. Describe when a bounded realtime query and cursor paging would be worthwhile. Explain how moving older posts out of the live window affects what the user sees.

## Two case files to develop in your own words

**The Ghost Editor.** Friendly UI tests exercised only owner actions. A rule that checks sign-in alone accepts cross-user writes. Compare the existing document's authorUid with request.auth.uid before edit/delete, restrict edit fields, and separately bind new documents to the caller. Run the same update as owner and another signed-in account and capture both results.

**The Runaway Dupes.** An ordinary offline Firestore write can be queued. Reissuing the logical action with a fresh document ID can create a distinct write. A busy button reduces repeat taps during one screen session. A stable draft ID with a transaction also handles concurrent same-ID requests and costs an online round trip. A new draft or restart can still produce a new ID and allow identical text as a new post. Use the same-ID test, then compare with an offline attempt and retry in the app.

## Undergraduate AI lab

AI-assisted predictions drafted November 22, before release verification. These are hypotheses. No original pre-AI predictions have been supplied.

1. After force-stopping and reopening the app, the same account should reach the board without entering its password.
2. A message acknowledged by Firestore should still appear after the app restarts.
3. Rebooting the phone should preserve the signed-in account unless its credentials have been revoked.
4. Clearing app storage should remove the local session and open the sign-in screen.
5. After clearing storage and signing back into the same project, the user should see the previously saved messages and profile again.

Tool to disclose: ChatGPT, November 22, 2026. Its implementation advice used authStateChanges for routing, snapshots for continuing updates, get for a single read, and server timestamps for a consistent message clock. One distinction to verify is offline behavior: ordinary writes can use the offline queue, while the transaction used by this composer needs connectivity. Compare this with your own release results and document one suggestion you kept and one you revised. Use your own judgment and wording.

Sources to check and cite alongside your observations:

- Firebase Authentication for Flutter — https://firebase.google.com/docs/auth/flutter/start
- Firestore realtime listeners — https://firebase.google.com/docs/firestore/query-data/listen
- Firestore transactions — https://firebase.google.com/docs/firestore/manage-data/transactions
- Firestore security rule conditions — https://firebase.google.com/docs/firestore/security/rules-conditions


