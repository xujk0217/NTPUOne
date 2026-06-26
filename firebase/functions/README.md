# NTPUOne Community Notifications

This folder is a deployable Firebase Cloud Functions reference for community push notifications
and secure community content ownership actions.

Run Firebase CLI commands from the `firebase/` directory so `firebase.json` resolves
`firestore.rules` and the `functions/` source folder correctly.

The iOS app writes:

- `communityDeviceTokens/{deviceSecret}`: latest FCM token and local subscription arrays.
- `communityProfiles/{deviceSecret}`: private profile settings for the local installation.
- `communityCategorySubscriptions/{category}/devices/{deviceSecret}`: category subscribers.
- `communityTopicSubscriptions/{topicId}/devices/{deviceSecret}`: topic subscribers.
- `communityTopics/{topicId}` and `communityTopics/{topicId}/replies/{replyId}`: discussion data.

The functions send FCM/APNs pushes when:

- a new topic is created in a subscribed category;
- a new reply is created under a subscribed topic.

The callable functions manage community ownership actions:

- create topics/replies while also creating private owner records;
- list the current device's owned topics/replies;
- edit or delete owned topics/replies after checking the private owner record.

Deploying requires Firebase CLI, a configured Firebase project, and APNs/FCM setup for the iOS bundle. This code is not deployed automatically by the app build.

## Required Firebase setup

1. Enable Google as a Firebase Authentication sign-in provider.
2. Replace the placeholder `CLIENT_ID` and `REVERSED_CLIENT_ID` values in
   `NTPUOne/GoogleService-Info.plist` with the current iOS app values from the
   Firebase console.
3. Replace `REVERSED_CLIENT_ID_PLACEHOLDER` in `NTPUOne/Info.plist` with the same
   `REVERSED_CLIENT_ID` value so Firebase Auth can receive the OAuth callback.
4. Configure APNs for the iOS bundle in Firebase Cloud Messaging.
5. Deploy Firestore rules, indexes, and functions from this directory:

   ```sh
   firebase deploy --only firestore:rules,firestore:indexes,functions
   ```

## Security notes

- Community topics and replies are publicly readable.
- Device tokens, category subscriptions, and topic subscriptions are not client-readable.
  Cloud Functions read them with Admin SDK privileges when sending notifications.
- Private device documents are keyed by a local `communityDeviceSecret`; public
  `authorDeviceId` values from topics/replies are not enough to update token,
  profile, or subscription docs.
- Profiles are not client-readable because public topics include `authorDeviceId`.
  The app writes profile metadata directly into topics/replies when authors choose to
  display it.
- Post and reply edits are limited by private ownership records under
  `communityContentOwners/{deviceSecret}`. Public `authorDeviceId` values are not
  enough to edit or delete community content.
- The iOS app now creates topics/replies through callables so new content can be
  managed later. Legacy public content without an owner record is intentionally not
  editable through the management UI.
