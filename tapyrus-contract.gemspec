require_relative 'lib/tapyrus/contract/version'

Gem::Specification.new do |spec|
  spec.name          = "tapyrus-contract"
  spec.version       = Tapyrus::Contract::VERSION
  spec.authors       = ["azuchi"]
  spec.email         = ["azuchi@chaintope.com"]

  spec.summary       = %q{A Ruby library of smart contracts that can be used on Tapyrus.}
  spec.description   = %q{A Ruby library of smart contracts that can be used on Tapyrus.}
  spec.homepage      = "https://github.com/chaintope/tapyrus-contractrb"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")


  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/chaintope/tapyrus-contractrb"
  spec.metadata["changelog_uri"] = "https://github.com/chaintope/tapyrus-contractrb"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'tapyrus'
  spec.add_development_dependency 'rails'
  spec.add_development_dependency 'rspec-rails'
end
