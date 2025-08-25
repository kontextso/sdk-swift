# Kontext.so Swift SDK

The official Swift SDK for integrating Kontext.so ads into your mobile application.

KontextSwiftSDK is a Swift package that provides an easy way to integrate Kontext.so ads into your iOS application. It manages ad loading, placement and errors with minimalist API. There is no need for complex state management, just iniatlize it and pass it messages whenever they change. The SDK will take care of the rest.

## Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 15+

## Installation

Swift Package Manager and CocoaPods are two currently supported ways of integrating KontextSwiftSDK into your project.

### Swift Package Manager (Recommended)


The [Swift Package Manager](https://swift.org/package-manager/) is integrated to Swift and is one of the easiest ways to add a dependency to na iOS app. Once the Swift Package is setup add KontextSwiftSDK into your list of dependencies.

```swift
dependencies: [
    .package(url: "https://github.com/kontextso/sdk-swift", .upToNextMajor(from: "1.0.1"))
]
```

Alternatively you can use Xcode's UI: `File > Add Package Dependencies ...` and paste the URL into search.

### CocoaPods

If you prefer Cococapods instead.

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
    id: "12345",
    // Name of the character
    name: "Alice",
    // URL of the character’s avatar
    avatarUrl: URL(string: "https://example.com/avatar.png"),
    // Whether the character is NSFW
    isNsfw: false,
    // Greeting of the character
    greeting: "Hello there!",
    // Description of the character’s personality
    persona: "Friendly and helpful",
    // Tags of the character (list of strings)
    tags: ["assistant", "friendly"]
)
```

### 2. Regulatory

Secondly, prepare regulatory compliance object. More information about its properties can be found as documentation of the object in the code.

```
let regulatory = Regulatory(...)
```

### 3. AdsProviderConfiguration

Thirdly, you need to create `AdsProviderConfiguration`. Its information is scoped to one conversation. It uses previously created `character` and `regulatory`.

```swift
let configuration = AdsProviderConfiguration(
	// Your unique publisher token received from your account manager.
	publisherToken: "nexus-dev",
	// A unique string that should remain the same during the user’s lifetime (used for retargeting and rewarded ads). Eg. uuid or hash of email address work well.
	userId: "<some id>",
	// Unique ID of the conversation. This is mostly used for ad pacing.
	conversationId: "<some id>",
	// A list of placement codes that identify ad slots in your app. You receive them from your account manager.
	enabledPlacementCodes: ["inlineAd"],
	// The character object used in this conversation
	character: character,
	// Advertising identifier (IDFA) or GAID, when allowed by user, otherwise nil
	advertisingId: ASIdentifierManager.shared().advertisingIdentifier,
	// An alphanumeric string that uniquely identifies a device to the app’s vendor (IDFV).
	vendorId: UIDevice.current.identifierForVendor,
	// URL of the server from which the ads are served. Defaults to https://server.megabrain.co/
	adServerUrl: nil
	/// Information about regulatory requirements that apply
	regulatory: regulatory
)
```

### 4. AdsProvider

Next, `AdsProvider`, the object responsible for managing the loading and displaying ads. This is the most important part of the library. It utilizes previously created `configuration`.

```swift
let adsProvider = AdsProvider(
	// Previously created configuration (it is immutable and publicly available if you need to refer to it later)
	configuration: configuration,
	// ID of the session, will be nil for new chats, SDK will resolve it internally with first ads.
	sessionId: nil
)

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

Lastly, provide place for the Ads to manifest into. This is done by placing `InlineAdView` into View hierarchy just after the associated message. It will stay empty until an ad linked to the respective message is retrieved.

```swift
ForEach(messages, id: \.uuid.uuidString) { message in
	VStack {
		MyChatMessageView(message)
		InlineAdView(
			adsProvider: adsProvider,
			code: "inlineAd",
			messageId: message.id,
			otherParams: [:] // May contain arbitrary key-value pairs. Used to pass publisher-specific information to Kontext. Contents will be discussed with your account manager if needed.
		)
	}
}

```

Now you are set up and ready to go 🎉

## Documentation

For advanced usage, supported formats, and configuration details, see the docs: [https://docs.kontext.so/sdk/ios](https://docs.kontext.so/sdk/ios)

## License

KontextSwiftSDK is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

