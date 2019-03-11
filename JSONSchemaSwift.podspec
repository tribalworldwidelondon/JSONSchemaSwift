Pod::Spec.new do |s|

  s.name         = "JSONSchemaSwift"
  s.version      = "0.0.1"
  s.summary      = "A JSONSchema validation library for swift, supporting JSONSchema draft 7."
  s.description  = <<-DESC
  A JSON Schema validation library that supports the majority of JSONSchema draft 7.
                   DESC

  s.homepage     = "https://github.com/tribalworldwidelondon/JSONSchemaSwift"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Andy Best" => "andy.best@tribalworldwide.co.uk" }

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.9'

  s.subspec 'JSONParser' do |jsonParser|
    jsonParser.source_files = "Sources/JSONParser/**/*.swift"
  end

  s.subspec 'Core' do |core|
    core.dependency 'JSONSchemaSwift/JSONParser'
    core.source_files = "Sources/JSONSchema/**/*.swift"
  end

  s.source       = { :git => "https://github.com/tribalworldwidelondon/JSONSchemaSwift.git", :tag => "#{s.version}" }
  s.swift_version = '4.2'

end
