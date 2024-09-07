# frozen_string_literal: true

require_relative "lib/webcash/version"

Gem::Specification.new do |spec|
  spec.name = "webcash"
  spec.version = Webcash::VERSION
  spec.authors = [ "acidtib" ]
  spec.email = [ "hello@dainelvera.com" ]

  spec.summary = "TODO: Write a short summary, because RubyGems requires one."
  spec.description = "TODO: Write a longer description or delete this line."
  spec.homepage = "TODO: Put your gem's website or public repo URL here."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  # add dependencies
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "bigdecimal", "~> 3.1"
  spec.add_dependency "digest", "~> 3.1"
  spec.add_dependency "base64", "~> 0.2"
  spec.add_dependency "securerandom", "~> 0.3.1"
  spec.add_dependency "httparty", "~> 0.22"

  # Development dependencies
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-byebug'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
