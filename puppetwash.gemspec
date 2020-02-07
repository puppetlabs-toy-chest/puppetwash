# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "puppetwash"
  spec.version       = "0.2.0"
  spec.authors       = ["Puppet"]
  spec.email         = ["puppet@puppet.com"]

  spec.summary       = "A Wash plugin for Puppet infrastructure"
  spec.description   = "A Wash plugin for examining Puppet infrastructure nodes such as PuppetDB, Puppet Server, and PE Classifier"
  spec.homepage      = "https://github.com/puppetlabs/puppetwash"
  spec.license       = "Apache-2.0"
  spec.files         = Dir["*.rb"]

  spec.required_ruby_version = "~> 2.3"

  spec.add_dependency "puppetdb-ruby", "~> 1.2"
  spec.add_dependency "wash", "~> 0.1"

  spec.add_development_dependency "pry", "~> 0.12"
  spec.add_development_dependency "ruby-debug-ide", "~> 0.7"
  spec.add_development_dependency "debase", "~> 0.2"
  spec.add_development_dependency "rcodetools", "~> 0.8"
end
