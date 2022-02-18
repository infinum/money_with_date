# frozen_string_literal: true

require "money_with_date/hooks"
require "money-rails"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

MoneyRails::Hooks.init
MoneyWithDate::Hooks.init

RSpec.describe MoneyWithDate::ClassMethods do
  describe ".default_date_column / .default_date_column=" do
    around do |example|
      old_default_date_column = Money.default_date_column
      example.run
      Money.default_date_column = old_default_date_column
    end

    it "sets and retrieves the value" do
      expect do
        Money.default_date_column = :created_on
      end.to change(Money, :default_date_column).from(:created_at).to(:created_on)
    end
  end
end
