# frozen_string_literal: true

module MoneyWithDate
  module InstanceMethods
    attr_reader :date

    def initialize(obj, currency = ::Money.default_currency, options = {})
      if options.is_a?(::Hash)
        @date = self.class.parse_date(options[:date])
      else
        @date = ::Money.default_date
      end

      raise ArgumentError, "#{@date.inspect} is not an instance of Date" unless @date.is_a?(::Date)

      super
    end

    def hash
      return super unless ::Money.date_determines_equality

      [fractional.hash, currency.hash, date.hash].hash # rubocop:disable Security/CompoundHash
    end

    def inspect
      "#<#{self.class.name} fractional:#{fractional} currency:#{currency} date:#{date}>"
    end

    def with_date(new_date)
      new_date = self.class.parse_date(new_date)

      if date == new_date
        self
      else
        dup_with(date: new_date)
      end
    end

    def dup_with(options = {})
      self.class.new(
        options[:fractional] || fractional,
        options[:currency] || currency,
        bank: options[:bank] || bank,
        date: options[:date] || date
      )
    end

    def eql?(other)
      return super unless ::Money.date_determines_equality

      if other.is_a?(::Money)
        (fractional == other.fractional && currency == other.currency && date == other.date) ||
          (fractional.zero? && other.fractional.zero?)
      else
        false
      end
    end

    def <=>(other) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      return super unless ::Money.date_determines_equality

      unless other.is_a?(::Money)
        return unless other.respond_to?(:zero?) && other.zero?

        return other.is_a?(::Money::Arithmetic::CoercedNumeric) ? 0 <=> fractional : fractional <=> 0
      end

      return fractional <=> other.fractional if zero? || other.zero?

      other = other.exchange_to(currency)
      [fractional, date] <=> [other.fractional, other.date]
    rescue ::Money::Bank::UnknownRate
      nil
    end
  end
end
