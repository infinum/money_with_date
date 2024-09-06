# frozen_string_literal: true

RSpec.describe MoneyWithDate::Bank::VariableExchange do
  let(:date_dependent_store) { MoneyWithDate::RatesStore::Memory.new }
  let(:date_independent_store) { Money::RatesStore::Memory.new }

  describe "#initialize" do
    context "without &block" do
      it "defaults to Memory store" do
        expect(described_class.new.store).to be_a(MoneyWithDate::RatesStore::Memory)
      end
    end

    context "with &block" do
      let(:bank) do
        proc = proc(&:ceil)
        described_class.new(&proc).tap do |bank|
          bank.add_rate("USD", "EUR", 1.33, Date.today)
        end
      end

      describe "#exchange_with" do
        it "uses the stored truncation method" do
          expect(bank.exchange_with(Money.new(10, "USD"), "EUR")).to eq(Money.new(14, "EUR"))
        end

        it "accepts a custom truncation method" do
          proc = proc { |n| n.ceil + 1 }

          expect(bank.exchange_with(Money.new(10, "USD"), "EUR", &proc)).to eq(Money.new(15, "EUR"))
        end
      end
    end
  end

  describe "#set_rate / #get_rate" do
    context "when store accepts a date param" do
      subject(:bank) { described_class.new(date_dependent_store) }

      it "sets and gets exchange rates by date" do
        bank.set_rate "USD", "EUR", 0.9, Date.today
        bank.set_rate "USD", "EUR", 0.95, Date.today + 1

        expect(bank.get_rate("USD", "EUR", Date.today)).to eq(0.9)
        expect(bank.get_rate("USD", "EUR", Date.today + 1)).to eq(0.95)
      end

      it "parses the date" do
        bank.set_rate "USD", "EUR", 0.9, "2020-01-01"
        bank.set_rate "USD", "EUR", 0.95, "2020-01-02"

        expect(bank.get_rate("USD", "EUR", Date.parse("2020-01-01"))).to eq(0.9)
      end

      it "raises an error if date isn't supplied" do
        expect do
          bank.set_rate "USD", "EUR", 0.9
        end.to raise_error(ArgumentError).with_message("wrong number of arguments (given 3, expected 4)")

        expect do
          bank.get_rate "USD", "EUR"
        end.to raise_error(ArgumentError).with_message("wrong number of arguments (given 2, expected 3)")
      end
    end

    context "when store doesn't accept a date param" do
      subject(:bank) { described_class.new(date_independent_store) }

      it "sets and gets exchange rates but doesn't save the date" do
        bank.set_rate "USD", "EUR", 0.9, Date.today
        bank.set_rate "USD", "EUR", 0.95, Date.today + 1

        expect(bank.get_rate("USD", "EUR", Date.today)).to eq(0.95)
        expect(bank.get_rate("USD", "EUR", Date.today + 1)).to eq(0.95)
      end
    end
  end

  describe "#add_rate" do
    context "when store accepts a date param" do
      subject(:bank) { described_class.new(date_dependent_store) }

      it "delegates to store#set_rate with the date" do
        expect(bank.add_rate("USD", "EUR", 1.25, Date.today)).to eq(1.25)
        expect(bank.add_rate("USD", "EUR", 1.3, Date.today + 1)).to eq(1.3)

        expect(bank.get_rate("USD", "EUR", Date.today)).to eq(1.25)
      end
    end

    context "when store doesn't accept a date param" do
      subject(:bank) { described_class.new(date_independent_store) }

      it "delegates to store#set_rate without the date" do
        expect(bank.add_rate("USD", "EUR", 1.25, Date.today)).to eq(1.25)
        expect(bank.add_rate("USD", "EUR", 1.3, Date.today + 1)).to eq(1.3)

        expect(bank.get_rate("USD", "EUR", Date.today)).to eq(1.3)
      end
    end
  end

  describe "#exchange_with" do
    subject(:bank) { described_class.new(date_dependent_store) }

    before do
      bank.add_rate "USD", "EUR", 1.33, Date.today
      bank.add_rate "USD", "EUR", 1.4, Date.today + 1
    end

    it "exchanges one currency to another with the correct date" do
      money = Money.new(100, :usd, date: Date.today)

      exchanged_money = bank.exchange_with(money, :eur)

      expect(exchanged_money).to eq(Money.new(133, :eur))
      expect(exchanged_money.date).to eq(Date.today)
    end

    it "returns the same money object if exchanging to same currency" do
      money = Money.new(100, :usd, date: Date.today)

      exchanged_money = bank.exchange_with(money, :usd)

      expect(exchanged_money).to eq(money)
    end

    it "raises an error if an exchange rate doesn't exist for the given date" do
      money = Money.new(100, :usd, date: "2020-01-01")
      error_message = "No conversion rate known for 'USD' -> 'EUR' on date 2020-01-01"

      expect do
        bank.exchange_with(money, :eur)
      end.to raise_error(Money::Bank::UnknownRate).with_message(error_message)
    end

    it "raises an error if an exchange rate doesn't exist at all" do
      money = Money.new(100, :usd, date: "2020-01-01")

      expect do
        bank.exchange_with(money, :bbb)
      end.to raise_error(Money::Currency::UnknownCurrency).with_message("Unknown currency 'bbb'")
    end

    it "accepts a custom truncation method" do
      money = Money.new(10, :usd, date: Date.today)
      proc = proc(&:ceil)

      exchanged_money = bank.exchange_with(money, :eur, &proc)

      expect(exchanged_money).to eq(Money.new(14, :eur))
    end

    it "preserves the class in the result when given a subclass of Money" do
      special_money_class = Class.new(Money)
      special_money = special_money_class.new(100, :usd, date: Date.today)

      expect(bank.exchange_with(special_money, :eur)).to be_a(special_money_class)
    end
  end

  describe "#export_rates" do
    context "when store accepts a date param" do
      subject(:bank) { described_class.new(date_dependent_store) }

      let(:rates) { { Date.today.to_s => { "USD_TO_EUR" => 1.25, "USD_TO_JPY" => 2.55 } } }

      before :each do
        subject.set_rate("USD", "EUR", 1.25, Date.today)
        subject.set_rate("USD", "JPY", 2.55, Date.today)
      end

      context "with format == :json" do
        it "should return rates formatted as json" do
          json = subject.export_rates(:json)

          expect(JSON.parse(json)).to eq(rates)
        end
      end

      context "with format == :ruby" do
        it "should return rates formatted as ruby objects" do
          marshal = subject.export_rates(:ruby)

          expect(Marshal.load(marshal)).to eq(rates) # rubocop:disable Security/MarshalLoad
        end
      end

      context "with format == :yaml" do
        it "should return rates formatted as yaml" do
          yaml = subject.export_rates(:yaml)

          expect(YAML.safe_load(yaml)).to eq(rates)
        end
      end

      context "with unknown format" do
        it "raises Money::Bank::UnknownRateFormat" do
          expect do
            subject.export_rates(:foo)
          end.to raise_error(Money::Bank::UnknownRateFormat)
        end
      end

      context "with :file provided" do
        it "writes rates to file" do
          f = double("IO")
          expect(File).to receive(:open).with("null", "w").and_yield(f)
          expect(f).to receive(:write).with(JSON.dump(rates))

          subject.export_rates(:json, "null")
        end
      end

      it "delegates execution to store, options are a no-op" do
        expect(subject.store).to receive(:transaction)

        subject.export_rates(:yaml, nil, foo: 1)
      end
    end

    context "when store doesn't a date param" do
      subject(:bank) { described_class.new(date_independent_store) }

      let(:rates) { { "USD_TO_EUR" => 1.25, "USD_TO_JPY" => 2.55 } }

      before :each do
        subject.set_rate("USD", "EUR", 1.25, Date.today)
        subject.set_rate("USD", "JPY", 2.55, Date.today)
      end

      context "with format == :json" do
        it "should return rates formatted as json" do
          json = subject.export_rates(:json)

          expect(JSON.parse(json)).to eq(rates)
        end
      end

      context "with format == :ruby" do
        it "should return rates formatted as ruby objects" do
          marshal = subject.export_rates(:ruby)

          expect(Marshal.load(marshal)).to eq(rates) # rubocop:disable Security/MarshalLoad
        end
      end

      context "with format == :yaml" do
        it "should return rates formatted as yaml" do
          yaml = subject.export_rates(:yaml)

          expect(YAML.safe_load(yaml)).to eq(rates)
        end
      end

      context "with unknown format" do
        it "raises Money::Bank::UnknownRateFormat" do
          expect do
            subject.export_rates(:foo)
          end.to raise_error(Money::Bank::UnknownRateFormat)
        end
      end

      context "with :file provided" do
        it "writes rates to file" do
          f = double("IO")
          expect(File).to receive(:open).with("null", "w").and_yield(f)
          expect(f).to receive(:write).with(JSON.dump(rates))

          subject.export_rates(:json, "null")
        end
      end

      it "delegates execution to store, options are a no-op" do
        expect(subject.store).to receive(:transaction)

        subject.export_rates(:yaml, nil, foo: 1)
      end
    end
  end

  describe "#import_rates" do
    context "when store accepts a date param" do
      subject(:bank) { described_class.new(date_dependent_store) }

      context "with format == :json" do
        let(:dump) { JSON.dump({ "2020-01-01" => { "USD_TO_EUR" => 1.25, "USD_TO_JPY" => 2.55 } }) }

        it "loads the rates provided" do
          subject.import_rates(:json, dump)

          expect(subject.get_rate("USD", "EUR", Date.parse("2020-01-01"))).to eq(1.25)
          expect(subject.get_rate("USD", "JPY", Date.parse("2020-01-01"))).to eq(2.55)
        end
      end

      context "with format == :ruby" do
        let(:dump) { Marshal.dump({ "2020-01-01" => { "USD_TO_EUR" => 1.25, "USD_TO_JPY" => 2.55 } }) }

        it "loads the rates provided" do
          subject.import_rates(:ruby, dump)

          expect(subject.get_rate("USD", "EUR", Date.parse("2020-01-01"))).to eq(1.25)
          expect(subject.get_rate("USD", "JPY", Date.parse("2020-01-01"))).to eq(2.55)
        end

        it "prints a warning" do
          allow(subject).to receive(:warn)

          subject.import_rates(:ruby, dump)

          expect(subject)
            .to have_received(:warn)
            .with(include("[WARNING] Using :ruby format when importing rates is potentially unsafe"))
        end
      end

      context "with format == :yaml" do
        let(:dump) { "---\n'2020-01-01':\n  USD_TO_EUR: 1.25\n  USD_TO_JPY: 2.55\n" }

        it "loads the rates provided" do
          subject.import_rates(:yaml, dump)

          expect(subject.get_rate("USD", "EUR", Date.parse("2020-01-01"))).to eq(1.25)
          expect(subject.get_rate("USD", "JPY", Date.parse("2020-01-01"))).to eq(2.55)
        end
      end

      context "with unknown format" do
        it "raises Money::Bank::UnknownRateFormat" do
          expect do
            subject.import_rates(:foo, "")
          end.to raise_error Money::Bank::UnknownRateFormat
        end
      end

      it "delegates execution to store#transaction" do
        dump = "---\n'2020-01-01':\n  USD_TO_EUR: 1.25\n  USD_TO_JPY: 2.55\n"

        expect(subject.store).to receive(:transaction)

        subject.import_rates(:yaml, dump, foo: 1)
      end
    end

    context "when store doesn't accept a date param" do
      subject(:bank) { described_class.new(date_independent_store) }

      context "with format == :json" do
        let(:dump) { JSON.dump({ "USD_TO_EUR" => 1.25, "USD_TO_JPY" => 2.55 }) }

        it "loads the rates provided" do
          subject.import_rates(:json, dump)

          expect(subject.get_rate("USD", "EUR", Date.parse("2020-01-01"))).to eq(1.25)
          expect(subject.get_rate("USD", "JPY", Date.parse("2020-01-01"))).to eq(2.55)
        end
      end

      context "with format == :ruby" do
        let(:dump) { Marshal.dump({ "USD_TO_EUR" => 1.25, "USD_TO_JPY" => 2.55 }) }

        it "loads the rates provided" do
          subject.import_rates(:ruby, dump)

          expect(subject.get_rate("USD", "EUR", Date.parse("2020-01-01"))).to eq(1.25)
          expect(subject.get_rate("USD", "JPY", Date.parse("2020-01-01"))).to eq(2.55)
        end

        it "prints a warning" do
          allow(subject).to receive(:warn)

          subject.import_rates(:ruby, dump)

          expect(subject)
            .to have_received(:warn)
            .with(include("[WARNING] Using :ruby format when importing rates is potentially unsafe"))
        end
      end

      context "with format == :yaml" do
        let(:dump) { "--- \nUSD_TO_EUR: 1.25\nUSD_TO_JPY: 2.55\n" }

        it "loads the rates provided" do
          subject.import_rates(:yaml, dump)

          expect(subject.get_rate("USD", "EUR", Date.parse("2020-01-01"))).to eq(1.25)
          expect(subject.get_rate("USD", "JPY", Date.parse("2020-01-01"))).to eq(2.55)
        end
      end

      context "with unknown format" do
        it "raises Money::Bank::UnknownRateFormat" do
          expect do
            subject.import_rates(:foo, "")
          end.to raise_error Money::Bank::UnknownRateFormat
        end
      end

      it "delegates execution to store#transaction" do
        dump = "---\n'2020-01-01':\n  USD_TO_EUR: 1.25\n  USD_TO_JPY: 2.55\n"

        expect(subject.store).to receive(:transaction)

        subject.import_rates(:yaml, dump, foo: 1)
      end
    end
  end

  describe "#marshal_dump" do
    subject(:bank) { described_class.new(date_dependent_store) }

    it "does not raise an error" do
      expect do
        Marshal.dump(subject)
      end.to_not raise_error
    end

    it "works with Marshal.load" do
      bank = Marshal.load(Marshal.dump(subject))

      expect(bank.rates).to eq(subject.rates)
      expect(bank.rounding_method).to eq(subject.rounding_method)
    end
  end
end
