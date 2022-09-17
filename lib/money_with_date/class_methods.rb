# frozen_string_literal: true

module MoneyWithDate
  module ClassMethods
    attr_accessor :date_determines_equality
    attr_accessor :default_date_column

    attr_writer :default_date

    def default_date
      if @default_date.respond_to?(:call)
        @default_date.call
      else
        @default_date
      end
    end

    def add_rate(from_currency, to_currency, rate, date = ::Money.default_date)
      if ::Money.default_bank.method(:add_rate).parameters.size == 3
        ::Money.default_bank.add_rate(from_currency, to_currency, rate)
      else
        ::Money.default_bank.add_rate(from_currency, to_currency, rate, date)
      end
    end

    def parse_date(date)
      return ::Money.default_date unless date
      return date.to_date if date.respond_to?(:to_date)

      ::Date.parse(date)
    rescue ArgumentError, TypeError, ::Date::Error # rubocop:disable Lint/ShadowedException
      raise ArgumentError, "#{date.inspect} cannot be parsed as Date"
    end
  end
end
