# NTPUOne Android System Specification

> Status: Draft, written from the iOS source code as the Android parity specification.
> Source repo: `/Users/xujunkai/Developer/NTPUOne`
> Writing strategy: batch-based. Each batch adds source-backed sections and a coverage checklist.

## 0. Specification Method, Scope, and Evidence Rules

### 0.1 Purpose

This document defines the complete Android product specification for NTPUOne by reverse-mapping the current iOS application. The Android app must preserve user-facing behavior, data semantics, backend contracts, navigation relationships, and permission boundaries unless a later product decision explicitly changes them.

The spec is intentionally detailed because it is meant to support a full Android rebuild. It covers pages, sheets, cards, buttons, navigation routes, local storage, backend API contracts, Firebase behavior, notifications, widgets/live activities equivalents, localization, presentation states, and platform-specific Android replacement requirements.

### 0.2 Evidence Rule

Every behavioral claim in this document should be traceable to source evidence. File references are written as local paths and line anchors where available. If a section has not yet been fully source-audited, it is marked as a coverage gap rather than guessed.

Primary evidence sources:

| Domain | Source files |
|---|---|
| App entry/lifecycle | `NTPUOne/NTPUOneApp.swift` |
| Root navigation/onboarding/community | `NTPUOne/ContentView.swift` |
| App configuration/permissions | `NTPUOne/Info.plist` |
| Home dashboard/web links | `NTPUOne/WebViews/LinkView.swift`, `NTPUOne/WebViews/*` |
| Courses/timetable | `NTPUOne/CourseList/*`, `CourseEntity+CoreData*`, `CourseModel.xcdatamodeld` |
| Memos/tasks | `NTPUOne/MemoView/*`, `MemoEntity+CoreData*`, `CourseModel.xcdatamodeld` |
| Food/restaurants/comments | `NTPUOne/FoodView/*` |
| Traffic/weather/life map | `NTPUOne/TrafficView/*`, `NTPUOne/WeatherView/*` |
| About/settings/admin | `NTPUOne/AboutView/*` |
| Ads/rewards | `NTPUOne/Ads/*`, `NTPUOne/Info.plist` |
| Widgets/live activity | `NextCourseWidget/*`, `NTPUOne/CourseList/NextCourseLiveActivityManager.swift` |
| Backend/security | `firebase/firestore.rules`, `firebase/functions/README.md`, Firebase config |
| Localization | `NTPUOne/zh-Hant.lproj/Localizable.strings`, `NTPUOne/en.lproj/Localizable.strings` |

### 0.3 Android Parity Rule

Android sections specify required behavior parity, not a mandatory architecture. For example, if iOS uses SwiftUI `TabView`, Android only needs equivalent tab navigation. If iOS uses ActivityKit Live Activities, Android needs an equivalent user-facing persistent class/task status surface, likely via notification/foreground-style ongoing notification, but the exact Android implementation can be chosen later.

### 0.4 Batch Plan

This document will be completed in batches:

| Batch | Chapter |
|---|---|
| 0 | Specification method, scope, glossary, coverage ledger |
| 1 | App shell, runtime, root navigation, onboarding, lifecycle |
| 2 | Data, storage, auth, backend contracts |
| 3 | Home/main dashboard and web links |
| 4 | Course and timetable |
| 5 | Memo and Today tasks |
| 6 | Community |
| 7 | Food, restaurants, comments, rewards |
| 8 | Traffic, weather, life, campus map |
| 9 | About, settings, feedback, admin |
| 10 | Ads and monetization |
| 11 | Widgets, Live Activity, background behavior |
| 12 | Android equivalence matrix |
| 13 | Final coverage audit |

### 0.5 Global Coverage Ledger

| Area | Status | Notes |
|---|---|---|
| App shell/root tabs | In progress | Initial source mapping from `ContentView.swift` and `NTPUOneApp.swift` complete. |
| Onboarding | Drafted | Root flow, buttons, freshman preference, and Google sign-in prompt documented. |
| Home dashboard | In progress | Web link source and quick feature data documented; full card-by-card UI still pending. |
| Course/timetable | Drafted | Data model, CRUD, notification hooks, and Live Activity refresh documented. |
| Memo/tasks | Drafted | Data model manager, CRUD, filtering, reminders, and Live Activity todo hook documented. |
| Community | Pending | Explorer task running. |
| Food/restaurants | Pending | Explorer task running. |
| Traffic/weather/life | Pending | Explorer task running. |
| About/settings/admin | Pending | Explorer task running. |
| Ads/rewards | Pending | Explorer task running. |
| Widgets/live activity | Drafted | Next-course/todo Live Activity manager documented; widget UI details still need source expansion. |
| Firebase/API rules | Pending | Needs backend chapter. |
| Android parity matrix | Pending | Depends on all feature chapters. |

## 1. App Shell, Runtime, Navigation, and Lifecycle

### 1.1 App Identity and Runtime Responsibilities

NTPUOne is a campus utility app for National Taipei University students. The iOS app starts from `NTPUOneApp`, which installs an `AppDelegate`, configures Firebase, initializes persistent Core Data/CloudKit storage, configures ads, registers notification delegates, starts widget refresh, and creates the root SwiftUI scene.

Source evidence:

| Behavior | Source |
|---|---|
| SwiftUI app entry point is `NTPUOneApp` | `NTPUOne/NTPUOneApp.swift:336` |
| App installs `AppDelegate` | `NTPUOne/NTPUOneApp.swift:338` |
| Root view is `ContentView()` | `NTPUOne/NTPUOneApp.swift:350` |
| Core Data context is injected into SwiftUI environment | `NTPUOne/NTPUOneApp.swift:351-353` |
| `CourseData` is created as an environment object | `NTPUOne/NTPUOneApp.swift:341-345`, `NTPUOne/NTPUOneApp.swift:353` |
| `AdFreeService.shared` is created as an environment object | `NTPUOne/NTPUOneApp.swift:340`, `NTPUOne/NTPUOneApp.swift:354` |
| Scene active refresh reloads widgets, refreshes ad state, Live Activity, community fallback notifications | `NTPUOne/NTPUOneApp.swift:356-364` |

Android parity requirements:

| iOS concept | Android required equivalent |
|---|---|
| SwiftUI `@main` app with `AppDelegate` | Android `Application` class plus main `Activity` initialization path. |
| `WindowGroup { ContentView() }` | Single app host activity with tab/root navigation. |
| Environment-injected Core Data context | App-wide dependency holder/repository access for local database. |
| `CourseData` and `AdFreeService` environment objects | Android app-level state holders or repositories available to screens. |
| Scene phase active/background handling | Android lifecycle observer handling foreground/background transitions. |
| Widget timeline reloads on foreground | Android widget/update worker refresh on app foreground where applicable. |

### 1.2 Firebase, App Check, Analytics, Messaging, and Ads Startup

At app launch, `AppDelegate.application(_:didFinishLaunchingWithOptions:)` performs the following startup sequence:

