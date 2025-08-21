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
    .package(url: "https://github.com/kontextso/sdk-swift", .upToNextMajor(from: "1.0.0"))
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

Then you need to create `AdsProviderConfiguration` and `AdsProvider` scoped to one conversation. You can have multiple instances of AdsProvider if yo uhave multilpe conversations.

```swift
let configuration = AdsProviderConfiguration(
    publisherToken: "nexus-dev", 		// Your unique publisher token received from your account manager.
    userId: "<some id>", 				// A unique string that should remain the same during the user’s lifetime (used for retargeting and rewarded ads). Eg. uuid or hash of email address work well.
    conversationId: "<some id>",		// Unique ID of the conversation. This is mostly used for ad pacing. 
    enabledPlacementCodes: ["inlineAd"], // A list of placement codes that identify ad slots in your app. You receive them from your account manager.
    character: nil,						// Assistant's character information (if any)
    advertisingId: nil,					// IDFA or GAID (if available)
    vendorId: nil,						// IDFV (mostly used as fallback if IDFA is not available)
)

let adsProvider = AdsProvider(
	configuration: configuration, 		// Previously created configuration (it is immutable and publicly available if you need to refer to it later)
	sessionId: nil,						// ID of the session, will be nil for new chats, SDK will resolve it internally with first ads.
	isDisabled: false					// Flag whether the displaying of ads isDisabled
)

```

Adapt your message onject to provide necessary information for the ads recommendation to work. You have two options, either make them conform to `MessageRepresentable` to return respective properties or to `MessageRepresentableProviding` and return the `MessageRepresentable` as a whole new object. There is `struct AdsMessage: MessageRepresentable` which you can use for this scenario.

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

The last thing remaining is to provide place for the Ads to manifest into. This is done by placing `InlineAdView` into View hieararchy just after the associated message. It will stay empty until an ad linked to the respective message is retrieved.

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

For advanced usage, supported formats, and configuration details, see the docs: https://docs.kontext.so/sdk/ios

## License

KontextSwiftSDK is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

