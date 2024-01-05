# Get the GEMFILE_VERSION without *require* "my_gem/version", for code coverage accuracy
# See: https://github.com/simplecov-ruby/simplecov/issues/557#issuecomment-825171399
load "lib/omniauth/jwt/version.rb"
gem_version = Omniauth::JWT::Version::VERSION
Omniauth::JWT::Version.send(:remove_const, :VERSION)

Gem::Specification.new do |spec|
  spec.name          = "omniauth-jwt2"
  spec.version       = gem_version
  spec.authors       = ["Michael Bleigh", "Robin Ward", "Peter Boling"]
  spec.email         = ["mbleigh@mbleigh.com", "robin.ward@gmail.com", "peter.boling@gmail.com"]
  spec.description   = %q{An OmniAuth strategy to accept JWT-based single sign-on.}
  spec.summary       = %q{An OmniAuth strategy to accept JWT-based single sign-on.}
  spec.homepage      = "http://github.com/pboling/omniauth-jwt2"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.2"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # TODO: Since this gem supports Ruby >= 2.2 we need to ensure no gems are
  #       added here that require a newer version. Once this gem progresses to
  #       only support non-EOL Rubies, all dependencies can be listed in this
  #       gemspec, and the gemfiles/* pattern can be dispensed with.
  spec.add_dependency "jwt", "~> 2.2", ">= 2.2.1"                           # ruby 2.1
  spec.add_dependency "omniauth", ">= 1.1"                                  # ruby 2.2

  # Utilities
  spec.add_dependency "version_gem", "~> 1.1", ">= 1.1.3"                   # ruby 2.2
  spec.add_development_dependency "rake", "~> 13.0"                         # ruby 2.2, v13.1 is >= 2.3

  # Hot reload
  spec.add_development_dependency "guard"                                   # ruby 1.9.3
  spec.add_development_dependency "guard-rspec"                             # ruby *

  # Testing
  spec.add_development_dependency "rspec", "~> 3.12"                        # ruby *
  spec.add_development_dependency "rack-test", "~> 2.1"                     # ruby 2.0
  spec.add_development_dependency "rspec-pending_for", "~> 0.1"             # ruby *
end
