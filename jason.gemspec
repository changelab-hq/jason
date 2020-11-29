require_relative 'lib/jason/version'

Gem::Specification.new do |spec|
  spec.name          = "jason"
  spec.version       = Jason::VERSION
  spec.authors       = ["James Rees"]
  spec.email         = ["jarees@gmail.com"]

  spec.summary       = "Reactive user interfaces with minimal boilerplate, using Rails + Redux"
  spec.homepage      = "https://github.com/jamesr2323/jason"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jamesr2323/jason"
  spec.metadata["changelog_uri"] = "https://github.com/jamesr2323/jason"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
