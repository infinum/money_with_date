# frozen_string_literal: true

RSpec.describe MoneyWithDate::Hooks do
  describe ".init?" do
    subject { described_class.init? }

    context "when money-rails version is supported" do
      before do
        stub_const("MoneyRails::VERSION", "1.15.0")
      end

      it { is_expected.to eq(true) }
    end

    context "when money-rails version is too low" do
      before do
        stub_const("MoneyRails::VERSION", "1.14.0")
      end

      it { is_expected.to eq(false) }
    end

    context "when money-rails version is too high" do
      before do
        stub_const("MoneyRails::VERSION", "100.0.0")
      end

      it { is_expected.to eq(false) }
    end
  end
end
