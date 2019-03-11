Pod::Spec.new do |s|

  s.name         = "JSONSchemaSwift"
  s.version      = "0.0.1"
  s.summary      = "A JSONSchema validation library for swift, supporting JSONSchema draft 7."
  s.description  = <<-DESC
  A JSON Schema validation library that supports JSONSchema draft 7.
                   DESC

  s.homepage     = "https://github.com/tribalworldwidelondon/JSONSchemaSwift"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Andy Best" => "andy.best@tribalworldwide.co.uk" }

  s.source       = { :git => "https://github.com/tribalworldwidelondon/JSONSchemaSwift.git", :tag => "#{s.version}" }

  s.source_files  = "Sources/**/*.swift"

end