| Step | iOS behavior | Source | Android parity requirement |
|---|---|---|---|
| App Check provider | Installs `MyAppCheckProviderFactory`, using App Attest on real devices and debug provider on simulator | `NTPUOne/NTPUOneApp.swift:54-69`, `NTPUOne/NTPUOneApp.swift:267-284` | Android must configure Firebase App Check. Use Play Integrity or debug provider depending on build type. |
| Firebase core | Calls `FirebaseApp.configure()` | `NTPUOne/NTPUOneApp.swift:59` | Android must initialize Firebase before Firestore/Auth/Messaging use. |
| App Check token logging | Requests App Check token twice and logs success/failure | `NTPUOne/NTPUOneApp.swift:61-77` | Android should request/verify App Check only as needed; debug logging should not expose secrets in production. |
| Network monitor | Starts `NWPathMonitor` and logs connectivity/expensive status | `NTPUOne/NTPUOneApp.swift:80`, `NTPUOne/NTPUOneApp.swift:252-264` | Android should expose network state if features need it; current iOS only logs. |
| Analytics | Logs Firebase Analytics app open event | `NTPUOne/NTPUOneApp.swift:81` | Android must log equivalent app-open analytics if analytics parity is required. |
| Google Mobile Ads | Starts `GADMobileAds` and sets test device identifiers | `NTPUOne/NTPUOneApp.swift:82-83` | Android must initialize Google Mobile Ads and configure test IDs in debug only. |
| Widgets | Calls `WidgetCenter.shared.reloadAllTimelines()` on launch | `NTPUOne/NTPUOneApp.swift:84` | Android must refresh app widgets or equivalent status surfaces at launch/foreground where applicable. |
| Notification delegate | Sets `UNUserNotificationCenter.current().delegate = self` | `NTPUOne/NTPUOneApp.swift:85` | Android must configure notification channels and foreground notification handling. |
| FCM delegate | Sets `Messaging.messaging().delegate = self` | `NTPUOne/NTPUOneApp.swift:86` | Android must register FCM token refresh handling. |
| Community background refresh | Registers and schedules community notification fallback BG task | `NTPUOne/NTPUOneApp.swift:87-88`, `NTPUOne/NTPUOneApp.swift:158-196` | Android should implement equivalent periodic/best-effort work using WorkManager if community notification fallback is retained. |
| FCM token persistence | Fetches token and writes device token payload to Firestore | `NTPUOne/NTPUOneApp.swift:89-95`, `NTPUOne/NTPUOneApp.swift:198-227` | Android must persist FCM token with matching Firestore schema and ownership metadata. |

### 1.3 Persistent Store and Shared Data

The app uses a CloudKit-backed Core Data store named `CourseModel`, located in an App Group container for sharing with widgets.

Source evidence:

| Behavior | Source |
|---|---|
| `AppDelegate` defines `NSPersistentCloudKitContainer(name: "CourseModel")` | `NTPUOne/NTPUOneApp.swift:33-35` |
| Store is placed in app group `group.NTPUOne.NextCourseWidget` as `shared.sqlite` | `NTPUOne/NTPUOneApp.swift:36-41` |
| CloudKit container identifier is `iCloud.com.xujk.NTPUOne` | `NTPUOne/NTPUOneApp.swift:39-41` |
| `PersistenceController` repeats the same store setup | `NTPUOne/NTPUOneApp.swift:311-333` |
| Merge policy is `NSMergeByPropertyObjectTrumpMergePolicy` | `NTPUOne/NTPUOneApp.swift:332` |

Android parity requirements:

| iOS behavior | Android equivalent requirement |
|---|---|
| Core Data model `CourseModel` | Android local database schema must include equivalent course and memo entities. |
| CloudKit sync | Android needs a replacement sync decision. If cross-platform sync is required, CloudKit cannot be reused directly; Firebase or another backend sync layer must be specified later. |
| App Group widget sharing | Android widgets can read from app-owned storage through repositories/Glance/RemoteViews update flows; no iOS App Group equivalent is required, but widget data must stay consistent. |
| Shared SQLite path | Android should avoid direct widget SQLite coupling unless the chosen widget stack needs it; behavior parity matters more than storage mechanism. |

### 1.4 Root Tab Navigation

`ContentView` defines the primary app navigation as a five-tab `TabView`.

Source evidence: `NTPUOne/ContentView.swift:37-69`.

| Tab index | iOS view | Tab icon | Tab title | Purpose |
|---|---|---|---|---|
| 0 | `LinkView(courseData:memoManager:)` | `house` | `Main` | Home dashboard, campus links, today hub, announcements, quick features, weather, food shortcuts. |
| 1 | `TodayView(memoManager:courseData:)` | `note.text` | localized `memo` | Memo/task management and Today task workflows. |
| 2 | `TimeTableView(memoManager:)` | `list.bullet.clipboard` | localized `timetable` | Course timetable and course-related flows. |
| 3 | `CommunityView()` | `bubble.left.and.bubble.right` | localized `community_title` | Community topics, replies, subscriptions, profile/content management. |
| 4 | `AboutView()` | `info.circle` | localized `my` | Account center, settings, feedback, admin entry points, privacy controls. |

Global tab styling:

| Behavior | Source | Android parity requirement |
|---|---|---|
| Tab icons disable filled symbol variants | `NTPUOne/ContentView.swift:39-66` | Android selected/unselected tab icons should avoid unexpected filled variants unless explicitly designed. |
| Tab labels use compact icon-text label style | `NTPUOne/ContentView.swift:69`, `NTPUOne/ContentView.swift:121-130` | Android bottom navigation should use compact label/icon spacing and avoid oversized labels. |

### 1.5 Deep Links

The app supports custom URL scheme `ntpuone` and routes some URLs from `ContentView.handleDeepLink(url:)`.

Source evidence:

| Behavior | Source |
|---|---|
| URL scheme `ntpuone` configured | `NTPUOne/Info.plist:26-35` |
| Google/Firebase auth URL handling occurs first | `NTPUOne/ContentView.swift:102-104` |
| Non-`ntpuone` schemes ignored after auth handlers | `NTPUOne/ContentView.swift:106` |
| `ntpuone://memo` selects tab 1 | `NTPUOne/ContentView.swift:108-111` |
| `ntpuone://timetable` selects tab 2 | `NTPUOne/ContentView.swift:112-114` |
| Unknown hosts ignored | `NTPUOne/ContentView.swift:115-116` |

Android parity requirements:

| Deep link | Required Android behavior |
|---|---|
| Auth callback URLs | Android must register Google/Firebase auth callback handling through Firebase Auth/Google Sign-In configuration. |
| `ntpuone://memo` | Open app and navigate to Memo/Today tab. |
| `ntpuone://timetable` | Open app and navigate to Timetable tab. |
| Unknown `ntpuone` host | Safely no-op or show default home without crashing. |

### 1.6 First-Run Onboarding Gate

The app stores onboarding completion in `@AppStorage("hasCompletedFirstRunOnboarding")`. If it is false, `ContentView` presents `FirstRunOnboardingView` as a non-interactively-dismissable full-screen cover on appear.

Source evidence:

| Behavior | Source |
|---|---|
| Storage key is `hasCompletedFirstRunOnboarding` | `NTPUOne/ContentView.swift:27` |
| `showFirstRunOnboarding` controls full-screen cover | `NTPUOne/ContentView.swift:30`, `NTPUOne/ContentView.swift:73-79` |
| Cover is shown on first `onAppear` if onboarding not completed | `NTPUOne/ContentView.swift:80-83` |
| Completion sets storage true and hides cover | `NTPUOne/ContentView.swift:73-77` |
| Interactive dismissal disabled | `NTPUOne/ContentView.swift:78` |

Initial onboarding component locations:

| Component | Source |
|---|---|
| `FirstRunOnboardingView` | `NTPUOne/ContentView.swift:138` |
| `FirstRunOnboardingFreshmanPromptCard` | `NTPUOne/ContentView.swift:298` |
| `FirstRunOnboardingLoginPromptCard` | `NTPUOne/ContentView.swift:338` |
| `FirstRunOnboardingCard` | `NTPUOne/ContentView.swift:398` |

Android parity requirements:

| iOS behavior | Android equivalent |
|---|---|
| First-run gate in root view | Android root navigation must check persistent onboarding completion before showing main app. |
| Full-screen cover, cannot dismiss interactively | Android onboarding should block access until user completes/skips through supported actions. |
| Freshman prompt affects quick features | Android must preserve new-student shortcut personalization behavior. Full details will be in Home/Onboarding batches. |
| Optional school Google login prompt | Android must offer Google sign-in prompt with equivalent community-posting implications. |

