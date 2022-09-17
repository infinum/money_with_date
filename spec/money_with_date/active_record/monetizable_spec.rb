# frozen_string_literal: true

require "money_with_date/hooks"
require "money-rails"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

MoneyRails::Hooks.init
MoneyWithDate::Hooks.init

ActiveRecord::Schema.define do
  create_table :products, force: true do |t|
    t.integer :price_cents
    t.string :price_currency
    t.date :created_on
    t.timestamps
  end
end

RSpec.describe ".monetize" do
  describe "money-rails options" do
    let(:model) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "products"

        def self.model_name
          "Product"
        end

        monetize :price_cents, with_model_currency: :price_currency
      end
    end

    it "doesn't affect them" do
      record = model.new(price_cents: 100, price_currency: "EUR")

      expect(record.price).to eq(Money.new(100, :eur))
    end
  end

  describe "no date options" do
    let(:model) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "products"

        def self.model_name
          "Product"
        end

        monetize :price_cents
      end
    end

    context "when default_date_column exists" do
      it "is used to set the date" do
        record = model.new(price_cents: 100, created_at: Date.today - 10)

        expect(record.price.date).to eq(Date.today - 10)
      end
    end

    context "when default_date_column is nil" do
      it "uses the default date" do
        record = model.new(price_cents: 100, created_at: nil)

        expect(record.price.date).to eq(Date.today)
      end
    end

    context "when default_date_column doesn't exist" do
      around do |example|
        old_default_date_column = Money.default_date_column
        example.run
        Money.default_date_column = old_default_date_column
      end

      it "uses the default date" do
        Money.default_date_column = :foo_bar

        record = model.new(price_cents: 100, created_at: Date.today - 10)

        expect(record.price.date).to eq(Date.today)
      end
    end
  end

  describe "with_model_date option" do
    let(:model) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "products"

        def self.model_name
          "Product"
        end

        monetize :price_cents, with_model_date: :created_on
      end
    end

    context "when date attribute is nil" do
      it "uses the default date" do
        record = model.new(price_cents: 100, created_on: nil)

        expect(record.price.date).to eq(Date.current)
      end
    end

    context "when date attribute exists" do
      it "is used to set the Money date" do
        record = model.new(price_cents: 100, created_on: Date.today - 5)

        expect(record.price.date).to eq(Date.today - 5)
      end
    end

    it "returns nil if the amount doesn't exist" do
      record = model.new(price_cents: nil, created_on: nil)

      expect(record.price).to eq(nil)
    end

    it "works with nil amount if the date column changes" do
      record = model.new(price_cents: nil, created_on: "2020-01-01")

      expect(record.price).to eq(nil)

      record.created_on = "2021-01-01"

      expect(record.price).to eq(nil)
    end

    it "changes the date on the money object if the date column changes" do
      record = model.new(price_cents: 100, created_on: "2020-01-01")

      expect(record.price.date).to eq(Date.parse("2020-01-01"))

      record.created_on = "2021-01-01"

      expect(record.price.date).to eq(Date.parse("2021-01-01"))
    end
  end

  context "with_date option" do
    context "when a callable" do
      let(:model) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "products"

          def self.model_name
            "Product"
          end

          monetize :price_cents, with_date: ->(_) { Date.today + 5 }
        end
      end

      it "resolves the callable" do
        record = model.new(price_cents: 100)

        expect(record.price.date).to eq(Date.today + 5)
      end
    end

    context "when a static value" do
      let(:model) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "products"

          def self.model_name
            "Product"
          end

          monetize :price_cents, with_date: Date.today + 5
        end
      end

      it "uses that value" do
        record = model.new(price_cents: 100)

        expect(record.price.date).to eq(Date.today + 5)
      end
    end
  end

  context "with_model_date and with_date option" do
    let(:model) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "products"

        def self.model_name
          "Product"
        end

        monetize :price_cents, with_model_date: :created_on, with_date: Date.today + 5
      end
    end

    it "gives precedence to with_model_date" do
      record = model.new(price_cents: 100, created_on: Date.today - 5)

      expect(record.price.date).to eq(Date.today - 5)
    end

    it "uses the default date if model date doesn't exist" do
      record = model.new(price_cents: 100, created_on: nil)

      expect(record.price.date).to eq(Date.today)
    end
  end
end
