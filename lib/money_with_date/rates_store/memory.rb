# frozen_string_literal: true

module MoneyWithDate
  module RatesStore
    class Memory < ::Money::RatesStore::Memory
      def add_rate(currency_iso_from, currency_iso_to, rate, date)
        guard.synchronize do
          date_key = date_key_for(date)
          rates[date_key] ||= {}
          rates[date_key][rate_key_for(currency_iso_from, currency_iso_to)] = rate
        end
      end

      def get_rate(currency_iso_from, currency_iso_to, date)
        guard.synchronize do
          rates.dig(date_key_for(date), rate_key_for(currency_iso_from, currency_iso_to))
        end
      end

      def each_rate
        return to_enum(:each_rate) unless block_given?

        guard.synchronize do
          rates.each do |date, date_rates|
            date_rates.each do |key, rate|
              iso_from, iso_to = key.split(INDEX_KEY_SEPARATOR)
              yield iso_from, iso_to, rate, date_for_key(date)
            end
          end
        end
      end

      private

      def date_key_for(date)
        date.to_date.to_s
      end

      def date_for_key(key)
        ::Date.parse(key)
      end
    end
  end
end
