# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pail/version'

Gem::Specification.new do |spec|
  spec.name          = "pail"
  spec.version       = Pail::VERSION
  spec.authors       = ["Eddie Johnston"]
  spec.email         = ["eddie@beanstalk.ie"]

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com' to prevent pushes to rubygems.org, or delete to allow pushes to any server."
  end

  spec.summary       = %q{Upload assets firectly to S3 using the Plupload JS Library}
  spec.description   = %q{When using a read-only file-system, it makes sense to upload assests directly to cloud storage. This gem makes it easy to upload directly to an S3 bucket using the Plupload JS Library. Callback functions can be triggered to run once files have finished uploading so that they can be processed by your application.}
  spec.homepage      = "https://github.com/eddiej/pail"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rails" ## for testing ::Rails::Engine
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "coveralls"
end