Coverage gap: This batch has not yet fully enumerated every onboarding button and page text. That will be completed after the app-shell explorer result is merged.

### 1.7 App Lifecycle Hooks

The app refreshes Live Activity and widgets through multiple foreground/course-change hooks.

| Event | Behavior | Source | Android parity requirement |
|---|---|---|---|
| Root `ContentView.onAppear` | Calls `refreshLiveActivity()` | `NTPUOne/ContentView.swift:80-85` | Android main screen should refresh equivalent persistent class/task notification on first display. |
| Root `ContentView.scenePhase == active` | Calls `refreshLiveActivity()` | `NTPUOne/ContentView.swift:86-90` | Android foreground lifecycle should reconcile class/task status. |
| App scene active | Refreshes ad-free state, reloads widgets, refreshes Live Activity, community fallback notifications | `NTPUOne/NTPUOneApp.swift:356-361` | Android app foreground should refresh ads state, widgets/status notifications, and community notification state. |
| App scene background | Schedules community notification refresh | `NTPUOne/NTPUOneApp.swift:362-364` | Android should schedule equivalent WorkManager/background refresh if community fallback remains. |
| Course data load/change | Refreshes Next Course Live Activity and widget timelines | `NTPUOne/CourseList/CourseData.swift:107`, `NTPUOne/CourseList/CourseData.swift:309-315` | Android course repository changes should update timetable widgets/status notification. |

### 1.8 Notification and Background Task Configuration

Relevant `Info.plist` configuration:

| Key | Value/behavior | Source | Android parity requirement |
|---|---|---|---|
| `BGTaskSchedulerPermittedIdentifiers` | Allows `$(PRODUCT_BUNDLE_IDENTIFIER).communityNotificationRefresh` | `NTPUOne/Info.plist:7-10` | Android WorkManager job identifiers/tags should include community notification fallback job. |
| `CFBundleURLTypes` | Registers `ntpuone` and Google reversed client scheme | `NTPUOne/Info.plist:26-43` | Android manifest must register app links/deep links and Google Sign-In configuration. |
| `FirebaseAppDelegateProxyEnabled` | `false` | `NTPUOne/Info.plist:45-46` | Android Firebase initialization can use normal Android integration; note iOS manually handles delegates. |
| `GADApplicationIdentifier` | Google Mobile Ads app ID | `NTPUOne/Info.plist:47-48` | Android requires its own AdMob app ID in manifest. |
| `NSAppTransportSecurity.NSAllowsArbitraryLoads` | `true` | `NTPUOne/Info.plist:49-53` | Android network security config must decide whether cleartext/arbitrary loads are allowed. Prefer explicit domains if possible. |
| `NSSupportsLiveActivities` | `true` | `NTPUOne/Info.plist:54-55` | Android needs equivalent persistent class/task status surface, not ActivityKit. |
| `SKAdNetworkItems` | Many ad network IDs | `NTPUOne/Info.plist:56-289` | Android ad attribution differs; AdMob setup and Play policies must be handled separately. |

### 1.9 Community Notification Token Registration

The app stores FCM tokens in Firestore collection `communityDeviceTokens` under the local `deviceSecret` document ID.

Source evidence: `NTPUOne/NTPUOneApp.swift:198-227`.

Firestore payload fields:

| Field | Meaning | Source |
|---|---|---|
| `deviceId` | Local public device identifier from `UserDefaults.commentDeviceId` or generated UUID | `NTPUOne/NTPUOneApp.swift:198-208` |
| `deviceSecret` | Local private secret from `UserDefaults.communityDeviceSecret` or generated UUID | `NTPUOne/NTPUOneApp.swift:210`, `NTPUOne/NTPUOneApp.swift:230-237` |
| `fcmToken` | Firebase Cloud Messaging registration token | `NTPUOne/NTPUOneApp.swift:211-215` |
| `platform` | Fixed string `ios` | `NTPUOne/NTPUOneApp.swift:215` |
| `updatedAt` | Firestore server timestamp | `NTPUOne/NTPUOneApp.swift:216` |
| `ownerUid` | Current Firebase Auth UID if signed in | `NTPUOne/NTPUOneApp.swift:218-219` |
| `ownerEmail` | Current Firebase Auth email if signed in | `NTPUOne/NTPUOneApp.swift:220` |

Android parity requirements:

| iOS behavior | Android requirement |
|---|---|
| Generate/persist local `commentDeviceId` | Android must generate and persist equivalent stable local device ID if backend rules expect it. |
| Generate/persist `communityDeviceSecret` | Android must persist a private token/secret if using same Firestore document model. |
| Write `platform: ios` | Android must write `platform: android`. |
| Merge token document | Android must use merge/update behavior so owner fields can be added later without deleting token fields. |
| Include owner fields when signed in | Android must attach Firebase Auth UID/email when available. |

### 1.10 App Review Prompt

The app increments `appLaunchCount` in `UserDefaults` on `NTPUOneApp.init()`. If launch count is at least 3 and `Bool.random()` returns true, it requests an App Store review through `SKStoreReviewController`.

Source evidence: `NTPUOne/NTPUOneApp.swift:344-347`, `NTPUOne/NTPUOneApp.swift:368-386`.

Android parity requirements:

| iOS behavior | Android requirement |
|---|---|
| Track launch count | Android should store launch count in SharedPreferences/DataStore. |
| Random review prompt after 3 launches | Android should use Play Core In-App Review API or remove randomness if product decision changes. |
| Requires foreground scene | Android review prompt should only be triggered from active Activity. |

### 1.11 Batch 1 Coverage Checklist

| Item | Status |
|---|---|
| App entry point documented | Complete |
| Firebase/App Check/Analytics/Ads startup documented | Complete |
| Core Data/App Group/CloudKit store documented | Complete |
| Root tabs documented | Complete |
| Deep links documented | Complete |
| First-run onboarding gate documented | Partial |
| Every onboarding button documented | Pending |
| Scene lifecycle hooks documented | Complete |
| Community notification FCM token payload documented | Complete |
| Info.plist permissions/capabilities documented | Partial, SKAdNetwork list summarized |
| Android parity notes included | Complete for audited items |

### 1.12 Batch 1 Open Gaps

| Gap | Reason | Planned batch |
|---|---|---|
| Full onboarding page/button inventory | Completed in section 1A | N/A |
| Account center/profile navigation from About tab | Needs About explorer/source merge | Batch 9 |
| Community tab details | Needs community explorer/source merge | Batch 6 |
| Home tab dashboard internals | Needs home explorer/source merge | Batch 3 |
| Exact localization text tables | Needs localization key sweep per feature | Each feature batch |

## 1A. First-Run Onboarding Detailed Flow

### 1A.1 Entry Conditions

The onboarding flow is controlled by `@AppStorage("hasCompletedFirstRunOnboarding")` in `ContentView`. On first root appearance, if the flag is false, `showFirstRunOnboarding` becomes true and a full-screen `FirstRunOnboardingView` is presented. Completion sets the flag true and hides the cover. Interactive dismissal is disabled.

Source evidence: `NTPUOne/ContentView.swift:27`, `NTPUOne/ContentView.swift:73-83`.

Android parity requirements:

| Requirement | Android behavior |
|---|---|
| Persistent first-run flag | Store `hasCompletedFirstRunOnboarding` equivalent in DataStore/SharedPreferences. |
| Non-dismissable onboarding | Do not allow back gesture to bypass first-run flow unless the user taps a supported skip/continue action. |
| Main app availability | Main navigation can exist behind the gate, but user must not interact with it until onboarding finishes. |

### 1A.2 Onboarding Page Sequence

