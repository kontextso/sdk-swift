Pod::Spec.new do |spec|
    spec.name                 = 'KontextSwiftSDK'
    spec.version              = '4.0.0'
    spec.summary              = 'Kontext.so Swift SDK'
    spec.description          = <<-DESC
    The official Swift SDK for integrating Kontext.so ads into your iOS application.
                                DESC
    spec.homepage             = 'https://github.com/kontextso/sdk-swift'
    spec.license              = { :type => 'Apache-2.0', :file => 'LICENSE' }
    spec.author               = { 'Kontext.so' => 'support@kontext.so' }

    spec.swift_version        = '5.9'
    spec.platform             = :ios, '14.0'

    spec.source               = { :git => 'https://github.com/kontextso/sdk-swift.git', :tag => spec.version.to_s }
    spec.source_files         = 'Sources/KontextSwiftSDK/**/*.swift'
    spec.resource_bundles     = { 'KontextSwiftSDKPrivacy' => ['Sources/KontextSwiftSDK/PrivacyInfo.xcprivacy'] }

    # Pre-1.0 KontextKit: pin exact. Once KontextKit hits 1.0, switch to `~> 1.0`.
    spec.dependency 'KontextKit', '0.0.2'
end
