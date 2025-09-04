# Kontext.so Swift SDK

The official Swift SDK for integrating Kontext.so ads into your mobile application.

KontextSwiftSDK is a Swift package that provides an easy way to integrate Kontext.so ads into your iOS application. It manages ad loading, placement and errors with minimalist API. The SDK provides an ad data source and UI components that render ads while remaining flexible on layout.

## Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 15+

## Installation

Swift Package Manager and CocoaPods are two currently supported ways of integrating KontextSwiftSDK into your project.

### Swift Package Manager (Recommended)


The [Swift Package Manager](https://swift.org/package-manager/) is integrated to Swift and is one of the easiest ways to add a dependency to an iOS app. Once the Swift Package is setup add KontextSwiftSDK into your list of dependencies.

```swift
dependencies: [
    .package(url: "https://github.com/kontextso/sdk-swift", .upToNextMajor(from: "1.0.4"))
]
```

Alternatively you can use Xcode's UI: `File > Add Package Dependencies ...` and paste the URL into search.

### CocoaPods

If you prefer CocoaPods instead.

Add the following line to your `Podfile`:

```ruby
pod 'KontextSwiftSDK'
```

## Usage

Once you have the dependency added and resolved you should be able to import the SDK.

```swift
import KontextSwiftSDK
```

### 1. Character

Firstly, prepare information about assistant's Character if it is relevant for this conversation.

```swift
// Character that is being conversed with, leave nil if not relevant for this conversation.
let character = Character(
    // Unique ID of the character
    id: "<character-id>",
    // Name of the character
    name: "<character-name>",
    // URL of the character’s avatar
    avatarUrl: URL(string: "<character-avatar-url>"),
    // Whether the character is NSFW
    isNsfw: <bool>,
    // Greeting of the character
    greeting: "<character-greeting>",
    // Description of the character’s personality
    persona: "<character-persona>",
    // Tags of the character (list of strings)
    tags: ["<tag-1>", "<tag-2>"]
)
```

### 2. Regulatory

Secondly, prepare information about regulations.

```swift
// Prepare regulatory compliance object
let regulatory = Regulatory(
	// Flag that indicates whether or not the request is subject to GDPR regulations (0 = No, 1 = Yes, null = Unknown).
	gdpr: 0,
	// Transparency and Consent Framework's Consent String data structure
	gdprConsent: "<gdpr-consent>",
	// Flag whether the request is subject to COPPA (0 = No, 1 = Yes, null = Unknown).
	coppa: 0,
	// Global Privacy Platform (GPP) consent string
	gpp: "<gpp>",
	// List of the section(s) of the GPP string which should be applied for this transaction
	gppSid: [1, 2],
	// Communicates signals regarding consumer privacy under US privacy regulation under CCPA and LSPA
	usPrivacy: "<us-privacy>"
)
```

### 3. AdsProviderConfiguration

Thirdly, you need to create `AdsProviderConfiguration`. Its information is scoped to one conversation. It uses previously created `character` and `regulatory`.

```swift
let configuration = AdsProviderConfiguration(
	// Your unique publisher token received from your account manager.
	publisherToken: "<publisher-token>",
	// A unique string that should remain the same during the user’s lifetime (used for retargeting and rewarded ads). Eg. uuid or hash of email address work well.
	userId: "<user-id>",
	// Unique ID of the conversation. This is mostly used for ad pacing.
	conversationId: "<conversation-id>",
	// A list of placement codes that identify ad slots in your app. You receive them from your account manager.
	enabledPlacementCodes: ["<code>"],
	// The character object used in this conversation
	character: character,
	// Advertising identifier (IDFA), when allowed by user, otherwise nil
	advertisingId: ASIdentifierManager.shared().advertisingIdentifier,
	// An alphanumeric string that uniquely identifies a device to the app’s vendor (IDFV).
	vendorId: UIDevice.current.identifierForVendor,
	/// Information about regulatory requirements that apply
	regulatory: regulatory,
    // May contain arbitrary key-value pairs. Used to pass publisher-specific information to Kontext. Contents will be discussed with your account manager if needed.   
    otherParams: ["theme": "v1-dark"]
)
```

### 4. AdsProvider

Next, `AdsProvider`, the object responsible for managing the loading and displaying ads. This is the most important part of the library. It utilizes previously created `configuration`.

```swift
let adsProvider = AdsProvider(
	// Previously created configuration (it is immutable and publicly available if you need to refer to it later)
	configuration: configuration,
	// ID of the session, will be nil for new chats, SDK will resolve it internally with first ads.
	sessionId: nil,
    // Optional delegate to consume events using delegate pattern.   
    delegate: self
)

#### Events

AdsProvider provides event observing in two formats

1. AdsProviderDelegate
2. Combine publisher

AdsProvider notifies about events such as:

* `didChangeAvailableAdsTo` - Received after `setMessages` is called and an ad is available, ads received in this event are ready to be rendered in either `InlineAdView` or `InlineAdUIView`.
* `didUpdateHeightForAd` - Received after an ad changes its size when it's being rendered.
* `didReceiveEventAds` - Received from a rendered ad, serves events that occur within the ad (viewed, clicked, error etc.).
* `didEncounterError` - Received when an error occurs in the retrieval of an advertisement, informs about ad not being available or errors retrieving an ad.
```

### 5. Provide information about messages

Adapt your message object to provide necessary information for the ads recommendation to work. You have two options, either make them conform to `MessageRepresentable` to return respective properties or to `MessageRepresentableProviding` and return the `MessageRepresentable` as a whole new object. There is `struct AdsMessage: MessageRepresentable` which you can use for this scenario.

```swift
// 1. Option: Conformance to MessageRepresentable
struct MyChatMessage: MessageRepresentable {
	...
	/// Unique ID of the message
	var id: String { self.uuid.uuidString }
	/// Role of the author of the message (user or assistant)
	var role: Role { self.isUser ? .user : .assistant }
	/// Content of the message
	var content: String { self.messageContent }
	/// Timestamp when the message was created
	var createdAt: Date { self.date }
	...
}

// 2. Option: Conformance to MessageRepresentableProviding
// Better if you have collision of names of properties
struct MyChatMessage: MessageRepresentable {
	...
	var message: MessageRepresentable {
		AdsMessage(
			id: self.uuid.uuidString,
			role: self.isUser ? .user : .assistant,
			content: self.messageContent,
			createdAt: self.date
		)
	...	
}
```

Whenever your list of messages changes you need to pass the new list to AdsProvider.

```swift
adsProvider.setMessages(messages)
```

### 6. Insert InlineAdView into view hierarchy

The last thing remaining is to provide place for the Ads to manifest into. This is done by placing `InlineAdView` into View hierarchy just after the associated message. The view will take care of loading the ad.

```swift
ZStack {
    ForEach(messages, id: \.uuid.uuidString) { message in
        VStack {
            MyChatMessageView(message)
      
            let ad = // Retrieve ad for message
            InlineAdView(ad: ad)
        }
    }
}.onReceive(adsProvider.eventPublisher) { event in
   // React to adsProvider events
}

```

For usage with UIKit please use `InlineAdUIView` instead and refer to the ExampleUIKit app. Beware that the ad view changes size as the ad is rendered - size changes are reported through events from AdsProvider.

Now you are set up and ready to go 🎉

## Documentation

 For more information, see the documentation: [https://docs.kontext.so/sdk/ios](https://docs.kontext.so/sdk/ios)

## License

KontextSwiftSDK is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.
