$: << "lib" and require "scientist/version"

Gem::Specification.new do |gem|
  gem.name          = "scientist"
  gem.description   = "A Ruby library for carefully refactoring critical paths"
  gem.version       = Scientist::VERSION
  gem.authors       = ["GitHub Open Source", "John Barnette", "Rick Bradley"]
  gem.email         = ["opensource+scientist@github.com", "jbarnette@github.com", "rick@rickbradley.com"]
  gem.summary       = "Carefully test, measure, and track refactored code."
  gem.homepage      = "https://github.com/github/scientist"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = []
  gem.test_files    = gem.files.grep(/^test/)
  gem.require_paths = ["lib"]

  gem.add_development_dependency "minitest", "~> 5.2"
end