`FirstRunOnboardingView` initially displays a page-style carousel with three pages.

Source evidence: `NTPUOne/ContentView.swift:145-164`.

| Order | Title key | Message key | Icon | Tint | Android equivalent |
|---|---|---|---|---|---|
| 1 | `onboarding_dashboard_title` | `onboarding_dashboard_message` | `rectangle.grid.2x2` | Blue | Dashboard/home introduction card. |
| 2 | `onboarding_timetable_title` | `onboarding_timetable_message` | `calendar.badge.clock` | Green | Timetable/course introduction card. |
| 3 | `onboarding_community_title` | `onboarding_community_message` | `person.text.rectangle` | Orange | Community/profile introduction card. |

The carousel uses a page indicator and card visuals: icon in a rounded square, title, message, grouped background, and accessibility-combined card semantics. Android should implement equivalent horizontally-paged cards or a stepper with the same content sequence.

### 1A.3 Onboarding Buttons and State Machine

Source evidence: `NTPUOne/ContentView.swift:207-278`, `NTPUOne/ContentView.swift:289-295`.

| Visible state | Button/action | Result | Android parity requirement |
|---|---|---|---|
| Intro page, not last | `onboarding_next_button` | Increments page selection by 1 with animation | Advance to next onboarding page. |
| Intro page, any page | `onboarding_skip_button` | Calls `onFinish()` | Mark onboarding complete and enter app. |
| Intro last page | `onboarding_start_button` | Switches to freshman prompt | Do not finish immediately; ask new-student question first. |
| Freshman prompt | `onboarding_freshman_yes_button` | Calls `applyFreshmanPreference(true)` | Mark new-student checklist as favorite and first quick feature, then show Google login prompt. |
| Freshman prompt | `onboarding_freshman_no_button` | Calls `applyFreshmanPreference(false)` | Keep checklist available but not favorited on home shortcuts, then show Google login prompt. |
| Google login prompt | `onboarding_google_login_button` | Calls `CommunityProfileManager.signInWithGoogleSchoolEmail()` | Start Google school-email sign-in. |
| Google login prompt | `onboarding_google_continue_button` | Calls `onFinish()` | Finish onboarding whether or not sign-in succeeded. |

### 1A.4 Freshman Preference Side Effects

Freshman preference is implemented by `StudentImpactStore.applyNewStudentShortcutPreference(isNewStudent:)`.

Source evidence: `NTPUOne/Other/StudentImpactModels.swift:138-152`.

| Choice | Data mutation | Required Android behavior |
|---|---|---|
| Yes, new student | Remove quick feature `new-student-checklist`, set `isFavorite = true`, insert at index 0, persist order/favorites | The New Student Checklist must become the first favorite quick feature on the home dashboard. |
| No, not new student | Remove quick feature `new-student-checklist`, set `isFavorite = false`, reinsert at original index, persist order/favorites | The checklist remains available in customization/order data but is hidden from default favorite shortcuts. |

Persisted keys:

| Key | Stored value | Source |
|---|---|---|
| `homeQuickFeatureOrder` | JSON array of quick feature IDs | `NTPUOne/Other/StudentImpactModels.swift:97`, `NTPUOne/Other/StudentImpactModels.swift:207-210` |
| `homeQuickFeatureFavorites` | JSON set of favorite quick feature IDs | `NTPUOne/Other/StudentImpactModels.swift:98`, `NTPUOne/Other/StudentImpactModels.swift:207-210` |

### 1A.5 Reopening Onboarding From My Tab

The About/My tab contains a button labeled `show_onboarding_again`. Tapping it presents the same `FirstRunOnboardingView` as a full-screen, non-dismissable cover. In this re-run path, completion only hides the cover and does not rewrite the root `hasCompletedFirstRunOnboarding` flag.

Source evidence: `NTPUOne/AboutView/AboutView.swift:83-90`, `NTPUOne/AboutView/AboutView.swift:161-166`.

Android parity requirements:

| Requirement | Android behavior |
|---|---|
| Settings entry point | My/About tab must include a way to replay onboarding. |
| Same flow | Replayed onboarding must use the same cards, freshman prompt, and Google prompt. |
| No accidental first-run reset | Replaying onboarding should not force future first-run presentation unless the privacy reset flow does so explicitly. |

## 2. Data, Local Storage, and Cross-Feature State

### 2.1 Local Key Inventory

The iOS app uses a mix of Core Data, App Group shared SQLite, CloudKit sync, and `UserDefaults`/`@AppStorage`. Android must preserve behavior-level state even if storage technology differs.

| Key | Owner | Meaning | Source | Android equivalent |
|---|---|---|---|---|
| `hasCompletedFirstRunOnboarding` | Root app/onboarding | First-run onboarding completion | `NTPUOne/ContentView.swift:27` | DataStore boolean. |
| `nextCourseLiveActivityEnabled` | Home/Live Activity | Toggle for persistent next-course surface | `NTPUOne/CourseList/NextCourseLiveActivityManager.swift:11`, `NTPUOne/WebViews/LinkView.swift:82` | DataStore boolean for ongoing notification/widget status. |
| `commentNickname` | About/community/food comments | Local display nickname | `NTPUOne/AboutView/AboutView.swift:36`, `NTPUOne/WebViews/LinkView.swift:93` | DataStore string. |
| `commentDeviceId` | About/comments/community | Stable anonymous local device identity | `NTPUOne/AboutView/AboutView.swift:37`, `NTPUOne/AboutView/AboutView.swift:181-185` | DataStore generated UUID. |
| `isAdmin` | About/admin/ads/badges | Local admin UI flag; server authorization must still be verified | `NTPUOne/AboutView/AboutView.swift:33` | DataStore boolean for UI only; backend custom claims/rules remain authoritative. |
| `adFreeUntil` | Ads | Timestamp until banner/native ads are suppressed | `NTPUOne/Ads/AdFreeService.swift:15` | DataStore timestamp. |
| `rewardedViewCount` | Rewarded ads | Daily rewarded ad view count | `NTPUOne/Ads/RewardedAdHelper.swift:40` | DataStore int. |
| `rewardedViewDate` | Rewarded ads | Date anchor for daily rewarded limit | `NTPUOne/Ads/RewardedAdHelper.swift:41` | DataStore timestamp. |
| `homeQuickFeatureOrder` | Student impact/home | Quick feature ordering | `NTPUOne/Other/StudentImpactModels.swift:97` | JSON/string set or structured table. |
| `homeQuickFeatureFavorites` | Student impact/home | Favorite quick features shown on dashboard | `NTPUOne/Other/StudentImpactModels.swift:98` | JSON/string set. |
| `newStudentChecklistState` | New student checklist | Completion state per checklist item ID | `NTPUOne/Other/StudentImpactModels.swift:99`, `NTPUOne/Other/StudentImpactModels.swift:212-215` | JSON map or Room table. |
| `eventFavorites` | Student impact/events | Saved event favorites | `NTPUOne/Other/StudentImpactModels.swift:100` | JSON list or Room table. |
| `studentInterests` | Student impact | Selected interests | `NTPUOne/Other/StudentImpactModels.swift:101` | JSON list. |
| `taskTemplatesEnabled` | Student impact/memo templates | Enabled memo template IDs | `NTPUOne/Other/StudentImpactModels.swift:102` | JSON map. |
| `todayHubRestaurantRecommendationCache` | Home dashboard | Cached restaurant recommendation | `NTPUOne/WebViews/LinkView.swift:81` | DataStore string/JSON. |

### 2.2 Quick Features and New Student Checklist

`StudentImpactStore` owns the home quick feature ordering/favorites, new-student checklist, event favorites, interests, and task template defaults.

Source evidence: `NTPUOne/Other/StudentImpactModels.swift:87-124`.

