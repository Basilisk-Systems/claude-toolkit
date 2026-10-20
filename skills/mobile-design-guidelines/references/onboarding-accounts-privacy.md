# Launching, onboarding, accounts, privacy, settings

Sources:
- https://developer.apple.com/design/human-interface-guidelines/launching
- https://developer.apple.com/design/human-interface-guidelines/onboarding
- https://developer.apple.com/design/human-interface-guidelines/managing-accounts
- https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
- https://developer.apple.com/design/human-interface-guidelines/privacy
- https://developer.apple.com/design/human-interface-guidelines/settings

## Launching
- "Launch instantly." Launch screen ≠ splash: "A launch screen's sole function is to enhance the perception of your experience as quick to launch."
- "Design a launch screen that's nearly identical to the first screen." Solid color first screen → solid color launch screen. Match orientation and appearance mode.
- "Avoid including text on your launch screen." "Don't advertise" — no logos unless part of the first screen.
- "Restore the previous state when your app restarts" — scroll position included.

## Onboarding
- "Design a flow that's fast, fun, and optional." Happens after launch.
- "Teach through interactivity." "Consider providing a collection of context-specific tips instead of a single onboarding flow."
- Prerequisite flow: "brief, enjoyable ... doesn't require people to memorize a lot."
- Optional tutorial: if skipped, "don't present it again," keep it findable in help/settings.
- "Postpone nonessential setup flows or customization steps. Provide reasonable default settings."
- Permission during onboarding only if the app needs it to function; "Otherwise, present a permission request when people first access the specific function."
- "Prefer letting people experience your app or game before prompting them for ratings or purchases."
- "Avoid displaying licensing details within your onboarding flow."

## Accounts
- "Ask people to create an account only if your core functionality requires it."
- "Explain the benefits of creating an account and how to sign up ... Display this message in your sign-in view."
- "Delay sign-in for as long as possible."
- No Sign in with Apple → "prefer using a passkey"; passwords → require two-factor.
- "Always identify the authentication method" — "Sign In with Face ID", not "Sign In." Only reference methods the device has.
- "Avoid offering an app-specific setting for opting in to biometric authentication."
- "Avoid using the term passcode."

### Account deletion
- "If you help people create an account within your app or game, you must also help them delete it, not just deactivate it."
- "Provide a clear way to initiate account deletion within your app" — otherwise a direct, easy-to-find link (not buried in privacy policy/ToS).
- Health-records caveat: if law requires keeping data, "clearly describe the situation."
- Same experience in-app and on web. Optional scheduled deletion must also offer immediate deletion.
- "Tell people when account deletion will complete, and notify them when it's finished."
- In-app purchases: explain that Apple billing continues until the subscription is cancelled.
- Sign in with Apple accounts: revoke tokens on deletion.

### Sign in with Apple (HIG presentation rules)
- The HIG page covers how to present it; the obligation to offer it comes from App Store Review Guideline 4.8 (not fetched here — see the `app-store-publishing` skill).
- "Ask people to sign in only in exchange for value." "Delay sign-in as long as possible."
- "Prominently display a Sign in with Apple button. Make a Sign in with Apple button no smaller than other sign-in buttons, and avoid making people scroll to see the button."
- Minimum size: 140 pt wide × 30 pt high; margin ≥ 1/10 of button height. 44 pt is "the default (and recommended) button height in iOS."
- Styles: white (dark backgrounds), white with outline (light backgrounds), black (light backgrounds). Corner radius may match your other buttons.
- "Don't ask people to supply a password." Respect private relay emails. Mark extra data as required vs optional.
- "Indicate when people are currently signed in" — e.g. "Using Sign in with Apple" in account settings.

## Privacy and permissions
- "Request access only to data that you actually need." Health data is listed as personal data requiring permission.
- "Request permission only when your app clearly needs access." "Avoid requesting permission at launch unless the data or resource is required."
- Purpose strings: "a brief, complete sentence that's straightforward, specific ... Use sentence case, avoid passive voice, and include a period." Good: "The app records during the night to detect snoring sounds." Bad: "Microphone access is needed for a better experience." Bad: "Turn on microphone access."

### Pre-permission (pre-alert) screens
- "Include only one button and make it clear that it opens the system alert." Title it "Continue" or "Next" — not "Allow."
- "Don't include additional actions in your custom screen ... don't provide a way for people to leave the screen or window without viewing the system alert — like offering an option to close or cancel."
- Tracking (ATT): never precede the system alert with a misleading screen — incentives, imitation requests, alert images or annotations "will cause rejection."
- Note: this conflicts with the common "Skip" button on priming screens. Per the HIG, make the feature optional by not routing to the priming screen at all (an entry elsewhere), not by adding Skip to it.

### Protecting data
- Passkeys over passwords; biometrics for kept-logged-in apps; "Store sensitive information in a keychain"; "Never store passwords ... in plain-text files"; "Avoid inventing custom authentication schemes."

## Settings
- Good defaults; "Minimize the number of settings you offer."
- "Avoid using settings to ask for setup information you can get in other ways" (e.g. detect Dark Mode).
- "Respect people's systemwide settings and avoid including redundant versions of them."
- Task-specific options live in the screen they affect, not in Settings.
