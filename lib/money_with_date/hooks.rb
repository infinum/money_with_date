# frozen_string_literal: true

module MoneyWithDate
  class Hooks
    def self.init
      ::ActiveSupport.on_load(:active_record) do
        require "money_with_date/active_record/monetizable"
        require "money_with_date/active_record/class_methods"

        ::ActiveRecord::Base.prepend(::MoneyWithDate::ActiveRecord::Monetizable)
        ::Money.singleton_class.prepend(::MoneyWithDate::ActiveRecord::ClassMethods)

        ::Money.default_date_column = :created_at
      end
    end

    def self.init?
      money_rails_version = ::Gem::Version.new(::MoneyRails::VERSION)

      money_rails_version >= ::Gem::Version.new(::MoneyWithDate::MINIMUM_MONEY_RAILS_VERSION) &&
        money_rails_version <= ::Gem::Version.new(::MoneyWithDate::MAXIMUM_MONEY_RAILS_VERSION)
    end
  end
end
