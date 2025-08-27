//
//  AdsProviderConfiguration.swift
//  KontextSwiftSDK
//

import Foundation

/// Configuration for the AdsProvider.
///
/// - Publicly available later so no need to keep it around.
/// - Cannot be reused for another chat conversation, because it is scoped by conversationId.
public struct AdsProviderConfiguration: Sendable {
    /// Unique publisher token received from your account manager.
    ///
    /// This token is not a secret.
    ///
    /// Publishers typically use two types of tokens:
    /// - Developer token: `{publisher}-dev` (for testing)
    /// - Production token**:** `{publisher}-{unique string}`
    public let publisherToken: String
    /// A unique string that should remain the same during the user’s lifetime (used for retargeting and rewarded ads)
    public let userId: String
    /// Unique ID of the conversation. It is mostly used for pacing.
    ///
    /// Represents the entire conversation between the user and the assistant. For example, in apps like ChatGPT,
    /// every new chat thread has a unique conversationId. This ID remains the same even
    /// if the user refreshes the page or returns to the same conversation later.
    public let conversationId: String
    /// Assistant's character information (if any)
    public let character: Character?
    /// A list of placement codes that identify ad slots in your app. You receive them from your account manager.
    public let enabledPlacementCodes: [String]
    /// String provided by the publisher to identify the user cohort in order to compare A/B test groups.
    public let variantId: String?
    /// Device-specific identifier provided by the operating systems (IDFA).
    ///
    /// - ASIdentifierManager.advertisingIdentifier, avoid using other identifiers like UUID.
    /// - More at: https://developer.apple.com/documentation/adsupport/asidentifiermanager/advertisingidentifier
    public let advertisingId: String?
    /// An alphanumeric string that uniquely identifies a device to the app’s vendor. (IDFV).
    ///
    /// - Mostly used as fallback when advertisingId is not available.
    /// - UIDevice.current.identifierForVendor?.uuidString, avoid using other identifiers like UUID.
    /// - More at: https://developer.apple.com/documentation/uikit/uidevice/identifierforvendor
    public let vendorId: String?
    /// URL of the server from which the ads are served.
    /// Defaults to https://server.megabrain.co/
    public let adServerUrl: URL
    /// Information about regulatory requirements that apply.
    public let regulatory: Regulatory?

    /// Initializes a new AdsProviderConfiguration to be later passed to the AdsProvider.
    ///
    /// - Parameters:
    ///     - publisherToken: Unique publisher token received from your account manager.
    ///     - userId: A unique string that should remain the same during the user’s lifetime (used for retargeting and rewarded ads).
    ///     - conversationId: Unique ID of the conversation. It is mostly used for pacing.
    ///     - enabledPlacementCodes: A list of placement codes that identify ad slots in your app. You receive them from your account manager.
    ///     - character: Assistant's character information (if any).
    ///     - variantId: String provided by the publisher to identify the user cohort in order to compare A/B test groups.
    ///     - advertisingId: Device-specific identifier provided by the operating systems (IDFA).
    ///     - vendorId: Vendor-specific identifier provided by the operating systems (IDFV).
    ///     - adServerUrl: URL of the server from which the ads are served. Defaults to https://server.megabrain.co/
    ///     - regulatory: Information about regulatory requirements that apply.
    public init(
        publisherToken: String,
        userId: String,
        conversationId: String,
        enabledPlacementCodes: [String],
        character: Character? = nil,
        variantId: String? = nil,
        advertisingId: String? = nil,
        vendorId: String? = nil,
        adServerUrl: URL? = nil,
        regulatory: Regulatory? = nil
    ) {
        self.publisherToken = publisherToken
        self.userId = userId
        self.conversationId = conversationId
        self.character = character
        self.enabledPlacementCodes = enabledPlacementCodes
        self.variantId = variantId
        self.advertisingId = advertisingId
        self.vendorId = vendorId
        self.adServerUrl = adServerUrl ?? SDKInfo.defaultAdServerURL
        self.regulatory = regulatory

    }
}
