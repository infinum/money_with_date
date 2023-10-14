# frozen_string_literal: true

module MoneyWithDate
  module Bank
    class VariableExchange < ::Money::Bank::VariableExchange
      def initialize(store = MoneyWithDate::RatesStore::Memory.new, &block)
        super
      end

      # rubocop:disable all
      def exchange_with(from, to_currency, &block)
        to_currency = ::Money::Currency.wrap(to_currency)
        if from.currency == to_currency
          from
        else
          if (rate = get_rate(from.currency, to_currency, from.date))
            fractional = calculate_fractional(from, to_currency)
            from.dup_with(
              fractional: exchange(fractional, rate, &block),
              currency: to_currency,
              bank: self
            )
          else
            raise ::Money::Bank::UnknownRate, "No conversion rate known for '#{from.currency.iso_code}' -> '#{to_currency}' on date #{from.date}"
          end
        end
      end
      # rubocop:enable all

      def add_rate(from, to, rate, date)
        set_rate(from, to, rate, date)
      end

      # rubocop:disable Metrics/AbcSize
      def set_rate(from, to, rate, date)
        if store.method(:add_rate).parameters.size == 3
          store.add_rate(::Money::Currency.wrap(from).iso_code, ::Money::Currency.wrap(to).iso_code, rate)
        else
          store.add_rate(::Money::Currency.wrap(from).iso_code, ::Money::Currency.wrap(to).iso_code, rate,
                         ::Money.parse_date(date))
        end
      end

      def get_rate(from, to, date)
        if store.method(:get_rate).parameters.size == 2
          store.get_rate(::Money::Currency.wrap(from).iso_code, ::Money::Currency.wrap(to).iso_code)
        else
          store.get_rate(::Money::Currency.wrap(from).iso_code, ::Money::Currency.wrap(to).iso_code,
                         ::Money.parse_date(date))
        end
      end
      # rubocop:enable Metrics/AbcSize

      def rates
        return super if store.method(:get_rate).parameters.size == 2

        store.each_rate.with_object({}) do |(from, to, rate, date), hash|
          hash[date.to_s] ||= {}
          hash[date.to_s][[from, to].join(SERIALIZER_SEPARATOR)] = rate
        end
      end

      def import_rates(format, s, opts = {}) # rubocop:disable all
        return super if store.method(:add_rate).parameters.size == 3

        raise Money::Bank::UnknownRateFormat unless RATE_FORMATS.include?(format)

        if format == :ruby
          warn "[WARNING] Using :ruby format when importing rates is potentially unsafe and " \
               "might lead to remote code execution via Marshal.load deserializer. Consider using " \
               "safe alternatives such as :json and :yaml."
        end

        store.transaction do
          data = FORMAT_SERIALIZERS[format].load(s)

          data.each do |date, rates|
            rates.each do |key, rate|
              from, to = key.split(SERIALIZER_SEPARATOR)
              add_rate(from, to, rate, date)
            end
          end
        end

        self
      end
    end
  end
end
