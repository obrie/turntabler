$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'turntabler/version'

Gem::Specification.new do |s|
  s.name              = "turntabler"
  s.version           = Turntabler::Version::STRING
  s.authors           = ["Aaron Pfeifer"]
  s.email             = "aaron.pfeifer@gmail.com"
  s.homepage          = "http://github.com/obrie/turntabler"
  s.description       = "Turntable.FM API for Ruby"
  s.summary           = "Turntable.FM API for Ruby"
  s.require_paths     = ["lib"]
  s.files             = `git ls-files`.split("\n")
  s.test_files        = `git ls-files -- test/*`.split("\n")
  s.rdoc_options      = %w(--line-numbers --inline-source --title turntabler --main README.md)
  s.extra_rdoc_files  = %w(README.md CHANGELOG.md LICENSE)

  s.add_runtime_dependency("em-synchrony")
  s.add_runtime_dependency("em-http-request")
  s.add_runtime_dependency("faye-websocket")
  s.add_development_dependency("rake")
  s.add_development_dependency("rspec", "~> 2.11")
  s.add_development_dependency("simplecov")
end
