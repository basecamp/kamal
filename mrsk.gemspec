require_relative "lib/mrsk/version"

Gem::Specification.new do |spec|
  spec.name        = "mrsk"
  spec.version     = Mrsk::VERSION
  spec.authors     = [ "David Heinemeier Hansson" ]
  spec.email       = "dhh@hey.com"
  spec.homepage    = "https://github.com/rails/mrsk"
  spec.summary     = "Deploy Docker containers with zero downtime to any host."
  spec.license     = "MIT"

  spec.files = Dir["lib/**/*", "MIT-LICENSE", "README.md"]

  spec.add_dependency "railties", ">= 7.0.0"
  spec.add_dependency "sshkit", "~> 1.21"
end
