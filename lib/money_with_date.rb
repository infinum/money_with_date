# frozen_string_literal: true

require "date"
require "money"

require_relative "money_with_date/version"
require_relative "money_with_date/class_methods"
require_relative "money_with_date/instance_methods"
require_relative "money_with_date/bank/variable_exchange"
require_relative "money_with_date/rates_store/memory"

::Money.prepend(::MoneyWithDate::InstanceMethods)
::Money.singleton_class.prepend(::MoneyWithDate::ClassMethods)

# :nocov:
::Money.date_determines_equality = false
::Money.default_date = ::Date.respond_to?(:current) ? -> { ::Date.current } : -> { ::Date.today }

require "money_with_date/railtie" if defined?(::Rails::Railtie) && defined?(::MoneyRails)
# :nocov:
