# APK Analysis: tv.abema v10.184.0

## Build Info
- **Version**: 10.184.0
- **Git Hash**: 2ec2bb4
- **Target SDK**: 36 (Android 15)
- **No native (.so) libraries** - pure Java/Kotlin app
- **User-Agent**: `AbemaTV;10.184.0;`
- **Quirk string**: `TpPaTqOan` / `TAPaTSPaq` (likely version/build identifiers)

## API Hosts (Production)
- `api.p-c3-e.abema-tv.com` - Main API
- `auth.abema.tv` - Authentication
- `bundle-api.p-c3-e.abema-tv.com` - Bundle API
- `realtime-api.p-c3-e.abema-tv.com` - Realtime API
- `streaming-api-cf.p-c2-x.abema-tv.com` - Streaming API (CF = Cloudflare?)
- `user-content-api.p-c3-e.abema-tv.com` - User content
- `upload-api.p-c3-e.abema-tv.com` - Upload API
- `license.p-c3-e.abema-tv.com` - DRM license
- `wt-api.p-c3-e.abema-tv.com` - (unknown purpose)
- `gateway.p-c2-x.abema-tv.com` - Gateway
- `wr.p-c2-x.abema-tv.com` - (unknown purpose)
- `image.p-c2-x.abema-tv.com` - Image CDN
- `zeus-api.p-c3-e.abema-tv.com` - Zeus service (feature flags/AB testing)
- `avod.ad.abema.io` - Ad video
- `itr.ad.abema.io` - Ad tracking
- `trk.ad.abema.io` - Ad tracking
- `user-schedule-api.ep.c3.abema.io` - User schedule

## Development/Test Hosts (potentially vulnerable)
- `dev-api.d-c3-e.abema-tv.com`
- `dev-auth.abema.tv`
- `dev-bundle-api.d-c3-e.abema-tv.com`
- `dev-realtime-api.d-c3-e.abema-tv.com`
- `dev-streaming-api-cf.d-c2-x.abema-tv.com`
- `dev-upload-api.d-c3-e.abema-tv.com`
- `dev-user-content-api.d-c3-e.abema-tv.com`
- `dev-wt-api.d-c3-e.abema-tv.com`
- `zeus-api.d-c3-e.abema-tv.com`
- `stg-avod.ad.abema.io` - Staging ad
- `stg-trk.ad.abema.io` - Staging tracking
- `ltrk.stg.ad.abema.io` - Staging tracking
- `wv.p-c3-x.abema-tv.com` - Stats (?)

## Authentication Headers
- **`X-Abema-PAT`** - Primary authentication token
- **`X-Abema-PPV-Ticket`** - Pay-per-view ticket token
- **`Authorization: Bearer`** - Bearer token for some endpoints
- **`X-Gateway-Authorization`** - Gateway auth header

## Token Storage Keys
- `abema-native-access-token`
- `abema-native-refresh-token`
- `abema-native-user-token`
- `abema-native-refresh-token-revoked-user-id`
- `abema-native-user-token-before-switching-auth`

## Proto Message Types (Google.protobuf.Any format)
Type URLs follow pattern: `type.googleapis.com/api.<MessageType>` or `type.googleapis.com/auth.<MessageType>`

### Auth Messages
- `auth.CreateAccessTokenRequest/Response`
- `auth.CreateSessionRequest/Response`
- `auth.LoginAsGuestRequest/Response`
- `auth.LoginWithEmailRequest/Response`
- `auth.LoginWithOneTimePasswordRequest/Response`
- `auth.LoginWithSingleDeviceOneTimeTokenRequest/Response`
- `auth.RegisterEmailRequest/Response`
- `auth.RestoreUserRequest/Response`
- `auth.IssueOneTimeTokenRequest/Response`
- `auth.StartAuthorizationRequest/Response`
- `auth.VerifyDeviceAuthorizationRequest/Response`
- `auth.VerifyKYCEmailOneTimePasscodeRequest/Response`

### Token Messages
- `api.IssueTokenRequest` - Token issuance
- `api.IssueTokenResponse`
- `api.MediaTokenResponse`
- `api.IssueOrVerifyTicketTokenResponse`

### API Messages (partial list)
- `api.Channel`, `api.ChannelMediaStatus`, `api.ChannelPlayback`, `api.ChannelStatus`
- `api.ContentlistContent`, `api.ContentlistContentDownload`, `api.ContentlistContentLiveEvent`, `api.ContentlistContentVideo`
- `api.Program`, `api.ProgramPlayback`, `api.ProgramProvidedInfo`
- `api.VideoProgram`, `api.VideoProgramInfo`, `api.VideoSeriesInfo`
- `api.Playlist`, `api.Playlist.ContentItem`
- `api.Slot`, `api.SlotPlayback`, `api.SlotAudience`, `api.SlotComment`
- `api.LiveEvent`, `api.LiveEventViewingAuthority`
- `api.PayperviewTicket`, `api.PurchasedPayperviewTicket`

