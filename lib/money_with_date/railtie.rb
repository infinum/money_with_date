# frozen_string_literal: true

require "money_with_date/hooks"

module MoneyWithDate
  class Railtie < ::Rails::Railtie
    initializer "money_with_date.initialize", after: "moneyrails.initialize" do
      MoneyWithDate::Hooks.init if MoneyWithDate::Hooks.init?
    end
  end
end
