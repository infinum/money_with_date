# frozen_string_literal: true

module MoneyWithDate
  class Hooks
    def self.init
      ::ActiveSupport.on_load(:active_record) do
        require "money_with_date/active_record/monetizable"

        ::ActiveRecord::Base.prepend(::MoneyWithDate::ActiveRecord::Monetizable)
      end
    end

    def self.init?
      money_rails_version = ::Gem::Version.new(::MoneyRails::VERSION)

      money_rails_version >= ::Gem::Version.new(::MoneyWithDate::MINIMUM_MONEY_RAILS_VERSION) &&
        money_rails_version <= ::Gem::Version.new(::MoneyWithDate::MAXIMUM_MONEY_RAILS_VERSION)
    end
  end
end
