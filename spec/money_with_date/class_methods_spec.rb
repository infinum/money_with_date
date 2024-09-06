# frozen_string_literal: true

RSpec.describe MoneyWithDate::ClassMethods do
  describe ".default_date / .default_date=" do
    around(:each) do |example|
      old_default_date = Money.default_date
      example.run
      Money.default_date = old_default_date
    end

    context "when default date is a callable" do
      before do
        Money.default_date = -> { Date.today - 5 }
      end

      it "resolves the callable" do
        expect(Money.default_date).to eq(Date.today - 5)
      end
    end

    context "when default date is static" do
      let(:value) { Date.today - 5 }

      before do
        Money.default_date = value
      end

      it "returns that value" do
        expect(Money.default_date).to eq(value)
        expect(Money.default_date.object_id).to eq(value.object_id)
      end
    end
  end

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

  describe ".add_rate" do
    around(:each) do |example|
      old_default_bank = Money.default_bank
      example.run
      Money.default_bank = old_default_bank
    end

    context "when bank object doesn't accept a date param" do
      before do
        Money.default_bank = Money::Bank::VariableExchange.new(Money::RatesStore::Memory.new)
      end

      it "doesn't forward date to the bank" do
        Money.add_rate "USD", "EUR", 0.9, Date.today
        Money.add_rate "USD", "EUR", 0.8, Date.today - 1

        expect(Money.default_bank.get_rate("USD", "EUR")).to eq(0.8)
      end
    end

    context "when bank object accepts a date param" do
      context "when store object accepts a date param" do
        before do
          Money.default_bank = MoneyWithDate::Bank::VariableExchange.new(MoneyWithDate::RatesStore::Memory.new)
        end

        it "saves the rate with the date param" do
          Money.add_rate "USD", "EUR", 0.9, Date.today
          Money.add_rate "USD", "EUR", 0.8, Date.today - 1

          expect(Money.default_bank.get_rate("USD", "EUR", Date.today)).to eq(0.9)
          expect(Money.default_bank.get_rate("USD", "EUR", Date.today - 1)).to eq(0.8)
        end
      end

      context "when store object doesn't accept a date param" do
        before do
          Money.default_bank = MoneyWithDate::Bank::VariableExchange.new(Money::RatesStore::Memory.new)
        end

        it "saves the rate without date" do
          Money.add_rate "USD", "EUR", 0.9, Date.today
          Money.add_rate "USD", "EUR", 0.8, Date.today - 1

          expect(Money.default_bank.get_rate("USD", "EUR", Date.today)).to eq(0.8)
          expect(Money.default_bank.get_rate("USD", "EUR", Date.today - 1)).to eq(0.8)
        end
      end
    end
  end
end