Default quick features:

| ID | Destination token | Default favorite | Android route/action |
|---|---|---|---|
| `student-info` | `studentInfo` | true | Open student information web page. |
| `past-exams` | `pastExams` | true | Open past exam site. |
| `school-announcements` | `schoolAnnouncements` | true | Open native school announcements list. |
| `common-links` | `commonLinks` | true | Open all common links page. |
| `ubike` | `ubike` | true | Open Ubike/traffic screen. |
| `campus-map` | `campusMap` | true | Open campus map. |
| `lms` | `lms` | true | Open LMS web page. |
| `course-reviews` | `courseReviews` | true | Open course review site. |
| `leave-system` | `leaveSystem` | true | Open leave system. |
| `library` | `library` | true | Open library login. |
| `food-wheel` | `foodWheel` | true | Open random food picker. |
| `new-student-checklist` | `newStudentChecklist` | true before onboarding preference | Open New Student Checklist. |

Source evidence: `NTPUOne/Other/StudentImpactModels.swift:261-274`.

New Student Checklist default items:

| ID | Action destination |
|---|---|
| `open-student-info` | `https://cof.ntpu.edu.tw/student_new.htm` |
| `course-selection` | `https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.chi_main` |
| `past-exams` | `https://past-exam.ntpu.cc` |
| `login-lms` | `https://lms3.ntpu.edu.tw/` |
| `join-clubs` | `https://www.extracurricular-activities-section.com.tw/` |
| `library-login` | `https://library.ntpu.edu.tw/masses/showMassesLogin` |
| `campus-directory` | `https://sea.cc.ntpu.edu.tw/pls/ld/campus_dir_m.main` |
| `student-union` | `https://linktr.ee/ntpusu` |
| `food-traffic` | Native restaurant picker and Ubike actions |

Source evidence: `NTPUOne/Other/StudentImpactModels.swift:276-309`.

## 3. Home Dashboard and Web Link Data

### 3.1 Home Tab Entry

The home tab is `LinkView(courseData:memoManager:)`, tagged as root tab 0 and labeled `Main` with icon `house`.

Source evidence: `NTPUOne/ContentView.swift:38-43`.

The home screen is responsible for mixing native cards and shortcut entry points: today/course/memo status, quick features, web links, school announcements, weather, restaurants, Ubike/campus map, and Live Activity toggle. Detailed visual layout remains pending in this draft, but the route/data inventory below is source-backed.

### 3.2 Canonical Web Link Groups

`WebManager.websArray` contains the canonical static university link catalog. Android must preserve group order, item IDs, localized titles, icon intent, and URL routing behavior.

Source evidence: `NTPUOne/WebViews/WebData.swift:31-87`.

| Group ID | Group title key | Included URL types |
|---|---|---|
| 0 | `web_main_site` | NTPU main site `https://new.ntpu.edu.tw/` |
| 1 | `web_student` | Student information system, LMS |
| 2 | `web_course` | Course search, course reviews, past exams |
| 3 | `web_departments` | College, department, and graduate institute websites |
| 4 | `web_calendar` | Dynamic Firestore calendar links |
| 5 | `web_student_union` | Student union Linktree and voting site |
| 6 | `web_others` | Clubs, campus directory, suggestions, library login, leave system |

Dynamic calendar links are loaded from Firestore collection `calendar`, ordered by `id`, and decoded as `WebData`.

Source evidence: `NTPUOne/WebViews/WebData.swift:89-115`.

Android parity requirements:

| Requirement | Android behavior |
|---|---|
| Static link catalog | Use same IDs, localized labels, groups, and URLs. |
| Calendar collection | Listen or fetch Firestore `calendar` ordered by `id`. |
| Link opening | Use native in-app browser/custom tab unless a route is explicitly native. |
| `https://past-exam.ntpu.cc` special case | iOS opens this externally in WebView/CommonLinks handling; Android should preserve if the site requires external browser behavior. |

## 4. Course and Timetable

### 4.1 Course Domain Model

`Course` is an identifiable local model backed by Core Data `CourseEntity`.

Source evidence: `NTPUOne/CourseList/CourseData.swift:14-60`.

| Field | Type/meaning | Android persistence requirement |
|---|---|---|
| `id` | Stable course UUID/string | Primary key in Room/local DB. |
| `name` | Course title | Required display field. |
| `day` | Weekday string such as `monday` | Store canonical weekday enum/string. |
| `startTime` | `TimeStart` raw time string | Store actual start time or slot-derived start time. |
| `timeSlot` | Slot enum (`morning1`, `afternoon1`, etc.) | Store slot enum to place in timetable grid. |
| `location` | Classroom/location | Optional display field. |
| `teacher` | Teacher name | Optional display field. |
| `isNotification` | Whether class reminder is enabled | Drives notification scheduling. |

Time slots and start times:

| Slot | Start | End used by Live Activity |
|---|---|---|
| `morning1` | 08:10 | 09:00 |
| `morning2` | 09:10 | 10:00 |
| `morning3` | 10:10 | 11:00 |
| `morning4` | 11:10 | 12:00 |
| `afternoon1` | 13:10 | 14:00 |
| `afternoon2` | 14:10 | 15:00 |
| `afternoon3` | 15:10 | 16:00 |
| `afternoon4` | 16:10 | 17:00 |
| `afternoon5` | 17:10 | 18:00 |
| `evening1` | 18:30 | 19:20 |
| `evening2` | 19:25 | 20:15 |
| `evening3` | 20:25 | 21:15 |
| `evening4` | 21:20 | 22:10 |

Source evidence: `NTPUOne/CourseList/CourseData.swift:24-59`, `NTPUOne/CourseList/NextCourseLiveActivityManager.swift:346-398`.

### 4.2 Course Persistence and CRUD

`CourseData` owns the in-memory course list and Core Data persistence.

Source evidence: `NTPUOne/CourseList/CourseData.swift:62-74`.

| Operation | iOS behavior | Source | Android requirement |
|---|---|---|---|
| Load courses | Fetch all `CourseEntity`, map to `Course`, schedule notifications, refresh Live Activity/widgets | `CourseData.swift:76-108` | Load Room table into observable state, schedule class reminders, update widgets/status. |
| Add course | Insert entity, derive start time from slot, schedule notification if enabled, append to memory, refresh status | `CourseData.swift:125-182` | Create local row, normalize start time, schedule reminder, update state/widgets. |
| Update course | Update matching entity by `id`, schedule or cancel notification, refresh status | `CourseData.swift:238-277` | Update row and reminder atomically. |
| Delete course | Cancel notification, delete matching entity, remove from memory, refresh status | `CourseData.swift:184-209` | Delete row and cancel reminder. |
| Delete all courses | Batch delete, cancel pending course notification IDs, refresh status | `CourseData.swift:279-307` | Clear course table and cancel all course reminder IDs without canceling memo reminders. |

### 4.3 Course Notifications

If `course.isNotification` is true, iOS schedules a repeating `UNCalendarNotificationTrigger` using the course weekday and start time. Notification identifiers are course IDs. Body includes day, start time, location, and teacher.

Source evidence: `NTPUOne/CourseList/CourseData.swift:110-123`, `NTPUOne/CourseList/CourseData.swift:337-360`.

Android parity requirements:

| Requirement | Android behavior |
|---|---|
| Reminder identity | Use course ID as stable notification/work identifier. |
| Repeating weekly schedule | Use AlarmManager/WorkManager depending on exact notification reliability requirement. |
| Per-course toggle | Schedule only if enabled, cancel when disabled. |
| Do not cancel memo notifications | Course delete-all must only cancel course reminder IDs. |

## 5. Memo and Today Tasks

### 5.1 Memo Manager State

`MemoManager` owns all memo/task state, filtering, sorting, persistence, notification permission handling, notification scheduling, and Live Activity todo refresh.

