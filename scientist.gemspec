load "lib/scientist/version.rb"

Gem::Specification.new do |gem|
  gem.name          = "scientist"
  gem.version       = Scientist::VERSION
  gem.authors       = ["John Barnette", "Rick Bradley"]
  gem.email         = ["jbarnette@github.com", "rick@github.com"]
  gem.summary       = "Carefully test, measure, and track refactored code."
  gem.homepage      = "https://github.com/github/scientist"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = []
  gem.test_files    = gem.files.grep(/^test/)
  gem.require_paths = ["lib"]

  gem.add_development_dependency "minitest", "~> 5.2.2"
  gem.add_development_dependency "mocha",    "~> 1.0.0"
end
