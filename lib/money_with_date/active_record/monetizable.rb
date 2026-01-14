# frozen_string_literal: true

module MoneyWithDate
  module ActiveRecord
    module Monetizable
      # :nocov:
      # see https://github.com/RubyMoney/money-rails/pull/670/changes
      if ::Gem::Version.new(::MoneyRails::VERSION) >= ::Gem::Version.new("2.0.0")
        def read_monetized(name, subunit_name, options = {}, *args, **kwargs)
          money = super
          date = find_date_for(options[:with_model_date], options[:with_date])

          if money&.date == date
            money
          else
            instance_variable_set("@#{name}", money&.with_date(date))
          end
        end
      else
        def read_monetized(name, subunit_name, options = {}, *args)
          money = super
          date = find_date_for(options[:with_model_date], options[:with_date])

          if money&.date == date
            money
          else
            instance_variable_set("@#{name}", money&.with_date(date))
          end
        end
      end
      # :nocov:

      private

      def find_date_for(instance_date_name, field_date_name) # rubocop:disable Metrics/MethodLength
        if instance_date_name && respond_to?(instance_date_name)
          public_send(instance_date_name)
        elsif field_date_name.respond_to?(:call)
          field_date_name.call(self)
        elsif field_date_name
          field_date_name
        elsif ::Money.default_date_column && respond_to?(::Money.default_date_column)
          public_send(::Money.default_date_column)
        else
          ::Money.default_date
        end
      end
    end
  end
end