Source evidence: `NTPUOne/MemoView/MemoManager.swift:13-47`.

State fields:

| Field | Meaning |
|---|---|
| `memos` | Full memo list from Core Data. |
| `filteredMemos` | Current list after filters and sort. |
| `filterStatus` | Optional status filter. |
| `filterTagTypes` | Multi-select tag filters. |
| `filterCourseLink` | Optional course-linked filter. |
| `filterIncompleteOnly` | Default true; hides done tasks unless disabled. |
| `showOverdueOnly` | Overdue-only filter. |
| `sortBy` | Due date, priority, created date, or updated date. |

### 5.2 Memo Persistence and CRUD

Source evidence: `NTPUOne/MemoView/MemoManager.swift:91-114`, `NTPUOne/MemoView/MemoManager.swift:185-282`.

| Operation | iOS behavior | Android requirement |
|---|---|---|
| Load memos | Fetch `MemoEntity`, decode reminder rules, clean expired non-repeating reminders, apply filters/sort, refresh Live Activity todos | Room load plus reminder-rule cleanup and status surface update. |
| Add memo | Insert Core Data entity, save, append to memory, apply filters/sort, refresh todos, schedule notification | Insert row, update list, schedule reminders. |
| Update memo | Fetch by ID, overwrite entity fields, save, update memory, apply filters/sort, refresh todos, schedule notification | Update row and reminder schedule. |
| Delete memo | Fetch by ID, delete entity, save, remove memory, apply filters/sort, refresh todos, cancel notification | Delete row and cancel reminder IDs. |

Persisted memo fields from `updateEntity`:

| Field | Source |
|---|---|
| `id`, `title`, `content` | `MemoManager.swift:260-263` |
| `tagType`, `courseLink`, `status`, `priority` | `MemoManager.swift:264-267` |
| `createdAt`, `updatedAt`, `dueAt`, `planAt`, `doneAt` | `MemoManager.swift:268-272` |
| `disableAutoDueReminder`, `disableAutoPlanReminder` | `MemoManager.swift:273-274` |
| encoded `reminderRulesData` | `MemoManager.swift:276-281` |

### 5.3 Memo Status Actions

Source evidence: `NTPUOne/MemoView/MemoManager.swift:284-341`.

| Action | Behavior | Android parity requirement |
|---|---|---|
| Mark completed | Set status `.done`, set `doneAt = now`, update `updatedAt` | Preserve done timestamp. |
| Mark incomplete | Set status `.todo`, clear `doneAt`, update `updatedAt` | Clear completion timestamp. |
| Toggle completion | Switch between done and todo | Same one-tap behavior in lists/cards. |
| Update status | Set status, set/clear `doneAt` depending on `.done` | Status picker must apply same timestamp semantics. |
| Update planned time | Set `planAt`, update timestamp | Planning UI must update schedule/status surfaces. |
| Snooze | Set status `.snoozed`, set `planAt`, update timestamp | Snooze action should move task out of immediate today flow until planned time. |

### 5.4 Notification Permission and Reminder Scheduling

On init, `MemoManager` checks notification settings. If authorized/provisional, it schedules all memo notifications. If not determined, it requests alert/badge/sound permission and schedules after grant. If denied, it logs and does not schedule.

Source evidence: `NTPUOne/MemoView/MemoManager.swift:43-87`.

Android parity requirements:

| Requirement | Android behavior |
|---|---|
| Runtime notification permission | Request Android notification permission on Android 13+ before scheduling user-visible reminders. |
| Respect denial | Do not schedule/display notifications if permission is denied. |
| Schedule after grant | Immediately schedule existing memo reminders after permission grant. |
| Cleanup expired one-off rules | Remove non-repeating reminder rules whose trigger time has passed. |

## 11. Widgets, Live Activity, and Android Equivalents

### 11.1 iOS Live Activity Manager Contract

`NextCourseLiveActivityManager` is the app-side state owner for the next-course Live Activity. ActivityKit requests are local-only and do not register a Live Activity push token; boundary refresh relies on local rollover and the widget's date-based display resolution when the system lets the activity render.

Source evidence: `NTPUOne/CourseList/NextCourseLiveActivityManager.swift:7-26`, `NTPUOne/CourseList/NextCourseLiveActivityManager.swift:149-168`.

| Property/key | Meaning | Android equivalent |
|---|---|---|
| `isEnabledKey = "nextCourseLiveActivityEnabled"` | User toggle for the persistent status surface | DataStore boolean for ongoing notification/widget. |
| `activityID = "next-course"` | Activity identity | Notification ID/channel tag. |
| `rolloverLeeway = 1` | One second delay after class boundary before local fallback resync | Small post-boundary refresh delay. |
| Local ActivityKit state | Course start/end transitions are resolved from local dates, subject to iOS background/runtime limits | Android ongoing notification/status updates should use local scheduling and avoid promising exact background refresh. |
| `latestCourses`, `latestMemos` | Last known source data | Repository-backed current state. |
| `syncGeneration` | Cancels stale sync work | Coroutine/job generation or latest-state guard. |

### 11.2 Live Activity Sync Rules

Source evidence: `NTPUOne/CourseList/NextCourseLiveActivityManager.swift:28-126`.

| Trigger | Behavior | Android requirement |
|---|---|---|
| Courses changed | `sync(with:)` stores latest courses and calls `syncIfNeeded()` | Refresh ongoing notification/widget when timetable changes. |
| Courses+memos changed | `sync(courses:memos:)` stores both and calls sync | Refresh combined class/task status. |
| Memos changed | `syncMemos(_:)` stores memos and calls sync | Refresh urgent task summary. |
| Toggle enabled on | Persist true and sync | Start/update Android status surface. |
| Toggle enabled off | Persist false and stop/end activity | Remove ongoing notification/status surface. |
| Activity authorization disabled | End existing activities | If Android notifications are disabled, remove scheduled ongoing surface or degrade silently. |
| Multiple activities | Keep first, end extras | Keep one notification/status instance. |

### 11.3 Next Course Timeline Rules

Source evidence: `NTPUOne/CourseList/NextCourseLiveActivityManager.swift:382-409`.

| Condition | Displayed course | Next refresh boundary |
|---|---|---|
| A course is currently in progress today | Current course with `isInProgress = true` | Course end time. |
| No current course, but future course remains today | Next future course with `isInProgress = false` | Course start time. |
| No remaining course today | No course snapshot | Next day start. |

Important: the resolver only considers courses whose weekday matches the current date. It does not show tomorrow's class as the next course today.

### 11.4 Urgent Today Todo Rules

Source evidence: `NTPUOne/CourseList/NextCourseLiveActivityManager.swift:438-472`.

Included memos:

| Rule | Included? |
|---|---|
| Status is `.done` | No. |
| Overdue | Yes. |
| `dueAt` is today | Yes. |
| `planAt` is today | Yes. |
| None of the above | No. |

Sorting:

1. Overdue items before non-overdue items.
2. Lower `priority.sortOrder` first.
3. Earlier `dueAt` or `planAt` first.
4. More recently updated first.

The payload is capped to three items. Each snapshot contains memo ID, title, detail text, numeric priority, and overdue flag.

Android parity requirements:

| Requirement | Android behavior |
|---|---|
| Summary size | Ongoing notification/widget should show at most three urgent todos. |
| Detail text | Use `overdue`, `HH:mm` for due/plan time, or priority display fallback. |
| Course + todo combination | If class data is empty but urgent todos exist, Android may keep a task status surface. |
| Boundary refresh | Schedule refresh at class start/end or next day start, subject to Android background limits. |

## 6. Community

### 6.1 Community Tab Entry and High-Level Screen

