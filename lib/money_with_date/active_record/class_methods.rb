# frozen_string_literal: true

module MoneyWithDate
  module ActiveRecord
    module ClassMethods
      attr_accessor :default_date_column
    end
  end
end
