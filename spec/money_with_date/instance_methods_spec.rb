# frozen_string_literal: true

RSpec.describe MoneyWithDate::InstanceMethods do
  describe "#initialize" do
    context "without date param" do
      it "sets the default date" do
        money = Money.new(20)

        expect(money.date).to eq(Date.today)
      end
    end

    context "without date param but unparseable default date" do
      around do |example|
        old_default_date = Money.default_date
        example.run
        Money.default_date = old_default_date
      end

      it "raises an ArgumentError" do
        Money.default_date = -> { "not a date" }

        expect do
          Money.new(20)
        end.to raise_error(ArgumentError).with_message('"not a date" is not an instance of Date')
      end
    end

    context "with nil date param" do
      it "sets the default date" do
        money = Money.new(20, :usd, date: nil)

        expect(money.date).to eq(Date.today)
      end
    end

    context "with Time date param" do
      it "converts it to date" do
        money = Money.new(20, :usd, date: Time.new(2020, 1, 1, 20, 30, 30))

        expect(money.date).to eq(Date.new(2020, 1, 1))
      end
    end

    context "with parseable string date param" do
      it "converts it to date" do
        money = Money.new(20, :usd, date: "2020-01-01")

        expect(money.date).to eq(Date.new(2020, 1, 1))
      end
    end

    context "with unparseable string date param" do
      it "raises an argument error" do
        expect do
          Money.new(20, :usd, date: "not a date")
        end.to raise_error(ArgumentError).with_message('"not a date" cannot be parsed as Date')
      end
    end

    context "with numeric date param" do
      it "raises an argument error" do
        expect do
          Money.new(20, :usd, date: 20)
        end.to raise_error(ArgumentError).with_message("20 cannot be parsed as Date")
      end
    end

    context "with positional bank param" do
      it "sets the default date" do
        money = Money.new(20, :usd, Money::Bank::VariableExchange.new)

        expect(money.date).to eq(Money.default_date)
      end
    end
  end

  describe "#hash" do
    context "by default" do
      it "is equal if the dates are equal" do
        first_money = Money.new(20, :usd, date: Date.today)
        second_money = Money.new(20, :usd, date: Date.today)

        expect(first_money.hash).to eq(second_money.hash)
      end

      it "is equal if the dates are different" do
        first_money = Money.new(20, :usd, date: Date.today)
        second_money = Money.new(20, :usd, date: Date.today - 1)

        expect(first_money.hash).to eq(second_money.hash)
      end
    end

    context "when Money.date_determines_equality is true" do
      around do |example|
        Money.date_determines_equality = true
        example.run
        Money.date_determines_equality = false
      end

      it "is equal if the dates are equal" do
        first_money = Money.new(20, :usd, date: Date.today)
        second_money = Money.new(20, :usd, date: Date.today)

        expect(first_money.hash).to eq(second_money.hash)
      end

      it "changes if the dates are different" do
        first_money = Money.new(20, :usd, date: Date.today)
        second_money = Money.new(20, :usd, date: Date.today - 1)

        expect(first_money.hash).not_to eq(second_money.hash)
      end
    end
  end

  describe "#inspect" do
    it "outputs date along with other variables" do
      money = Money.new(20, :usd, date: Date.parse("2020-01-01"))

      expect(money.inspect).to eq("#<Money fractional:20 currency:USD date:2020-01-01>")
    end
  end

  describe "#with_date" do
    it "returns self if given the same date" do
      money = Money.new(20, :usd, date: Date.today)

      new_money = money.with_date(Date.today)

      expect(money.object_id).to eq(new_money.object_id)
    end

    it "duplicates Money but changes the date if new date is different" do
      money = Money.new(20, :usd, date: Date.today)

      new_money = nil
      expect do
        new_money = money.with_date(Date.today - 1)
      end.not_to change(money, :date)

      expect(new_money.fractional).to eq(money.fractional)
      expect(new_money.currency).to eq(money.currency)
      expect(new_money.date).to eq(Date.today - 1)
    end
  end

  describe "#eql?" do
    subject { money.eql?(other) }

    context "by default" do
      context "when other object is not an instance of Money" do
        let(:money) { Money.new(20) }
        let(:other) { "foo bar" }

        it { is_expected.to eq(false) }
      end

      context "when money and other object are both zero" do
        let(:money) { Money.new(0, :usd, date: Date.today) }
        let(:other) { Money.new(0, :usd, date: Date.today - 1) }

        it { is_expected.to eq(true) }
      end

      context "when money and other object are more than zero" do
        context "when fractional, currency, and date are equal" do
          let(:money) { Money.new(20, :usd, date: Date.today) }
          let(:other) { Money.new(20, :usd, date: Date.today) }

          it { is_expected.to eq(true) }
        end

        context "when fractionals differ" do
          let(:money) { Money.new(20, :usd, date: Date.today) }
          let(:other) { Money.new(40, :usd, date: Date.today) }

          it { is_expected.to eq(false) }
        end

        context "when currencies differ" do
          let(:money) { Money.new(20, :usd, date: Date.today) }
          let(:other) { Money.new(20, :eur, date: Date.today) }

          it { is_expected.to eq(false) }
        end

        context "when dates differ" do
          let(:money) { Money.new(20, :usd, date: Date.today) }
          let(:other) { Money.new(20, :usd, date: Date.today - 1) }

          it { is_expected.to eq(true) }
        end
      end
    end

    context "when Money.date_determines_equality is true" do
      around do |example|
        Money.date_determines_equality = true
        example.run
        Money.date_determines_equality = false
      end

      context "when other object is not an instance of Money" do
        let(:money) { Money.new(20) }
        let(:other) { "foo bar" }

        it { is_expected.to eq(false) }
      end

      context "when money and other object are both zero" do
        let(:money) { Money.new(0, :usd, date: Date.today) }
        let(:other) { Money.new(0, :usd, date: Date.today - 1) }

        it { is_expected.to eq(true) }
      end

      context "when money and other object are more than zero" do
        context "when fractional, currency, and date are equal" do
          let(:money) { Money.new(20, :usd, date: Date.today) }
          let(:other) { Money.new(20, :usd, date: Date.today) }

          it { is_expected.to eq(true) }
        end

        context "when fractionals differ" do
          let(:money) { Money.new(20, :usd, date: Date.today) }
          let(:other) { Money.new(40, :usd, date: Date.today) }

          it { is_expected.to eq(false) }
        end

        context "when currencies differ" do
          let(:money) { Money.new(20, :usd, date: Date.today) }
          let(:other) { Money.new(20, :eur, date: Date.today) }

          it { is_expected.to eq(false) }
        end

        context "when dates differ" do
          let(:money) { Money.new(20, :usd, date: Date.today) }
          let(:other) { Money.new(20, :usd, date: Date.today - 1) }

          it { is_expected.to eq(false) }
        end
      end
    end
  end

  describe "#<=>" do
    context "by default" do
      context "when other iz zero" do
        subject { Money.new(20) <=> 0 }

        it { is_expected.to eq(1) }
      end

      context "when other is Money with different currency but the value is zero" do
        subject { Money.new(20, :usd) <=> Money.new(0, :eur) }

        it { is_expected.to eq(1) }
      end

      context "when other is Money with different currency but the exchange rate isn't known" do
        subject { Money.new(20, :usd) <=> Money.new(20, :eur) }

        it { is_expected.to eq(nil) }
      end

      context "when other is Money with different currency but known exchange rate" do
        subject { Money.new(20, :usd) <=> Money.new(20, :eur) }

        around do |example|
          old_bank = Money.default_bank
          example.run
          Money.default_bank = old_bank
        end

        before do
          Money.default_bank = Money::Bank::VariableExchange.new
          Money.add_rate(:eur, :usd, 1.25)
        end

        it { is_expected.to eq(-1) }
      end

      context "when other is Money with same currency but different date" do
        subject { Money.new(20, :usd, date: Date.today - 1) <=> Money.new(20, :usd, date: Date.today) }

        it { is_expected.to eq(0) }
      end
    end

    context "when Money.date_determines_equality is true" do
      around do |example|
        Money.date_determines_equality = true
        example.run
        Money.date_determines_equality = false
      end

      context "when zero is on the left side" do
        subject { Money.new(20) <=> 0 }

        it { is_expected.to eq(1) }
      end

      context "when zero is on the right side" do
        subject { 0 <=> Money.new(20) }

        it { is_expected.to eq(-1) }
      end

      context "when other is not Money and not zero" do
        subject { Money.new(20) <=> 5 }

        it { is_expected.to eq(nil) }
      end

      context "when other is Money with different currency but the value is zero" do
        subject { Money.new(20, :usd) <=> Money.new(0, :eur) }

        it { is_expected.to eq(1) }
      end

      context "when other is Money with different currency but the exchange rate isn't known" do
        subject { Money.new(20, :usd) <=> Money.new(20, :eur) }

        it { is_expected.to eq(nil) }
      end

      context "when other is Money with different currency but known exchange rate" do
        subject { Money.new(20, :usd) <=> Money.new(20, :eur) }

        around do |example|
          old_bank = Money.default_bank
          example.run
          Money.default_bank = old_bank
        end

        before do
          Money.default_bank = Money::Bank::VariableExchange.new
          Money.add_rate(:eur, :usd, 1.25)
        end

        it { is_expected.to eq(-1) }
      end

      context "when other is Money with same currency but different date" do
        subject { Money.new(20, :usd, date: Date.today - 1) <=> Money.new(20, :usd, date: Date.today) }

        it { is_expected.to eq(-1) }
      end
    end
  end
end