The community tab is `CommunityView()`, tagged as root tab 3 and labeled with localized `community_title`. It is implemented in `ContentView.swift` rather than a separate module file.

Source evidence: `NTPUOne/ContentView.swift:57-61`, `NTPUOne/ContentView.swift:1658-1754`.

Community screen structure:

| Element | Behavior | Source | Android parity requirement |
|---|---|---|---|
| Hero card | Shows community icon, `NTPU` badge, localized hero title, and optional profile display line | `ContentView.swift:1761-1798` | Header card with profile identity context. |
| Category picker | Horizontal chips for all categories; category button changes selected filter | `ContentView.swift:1800-1839` | Horizontal filter chips. |
| Category subscription bell | For non-`all` categories, toggles subscription via `CommunitySubscriptionManager.toggleCategory` | `ContentView.swift:1821-1833` | Bell button per category with subscribed/unsubscribed states. |
| Search | `searchable(text:prompt:)`; filters title/body locally | `ContentView.swift:1668-1676`, `ContentView.swift:1739-1740` | Search bar filters currently loaded topics by title/body. |
| Topic list | Shows loading, empty, error, or topic rows | `ContentView.swift:1693-1735` | Preserve loading/empty/error states. |
| Topic row tap | Opens `CommunityTopicDetailView(topic:subscriptionManager:)` | `ContentView.swift:1719-1724` | Navigate to topic detail. |
| Add topic | Toolbar primary action opens composer sheet | `ContentView.swift:1741-1752` | Floating/action-bar compose button opens composer. |
| Ads | Inserts native ad every 5 topics when not ad-free | `ContentView.swift:1659-1660`, `ContentView.swift:1726-1730`, `ContentView.swift:1757-1759` | If Android ads are enabled, insert ad after every fifth visible topic unless user is ad-free. |
| Load | Calls `manager.loadTopics()` on appear | `ContentView.swift:1753` | Load topic feed when screen appears. |

### 6.2 Community Categories

Community categories are validated by both app code and Firestore rules. Server-valid categories are `food`, `course`, `campus`, `question`, `trade`, and `meetup`; UI also has `all` as a local filter category.

Source evidence: `firebase/firestore.rules:62-64`, `firebase/functions/communityContent.js:6`, `NTPUOne/ContentView.swift:1803-1836`.

Android parity requirements:

| Category | Backend value | Notes |
|---|---|---|
| All | local-only `all` | UI filter only; do not write as topic category. |
| Food | `food` | Restaurant/food discussions. |
| Course | `course` | Course discussions. |
| Campus | `campus` | Campus topics. |
| Question | `question` | Default composer category when selected filter is all. |
| Trade | `trade` | Exchange/trade topics. |
| Meetup | `meetup` | Meetup/social topics. |

### 6.3 Topic Row Fields

Topic rows display category, relative time, title, body preview, author display name, optional badge, optional department/year profile line, and reply count.

Source evidence: `NTPUOne/ContentView.swift:1842-1888`.

Android row requirements:

| Field | Required behavior |
|---|---|
| Category | Use category title/icon/color. |
| Created time | Use localized relative time. |
| Title | Two-line limit in list. |
| Body preview | Two-line secondary text. |
| Author name | Use local override if current anonymous device ID matches author device ID. |
| Badge | Show badge only when author opted into showing badge. |
| Department/year | Show only according to author profile disclosure flags. |
| Reply count | Localized reply count label. |

### 6.4 Composer Identity and Disclosure Defaults

The composer reads local identity and profile-disclosure defaults from `@AppStorage`.

Source evidence: `NTPUOne/ContentView.swift:1890-1909`.

| Key | Meaning | Android equivalent |
|---|---|---|
| `commentNickname` | Display author name | DataStore string; initialize if empty. |
| `commentDeviceId` | Anonymous public author device ID | DataStore generated UUID. |
| `communityDepartment` | Optional department line | DataStore string. |
| `communityEntryYear` | Optional entry year | DataStore string. |
| `communityShowDepartment` | Default publish department disclosure | DataStore boolean. |
| `communityShowYear` | Default publish year disclosure | DataStore boolean. |
| `communityShowBadge` | Default publish badge disclosure | DataStore boolean. |

### 6.5 Community Firestore Collections

The Firebase functions README and Firestore rules define the canonical community backend model.

| Collection/path | Purpose | Read/write model | Source |
|---|---|---|---|
| `communityTopics/{topicId}` | Public topic documents | Public read; authenticated create with owner doc; limited owner update/delete | `firestore.rules:435-446` |
| `communityTopics/{topicId}/replies/{replyId}` | Public replies | Public read; authenticated create with owner doc; owner update/delete | `firestore.rules:448-455` |
| `communityContentOwners/{uid}/topics/{topicId}` | Private topic ownership index | Owner read/list; create only in same batch as public topic; no direct client write at parent | `firestore.rules:404-419` |
| `communityContentOwners/{uid}/replies/{topicId_replyId}` | Private reply ownership index | Owner read/list; create only in same batch as public reply | `firestore.rules:421-432` |
| `communityDeviceTokens/{deviceSecret}` | FCM token and subscription arrays | Not readable by clients; secret/owner write | `firestore.rules:375-380` |
| `communityProfiles/{deviceSecret}` | Private local-installation community profile | Not readable; secret/owner write | `firestore.rules:368-373` |
| `communityUserProfiles/{uid}` | Signed-in user profile sync | Auth owner read/create/update/delete | `firestore.rules:382-384` |
| `communityCategorySubscriptions/{category}/devices/{deviceSecret}` | Category subscriber devices | Not readable; client creates/updates own secret doc; owner delete | `firestore.rules:386-393` |
| `communityTopicSubscriptions/{topicId}/devices/{deviceSecret}` | Topic subscriber devices | Not readable; client creates/updates own secret doc; owner delete | `firestore.rules:395-402` |

Android backend requirements:

| Requirement | Android behavior |
|---|---|
| Public content contains no owner UID | Do not expose UID in public topic/reply docs. |
| Ownership index required | Create/update/delete must use the same owner-doc model expected by rules/functions. |
| Auth required for public community writes | Android must sign in with Firebase Auth before creating topics/replies under current rules. |
| Device secret distinct from public device ID | Store private `communityDeviceSecret` separately from public `commentDeviceId`. |
| Profiles private | Public posts copy only chosen profile display fields; do not rely on reading profile docs for feed display. |

### 6.6 Cloud Callable Community APIs

`firebase/functions/communityContent.js` exports callable APIs for community content and device cleanup. These APIs operate with Admin SDK and enforce validation/ownership checks.

| Callable | Input highlights | Behavior | Source |
|---|---|---|---|
| `createCommunityTopic` | `deviceSecret`, optional `topicId`, title/body/category/author fields | Creates public topic and private owner topic doc in one batch; returns `topicId` | `communityContent.js:38-65` |
| `createCommunityReply` | `deviceSecret`, `topicId`, optional `replyId`, body/author fields | Transactionally creates reply, increments `replyCount`, creates owner reply doc; blocks deleted topics | `communityContent.js:67-106` |
| `listMyCommunityContent` | `deviceSecret` | Lists owner topics and replies ordered by `createdAt desc` | `communityContent.js:108-121` |
| `deleteCommunityDeviceData` | `deviceSecret` | Deletes token/profile/subscriptions and owner indexes; returns deletion counts | `communityContent.js:123-151` |
| `updateCommunityTopic` | `deviceSecret`, `topicId`, `title`, `body` | Verifies active owner doc and updates public/owner topic content | `communityContent.js:153-183` |
| `deleteCommunityTopic` | `deviceSecret`, `topicId` | Soft-deletes public topic and marks owner doc deleted | `communityContent.js:185-225` |
| `updateCommunityReply` | `deviceSecret`, `topicId`, `replyId`, `body` | Verifies owner doc and updates reply body/owner preview | `communityContent.js:227-255` |

