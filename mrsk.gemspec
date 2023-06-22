require_relative "lib/mrsk/version"

Gem::Specification.new do |spec|
  spec.name        = "mrsk"
  spec.version     = Mrsk::VERSION
  spec.authors     = [ "David Heinemeier Hansson" ]
  spec.email       = "dhh@hey.com"
  spec.homepage    = "https://github.com/rails/mrsk"
  spec.summary     = "Deploy web apps in containers to servers running Docker with zero downtime."
  spec.license     = "MIT"

  spec.files = Dir["lib/**/*", "MIT-LICENSE", "README.md"]
  spec.executables = %w[ mrsk ]

  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "sshkit", "~> 1.21"
  spec.add_dependency "net-ssh", "~> 7.0"
  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "dotenv", "~> 2.8"
  spec.add_dependency "zeitwerk", "~> 2.5"
  spec.add_dependency "ed25519", "~> 1.2"
  spec.add_dependency "bcrypt_pbkdf", "~> 1.0"
  spec.add_dependency "concurrent-ruby", "~> 1.2"

  spec.add_development_dependency "debug"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "railties"
end
