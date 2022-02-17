# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec:unit rubocop]

namespace :spec do # rubocop:disable Metrics/BlockLength
  task :unit, [:money, :money_rails, :rails] do |_, args|
    args.with_defaults(money: "6.16.0", money_rails: "1.15.0", rails: "7.0.2.2")

    ENV["MONEY_VERSION"] = args.money
    ENV["MONEY_RAILS_VERSION"] = args.money_rails
    ENV["RAILS_VERSION"] = args.rails

    sh 'echo "Running unit tests on money $MONEY_VERSION, money-rails $MONEY_RAILS_VERSION, rails $RAILS_VERSION"',
       verbose: false
    Rake::Task["prepare_env"].invoke
    sh "bundle exec rspec", verbose: false
  end

  task :money, [:money] do |_, args|
    args.with_defaults(money: "6.16.0")

    ENV["MONEY_VERSION"] = args.money

    sh 'echo "Running money regressions tests on money $MONEY_VERSION"', verbose: false
    Rake::Task["prepare_env"].invoke
    sh "bin/prepare_money_specs", verbose: false
    sh "bundle exec rspec --default-path spec_money", verbose: false
  end

  task :money_rails, [:money_rails] do |_, args|
    args.with_defaults(money_rails: "1.15.0")

    ENV["MONEY_RAILS_VERSION"] = args.money_rails

    sh 'echo "Running money-rails regressions tests on money-rails $MONEY_RAILS_VERSION"', verbose: false
    Rake::Task["prepare_env"].invoke
    sh "bin/prepare_money_rails_specs", verbose: false

    Bundler.with_original_env do
      Dir.chdir("spec_money_rails") do
        sh "BUNDLE_GEMFILE='' bundle install", verbose: false
        sh "BUNDLE_GEMFILE='' bundle exec rake spec:all", verbose: false
      end
    end
  end
end

task :prepare_env do
  sh "export BUNDLE_GEMFILE=Gemfile_test", verbose: false
  sh "rm -f Gemfile_test.lock", verbose: false
  sh "bundle install", verbose: false
end
