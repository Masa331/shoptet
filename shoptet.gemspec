require_relative 'lib/shoptet'

Gem::Specification.new do |spec|
  spec.name          = 'shoptet'
  spec.version       = Shoptet.version
  spec.authors       = ['Premysl Donat']
  spec.email         = ['pdonat@seznam.cz']

  spec.summary       = 'API wrapper for interacting with Shoptet api'
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/Masa331/shoptet'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]

  spec.add_dependency 'oj'

  spec.add_development_dependency 'irb'
end
