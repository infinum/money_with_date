# frozen_string_literal: true

RSpec.describe MoneyWithDate::RatesStore::Memory do
  let(:subject) { described_class.new }

  describe "#add_rate and #get_rate" do
    it "stores rates in memory by date" do
      expect(subject.add_rate("USD", "CAD", 0.9, Date.today)).to eq(0.9)
      expect(subject.add_rate("USD", "CAD", 0.95, Date.today - 1)).to eq(0.95)

      expect(subject.get_rate("USD", "CAD", Date.today)).to eq(0.9)
      expect(subject.get_rate("USD", "CAD", Date.today - 1)).to eq(0.95)
    end
  end

  describe "#add_rate" do
    it "uses a mutex by default" do
      expect(subject.instance_variable_get(:@guard)).to receive(:synchronize)
      subject.add_rate("USD", "EUR", 1.25, Date.today)
    end
  end

  describe "#each_rate" do
    before do
      subject.add_rate("USD", "CAD", 0.9, Date.parse("2020-01-01"))
      subject.add_rate("CAD", "USD", 1.1, Date.parse("2021-01-01"))
    end

    it "iterates over rates" do
      expect do |b|
        subject.each_rate(&b)
      end.to yield_successive_args(["USD", "CAD", 0.9, Date.parse("2020-01-01")],
                                   ["CAD", "USD", 1.1, Date.parse("2021-01-01")])
    end

    it "is an Enumeator" do
      expect(subject.each_rate).to be_kind_of(Enumerator)
      result = subject.each_rate.each_with_object({}) { |(from, to, rate), m| m[[from, to].join] = rate }
      expect(result).to match({ "USDCAD" => 0.9, "CADUSD" => 1.1 })
    end
  end

  describe "#transaction" do
    context "mutex" do
      it "uses mutex" do
        expect(subject.instance_variable_get("@guard")).to receive(:synchronize)
        subject.transaction { 1 + 1 }
      end

      it "wraps block in mutex transaction only once" do
        expect do
          subject.transaction do
            subject.add_rate("USD", "CAD", 1, Date.today)
          end
        end.not_to raise_error
      end
    end
  end

  describe "#marshal_dump" do
    let(:subject) { described_class.new(optional: true) }

    it "can reload" do
      bank = MoneyWithDate::Bank::VariableExchange.new(subject)
      bank = Marshal.load(Marshal.dump(bank))
      expect(bank.store.instance_variable_get(:@options)).to eq(subject.instance_variable_get(:@options))
      expect(bank.store.instance_variable_get(:@index)).to eq(subject.instance_variable_get(:@index))
    end
  end
end
