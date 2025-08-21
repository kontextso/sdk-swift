
Pod::Spec.new do |spec|
  spec.name                 = "KontextSwiftSDK"
  spec.version              = "1.0.0"
  spec.summary              = "The official Swift SDK for integrating Kontext.so ads into your mobile application."
  spec.homepage             = "https://www.kontext.so/"
  spec.documentation_url    = "https://docs.kontext.so/sdk/ios"
  spec.license              = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  spec.author               = { "Kontext.so" => "michal.stembera@gmail.com" }
  spec.swift_versions       = ["5.9", "6.0", "6.1", "6.2"]
  spec.platform             = :ios, "14.0"
  spec.source               = { :git => "https://github.com/kontextso/sdk-swift.git", :tag => spec.version.to_s }
  spec.source_files         = "Sources/**/*.swift"
  spec.frameworks           = ["UIKit", "WebKit", "SwiftUI"]
end
