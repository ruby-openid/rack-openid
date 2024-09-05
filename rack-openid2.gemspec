# Get the GEMFILE_VERSION without *require* "my_gem/version", for code coverage accuracy
# See: https://github.com/simplecov-ruby/simplecov/issues/557#issuecomment-825171399
load "lib/rack/openid/version.rb"
gem_version = Rack::OpenID::Version::VERSION
Rack::OpenID::Version.send(:remove_const, :VERSION)

Gem::Specification.new do |spec|
  spec.name = "rack-openid2"
  spec.version = gem_version
  spec.summary = "Provides a more HTTPish API around the ruby-openid library"
  spec.authors = ["Peter Boling", "Michael Grosser", "Joshua Peek"]
  spec.email = "peter.boling@gmail.com"
  spec.homepage = "https://github.com/VitalConnectInc/#{spec.name}"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir[
    # Splats (alphabetical)
    "lib/**/*.rb",
    # Files (alphabetical)
    "LICENSE.txt",
    "README.md",
  ]

  spec.license = "MIT"
  cert = File.expand_path("~/.ssh/gem-private-key-grosser.pem")
  if File.exist?(cert)
    spec.signing_key = cert
    spec.cert_chain = ["gem-public_cert.pem"]
  end

  spec.add_dependency("rack", ">= 2.2")
  spec.add_dependency("ruby-openid2", ">= 3.0")
  spec.add_dependency("version_gem", "~> 1.1", ">= 1.1.4")

  # Testing
  spec.add_development_dependency("minitest", ">= 5")
  spec.add_development_dependency("minitest-rg", ">= 5")
  spec.add_development_dependency("rack-session", ">= 2")
  spec.add_development_dependency("rake", ">= 13")

  # Coverage
  spec.add_development_dependency("kettle-soup-cover", "~> 1.0", ">= 1.0.2")

  # Linting
  spec.add_development_dependency("rubocop-lts", "~> 18.2", ">= 18.2.1")
  spec.add_development_dependency("rubocop-minitest", "~> 0.36")
  spec.add_development_dependency("rubocop-packaging", "~> 0.5", ">= 0.5.2")
  spec.add_development_dependency("standard", ">= 1.35.1")

  # Documentation
  spec.add_development_dependency("yard", "~> 0.9", ">= 0.9.34")
  spec.add_development_dependency("yard-junk", "~> 0.0")
end
