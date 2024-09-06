# frozen_string_literal: true

require_relative "lib/money_with_date/version"

Gem::Specification.new do |spec|
  spec.name = "money_with_date"
  spec.version = MoneyWithDate::VERSION
  spec.authors = ["Lovro Bikić"]
  spec.email = ["lovro.bikic@gmail.com"]

  spec.summary = "Extension for the money gem which adds dates to Money objects"
  spec.homepage = "https://github.com/infinum/money_with_date"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "money", ">= #{MoneyWithDate::MINIMUM_MONEY_VERSION}", "<= #{MoneyWithDate::MAXIMUM_MONEY_VERSION}" # rubocop:disable Layout/LineLength

  # rubocop:disable Gemspec/DevelopmentDependencies
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-rspec"
  # rubocop:enable all
end
