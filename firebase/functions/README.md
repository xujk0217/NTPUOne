# NTPUOne Firebase

This folder contains the Firebase project configuration for NTPUOne.

Community topic/reply creation and ownership work on the Firebase **Spark plan**
through Firestore security rules plus Firebase Auth private owner documents.
The iOS app writes all community data with **direct, batched Firestore writes** —
there are no callable APIs and no Cloud Functions in use.

Run Firebase CLI commands from the `firebase/` directory so `firebase.json` resolves
`firestore.rules` and `firestore.indexes.json` correctly.

## Current state (2026-08)

- **Community push notifications: disabled.** The previous FCM trigger functions
  (`notifyCommunityCategorySubscribers`, `notifyCommunityTopicSubscribers`) and the
  callable content API (`communityContent.js`) were removed. Course-schedule and
  memo reminders remain local notifications and do not involve this folder.
- The callable API was removed because it never verified `request.auth` and keyed
  ownership by a caller-supplied `deviceSecret`, which allowed tampering with other
  users' content. Any future server API must authenticate every request, derive
  ownership from `request.auth.uid`, enforce App Check, and apply quotas before it
  is deployed.

## What the iOS app writes

- `communityDeviceTokens/{deviceSecret}`: FCM token + subscription arrays (requires sign-in).
- `communityProfiles/{deviceSecret}`: private profile settings for the local installation (requires sign-in).
- `communityCategorySubscriptions/{category}/devices/{deviceSecret}` / `communityTopicSubscriptions/{topicId}/devices/{deviceSecret}`: subscribers (require sign-in).
- `communityContentOwners/{uid}/topics|replies`: private ownership index for the signed-in Google account; created atomically together with each public document.
- `restaurantCommentOwners/{uid}/comments/...`: private ownership index for restaurant comments (created atomically with new comments; legacy comments can be adopted by their original author).
- `userStats/{uid}`: global comment count used for badge levels.
- `communityTopics/{topicId}` + replies, `{breakfast,lunch,dinner,MS}/{storeId}/comments/{commentId}`: public discussion data without owner UID fields on newly written documents.

## Security notes

- Community topics and replies are publicly readable; device tokens, profiles, and
  subscriptions are not client-readable and now require authentication to write.
- Public topics/replies embed a display snapshot (`authorName`, department/year/badge
  flags) chosen by the author at post time; profile edits fan out updates to owned docs only.
- `replyCount` is maintained exclusively inside the same atomic batch that creates or
  deletes a reply; standalone count adjustments are rejected by the rules.
- Restaurant comments no longer store `authorUid`. Legacy documents that still carry
  `authorUid` can be edited/deleted only by that exact authenticated account, and the
  app adopts them into private ownership records then scrubs the field.
- Badge level `99` (developer) cannot be written by regular client calls.