Coverage gap: the remainder of `deleteCommunityReply` and helper validation functions must be added in the next backend pass.

### 6.7 Push Notification Functions

`firebase/functions/index.js` defines Firestore triggers for community push notifications.

Source evidence: `firebase/functions/index.js:10-79`.

| Trigger | Path | Recipients | Message data | Android parity requirement |
|---|---|---|---|---|
| Category subscribers | `communityTopics/{topicId}` create | Active device docs under `communityCategorySubscriptions/{category}/devices`, excluding author device ID | `type=communityTopic`, `topicId`, `category` | Android FCM handler should route to topic detail or community tab. |
| Topic subscribers | `communityTopics/{topicId}/replies/{replyId}` create | Active device docs under `communityTopicSubscriptions/{topicId}/devices`, excluding reply author device ID | `type=communityReply`, `topicId`, `replyId` | Android FCM handler should route to topic detail and optionally reply anchor. |

Token cleanup behavior:

| Condition | Cleanup |
|---|---|
| Token doc missing/empty | Deactivate related subscription doc(s) and delete invalid token record where applicable. |
| FCM invalid/unregistered token | Delete `communityDeviceTokens/{deviceSecret}` and mark related category/topic subscriptions inactive with reason `invalid-fcm-token`. |
| Batch size | Sends FCM in batches of 500 tokens; Firestore cleanup batches at 450 operations. |

Source evidence: `firebase/functions/index.js:81-201`.

### 6.8 Firestore Security Principles

Source evidence: `firebase/firestore.rules:5-77`, `firebase/firestore.rules:202-455`.

| Principle | Rule behavior | Android implication |
|---|---|---|
| Auth owner check | `isAuthOwner(uid)` requires `request.auth.uid == uid` | Authenticated user document paths must use current UID. |
| Secret device documents | Can be written by matching `deviceSecret` payload or owner UID | Android must include `deviceSecret` in secret doc payloads. |
| Valid community categories | Only `food/course/campus/question/trade/meetup` accepted | Client validation should match rules. |
| Valid badge levels | Badge level must be one of `0,1,2,3,4,99` | Android badge mapping must not emit other values. |
| Public topic create | Requires auth, valid fields, and creation of owner doc in same write state | Android must use callable API or equivalent batch transaction. |
| Public reply create | Requires auth, valid fields, non-deleted topic, and owner doc | Android must block reply UI on deleted topics. |
| Topic delete | Soft-delete update only, not document deletion | Android should show deleted topic state rather than expecting missing docs. |

## 7. Food, Restaurants, Comments, and Admin Rules Draft

### 7.1 Restaurant Collections

Restaurant collections are Firestore top-level collections `breakfast`, `lunch`, `dinner`, and `MS`.

Source evidence: `firebase/firestore.rules:66-68`, `NTPUOne/FoodView/FManager.swift:24-105`.

Restaurant document fields allowed by rules:

| Field | Type/constraint | Source |
|---|---|---|
| `store` | non-empty string | `firestore.rules:112-123` |
| `time` | non-empty string | `firestore.rules:112-123` |
| `url` | non-empty string | `firestore.rules:112-123` |
| `address` | non-empty string | `firestore.rules:112-123` |
| `phone` | string | `firestore.rules:112-123` |
| `starNum` | number, non-negative | `firestore.rules:112-123` |
| `lat`, `lng` | number | `firestore.rules:112-123` |
| `check` | bool | `firestore.rules:112-123` |

Public restaurant creation must set `check == false` and `starNum == 1`; admin/developer users may create full valid restaurant documents. Restaurant updates allow either star increments or admin/developer full document updates.

Source evidence: `firebase/firestore.rules:126-130`, `firebase/firestore.rules:498-504`.

### 7.2 Restaurant Comments

Restaurant comments live under `{breakfast,lunch,dinner,MS}/{storeId}/comments/{commentId}` and require a private owner record under `restaurantCommentOwners/{uid}/comments/{mealCollection_storeId_commentId}`.

Source evidence: `firebase/firestore.rules:132-187`, `firebase/firestore.rules:458-467`, `firebase/firestore.rules:506-515`.

Comment public fields:

| Field | Constraint |
|---|---|
| `name` | non-empty string |
| `body` | non-empty string |
| `date` | number |
| `deviceId` | non-empty string |
| `authorUid` | must equal `request.auth.uid` |

Android parity requirements:

| Requirement | Android behavior |
|---|---|
| Auth required | Require Firebase Auth before restaurant comment creation under current rules. |
| Owner doc required | Create private owner doc in same batch/write flow as public comment. |
| Edit body | Only owner can update `body` plus numeric `updatedAt`. |
| Rename display | Owner can update comment `name` only. |
| Delete | Owner can delete public comment and owner doc. |
| User stats | `userStats/{uid}` is public-read and owner-write with non-negative integer `total`. |

## 9. My/About, Feedback, Admin, and Ads Draft

### 9.1 About/My Tab Structure

The My tab is `AboutView()`, tagged as root tab 4 and labeled with localized `my`.

Source evidence: `NTPUOne/ContentView.swift:63-67`, `NTPUOne/AboutView/AboutView.swift:41-180`.

Primary sections/actions:

| Section/action | Behavior | Source | Android parity requirement |
|---|---|---|---|
| Admin console | Visible only when local `isAdmin` true; opens `AdminConsoleView` | `AboutView.swift:45-55` | Show admin entry based on local UI flag, but backend must still enforce custom claims/rules. |
| Add announcement | Button opens `AddOrderView` through `isReward` navigation destination | `AboutView.swift:57-72`, `AboutView.swift:158-160` | My tab announcement submission path. |
| New Student Checklist | Opens `NewStudentChecklistView` | `AboutView.swift:73-79` | Settings shortcut to checklist. |
| Show onboarding again | Presents full-screen onboarding | `AboutView.swift:83-90`, `AboutView.swift:161-166` | Replay onboarding flow. |
| Ad preferences | Shows ad-free state or watch-ad action | `AboutView.swift:91-94`, `AboutView.swift:192-220` | Android equivalent rewarded ad/ad-free controls. |
| Feature suggestion | Opens `FeaturesView` | `AboutView.swift:96-103` | Feedback form. |
| Report bug | Opens `ReportBugView` | `AboutView.swift:105-111` | Bug report form. |
| Contact developer | Opens `ContactMeView` | `AboutView.swift:117-123` | Contact screen. |
| Privacy policy | Opens `PrivacyPolicyView` | `AboutView.swift:125-130` | Privacy policy screen. |
| Account center toolbar | Opens `AccountCenterView` | `AboutView.swift:146-156` | Account/profile button in toolbar. |

### 9.2 Feedback and Admin Firestore Rules

Source evidence: `firebase/firestore.rules:79-110`, `firebase/firestore.rules:475-496`.

| Collection | Client behavior | Admin/developer behavior | Rule source |
|---|---|---|---|
| `order/{orderId}` | Public read; create if valid order fields/tags | Update/delete if `isAdminOrDeveloper()` | `firestore.rules:479-484` |
| `bug/{bugId}` | Create only | Read/delete if admin/developer | `firestore.rules:486-490` |
| `feature/{featureId}` | Create only | Read/delete if admin/developer | `firestore.rules:492-496` |
| `adminUsers/{uid}` | No client read/write | Used only by rules `exists()` check | `firestore.rules:70-77`, `firestore.rules:475-477` |

`isAdminOrDeveloper()` accepts Firebase Auth custom claims `admin == true`, `developer == true`, or a server-side `adminUsers/{uid}` document. Android admin UI must not rely only on a local `isAdmin` flag for backend authorization.