## API Gateway Classes (80+ endpoints)
Key gateways identified:
- `DefaultAuthApiGateway` - Authentication (guest login, email login, OAuth, device auth)
- `DefaultChannelApiGateway` - Channel listing
- `DefaultSlotApiGateway` - Slot/Timeshift content
- `DefaultLiveEventApiGateway` - Live events
- `DefaultPayperviewApiGateway` - PPV tickets
- `DefaultUserApiGateway` - User profile/settings
- `DefaultVideoStreamApiGateway` - Video streaming
- `DefaultContentListApiGateway` - Content browsing
- `DefaultMylistApiGateway` - User playlists
- `DefaultChatApiGateway` - Live chat
- `DefaultMediaTokenApiGateway` - Media tokens
- `DefaultDownloadValidationApiGateway` - Download validation
- `DefaultRealtimeAuthApi`/`DefaultRealtimeSseApi` - Realtime notifications

## Network Security Config
- **Allows cleartext traffic** for: `localhost`, `10.0.2.2`, `10.0.3.2`, `yospace.com`
- Uses standard Android network security config XML

## Third-Party Services
- Google Firebase (Analytics, Crashlytics)
- Google Play Services (Auth, Ads, ID)
- Twitter Kit (social sharing)
- Adjust (analytics)
- Braze (push notifications)
- New Relic (monitoring)
- Bucketeer (feature flags)
- NPAW (video analytics)
- Google Ad Manager / IMA SDK
- Apple App Store authentication (AppstoreAuthenticationKey.pem)

## Certificate Pinning
- Uses OkHttp with CertificatePinner (SHA-256 pins)
- Pins are likely embedded in the network_security_config or hardcoded

## Potential Vulnerabilities to Investigate
1. **Dev/staging endpoints** - May have weaker auth or debug features
2. **X-Abema-PAT token format** - Need to determine generation mechanism
3. **IDOR on content endpoints** - `/v1/contents/{id}`, `/v1/channels/{id}`
4. **PPV ticket bypass** - `X-Abema-PPV-Ticket` header behavior
5. **Media token endpoint** - `MediaTokenResponse` could reveal token format
6. **Certificate pinning bypass** - Network security config allows yospace.com cleartext

## Session Findings (2026-09-30)

### Dev API Publicly Accessible
- `dev-api.d-c3-e.abema-tv.com` returns 200 for `/v1/channels` and `/v1/broadcast/slots` without auth
- Contains test channels: Smaqtest, thorhammer, aaa, abema-activation, gemma
- Contains test broadcast slots with full metadata (title, times, channel IDs, thumbnails, credits)

### Internal K8s Service Names Leaked
- `x-envoy-decorator-operation` header reveals: `abema-catalog-api.default.svc.cluster.local`, `abema-gateway-cdn.default.svc.cluster.local`

### Auth Flow Details
- Token exchange endpoint: `POST /v1/account/token-exchange/single-device`
- Auth interceptor: `nqsAuthorizationInterceptor` adds `X-Abema-PAT`, `X-Abema-PPV-Ticket`, `X-Gateway-Authorization` headers
- Bearer token extracted from `account.token?.bearerToken`
- All auth endpoints return 401 without valid token

### Additional API Paths Discovered
- `/about/premium`, `/about/premium/register`, `/about/premium/registration`
- `/account/change-from-device`, `/account/plan`, `/account/restore/email`, `/account/restore/otp`
- `/feature/([^/\?#]*)` - feature flag pattern
- `/channels/landing`
- `/tokens/transfer/approved`
- `/playbackResources/{arin}`
- `/video/title/`
- `/payperview/([^/\?#]*)`
- `/1.1/guest/activate.json`
- `/1.1/help/configuration.json`

### Additional Proto Messages Discovered
- `GetIPCheckResponse`, `GetNewsResponse`, `GetUserResponse`
- `GiftMessage`, `GiftFile`, `BroadcastSlotStats`
- `ChannelMediaStatus`, `ChannelPlayback`, `ContentlistContent`, `ContentlistSection`
- `VideoLicenseStatus`, `VideoOnDemandType`, `VideoProgramCredit`, `VideoProgramInfo`
- `VideoSeasonLabel`, `VideoSeriesLabel`, `VideoSeriesInfo`
- `SectionFAQ`, `SectionFeatureItem`, `SectionFirstView`, `SectionPlanList`, `SectionPolicy`
- `SlotMark`, `SlotPayperviewItem`, `SpotList`, `SpotListItem`
- `SubscriptionPage`, `SubscriptionStatus`, `SupporterProfile`
- `UserSubscriptionV2`, `Plan`, `Plan.Payment`, `Plan.PurchaseType`
- `MylistNotification`, `Playlist`, `Popup`, `Question`
