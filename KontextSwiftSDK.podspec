
Pod::Spec.new do |spec|
    spec.name                 = 'KontextSwiftSDK'
    spec.version              = '1.1.5'
    spec.summary              = 'Kontext.so Swift SDK'
    spec.description          = <<-DESC
    The official Swift SDK for integrating Kontext.so ads into your mobile application.
                                DESC
    spec.homepage             = 'https://github.com/kontextso/sdk-swift'
    # spec.homepage             = 'https://www.kontext.so'
    # spec.documentation_url    = 'https://docs.kontext.so/sdk/ios'
    spec.license              = { :type => 'Apache-2.0', :file => 'LICENSE' }
    spec.author               = { 'Kontext.so' => 'michal.stembera@gmail.com' }

    spec.swift_version        = '5.9'
    spec.platform             = :ios, '14.0'

    spec.source               = { :git => 'https://github.com/kontextso/sdk-swift.git', :tag => spec.version.to_s }
    spec.source_files         = 'Sources/**/*.swift'
    spec.frameworks           = ['UIKit', 'WebKit', 'SwiftUI']
end
