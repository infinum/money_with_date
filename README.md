# money_with_date

A Ruby library which extends the popular [money](https://github.com/RubyMoney/money) and [money-rails](https://github.com/RubyMoney/money-rails) gems with support for dated Money objects.

Dated Money objects are useful in situations where you have to exchange money between currencies based on historical exchange rates, and you'd like to keep date information on the Money object itself.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'money_with_date'
```

And then execute:

    $ bundle install

Or install it yourself:

    $ gem install money_with_date

That's it! All your Money objects now have a date attribute.

## Usage

```ruby
Money.default_bank = MoneyWithDate::Bank::VariableExchange.new(MoneyWithDate::RatesStore::Memory.new)
# the gem provides subclasses of Money::Bank::VariableExchange and Money::RatesStore::Memory
# which can save historical exchange rates

Money.add_rate "USD", "EUR", 0.9, "2020-01-01"
Money.add_rate "CHF", "EUR", 0.96, Date.today

Money.new(100, "EUR", date: Date.today) + Money.new(100, "USD", date: "2020-01-01")
# => Money.new(190, "EUR", date: Date.today)
# the second Money object is exchanged to EUR with the exchange rate on 1/1/2020

Money.default_date = -> { Date.today }
# new Money objects use the default date if "date" parameter is omitted in Money.new

transactions = [
  Money.from_amount(2, "CHF"),
  Money.from_amount(1, "USD", date: "2020-01-01"),
  Money.from_amount(2, "EUR")
]

transactions.map { |money| money.exchange_to(:eur) }.sum
# => Money.from_amount(4.82, "EUR")
# 2 CHF == 1,92 EUR on today's date
# 1 USD == 0,9 EUR on 1/1/2020
# 1,92 + 0,9 + 2 == 4,82

# In Rails, a date column can be used to control the date of the Money object:
class Product < ActiveRecord::Base
  monetize :amount_cents, with_model_date: :published_on
end

product = Product.new(amount_cents: 100, published_on: "2020-01-01")

product.amount.date
# => "2020-01-01"
```

When you install and require the gem, all Money objects will automatically have a date attribute.

The default date for a Money object is read from the configuration option `Money.default_date` (more about that [here](#default_date)).

You can also override the default date when creating a Money object:
```ruby
money = Money.new(100, :usd, date: "2020-01-01")

money.date # => "2020-01-01"
```

The type of the `date` param should either be a Date object or something which can be coerced into Date (e.g. Time object, a string which can be parsed as date). The following examples are all valid ways of setting a date:
```ruby
Money.new(100, :usd, date: Date.today)

Money.new(100, :usd, date: Time.now) # converted to Date with the `#to_date` method

Money.new(100, :usd, date: "2022-02-15") # converted to Date with `Date.parse`
```

`date` argument which cannot be coerced into a Date will result in an `ArgumentError`.

It is also possible to copy Money objects and change their date with `Money#with_date`:
```ruby
money = Money.from_cents(100, :eur, date: "2022-02-15")

new_money = money.with_date("2020-01-01")

new_money.cents # => 100
new_money.date # => "2020-01-01"
money.date # => "2022-02-15" (the original object is unchanged)
```

In addition to `Money.new`, the `date` param can also be passed to the following methods:
```ruby
Money.from_amount(10.00, :usd, date: Date.today)

Money.from_cents(1000, :usd, date: Date.today)
```

### Currency Exchange

This gem supports all existing bank implementations which do not support historical exchange rates. By default, when you require `money_with_date` in your project, existing currency exchange logic won't be affected.

To enable historical currency exchanges, the bank and rates store objects you use must support an additional `date` param in order to associate an exchange rate with a specific date.

This gem provides subclasses of money's default bank and rates store (variable exchange, in-memory store), which have been extended to support historical exchange rates:
```ruby
Money.default_bank = MoneyWithDate::Bank::VariableExchange.new(MoneyWithDate::RatesStore::Memory.new)
```

To save a historical exchange rate, use `Money.add_rate` and supply a date param:
```ruby
Money.add_rate "EUR", "USD", 1.1, Date.today
```

Currency exchange then works like this:
```ruby
Money.add_rate "EUR", "USD", 1.05, Date.today - 1
Money.add_rate "EUR", "USD", 1.1, Date.today
Money.add_rate "EUR", "USD", 1.2, Date.today + 1

money = Money.new(100, "EUR", date: Date.today + 1)

money.exchange_to("USD").cents == 120 # => true
```

To retrieve a historical exchange rate from a bank, invoke `Bank#get_rate` with a date param:
```ruby
Money.default_bank.get_rate("EUR", "USD", Date.today - 1) # => 1.05
```

The same rules that apply to the date param when initializing a Money object also apply here: it can be a Date object or anything that can be coerced into a Date object (Time, String).

### Exchange rate stores

This gem provides an in-memory store for historical exchange rates: `MoneyWithDate::RatesStore::Memory`. This class is very similar to `Money::RatesStore::Memory`, only an additional `date` parameter has been added to methods where necessary.

You can also implement your own store, but it has to follow this interface:
```ruby
# Add new exchange rate.
# @param [String] iso_from Currency ISO code. ex. 'USD'
# @param [String] iso_to Currency ISO code. ex. 'CAD'
# @param [Numeric] rate Exchange rate. ex. 0.0016
# @param [Date] date Exchange rate date. ex. Date.today
#
# @return [Numeric] rate.
def add_rate(iso_from, iso_to, rate, date); end

# Get rate. Must be idempotent. i.e. adding the same rate must not produce duplicates.
# @param [String] iso_from Currency ISO code. ex. 'USD'
# @param [String] iso_to Currency ISO code. ex. 'CAD'
# @param [Date] date Exchange rate date. ex. Date.today
#
# @return [Numeric] rate.
def get_rate(iso_from, iso_to, date); end

# Iterate over rate tuples (iso_from, iso_to, rate)
#
# @yieldparam iso_from [String] Currency ISO string.
# @yieldparam iso_to [String] Currency ISO string.
# @yieldparam rate [Numeric] Exchange rate.
# @yieldparam date [Date] Exchange rate date.
#
# @return [Enumerator]
#
# @example
#   store.each_rate do |iso_from, iso_to, rate, date|
#     puts [iso_from, iso_to, rate, date].join
#   end
def each_rate(&block); end

# Wrap store operations in a thread-safe transaction
# (or IO or Database transaction, depending on your implementation)
#
# @yield [n] Block that will be wrapped in transaction.
#
# @example
#   store.transaction do
#     store.add_rate('USD', 'CAD', 0.9, Date.today)
#     store.add_rate('USD', 'CLP', 0.0016, Date.today)
#   end
def transaction(&block); end

# Serialize store and its content to make Marshal.dump work.
#
# Returns an array with store class and any arguments needed to initialize the store in the current state.

# @return [Array] [class, arg1, arg2]
def marshal_dump; end
```

### Usage With Rails

In case you're using `money-rails`, its `monetize` helper will also be extended to provide options for setting the date on monetized attributes. There are three ways you can set the date on a monetized attribute:

#### `with_model_date` option

Use this option when you want to use a table column to set the date on a monetized attribute. For example, if you have a table:
```ruby
# Table name: products
#
#  id                  :integer      not null, primary key
#  amount_cents        :integer      not null
#  published_on        :date
#  created_at          :timestamp    not null
#
```
and you want to use `published_on` column to set the date on the monetized `amount_cents`, do this:
```ruby
class Product < ActiveRecord::Base
  monetize :amount_cents, with_model_date: :published_on
end
```
which will cause the following:
```ruby
product = Product.new(amount_cents: 100, published_on: "2020-01-01")

product.amount.date # => "2020-01-01"
```

If the value of the `with_model_date` column is `nil`, the date on the Money object will fall back to `Money.default_date`.

#### `with_date` option

This option can be used when you want to either hard-code a date for a monetized attribute, or you want to set the date dynamically. If you want to hard-code the date, pass a concrete value:
```ruby
class Product < ActiveRecord::Base
  monetize :amount_cents, with_date: "2020-01-01"
end
```
All `Product#amount` Money objects will now have the same date: 1/1/2020.

You can also set the date on the Money object dynamically by using a callable:
```ruby
class Product < ActiveRecord::Base
  monetize :amount_cents, with_date: ->(product) { product.published_on || product.created_at }
end
```
The callable should accept a single param: the ActiveRecord object.

In case the callable resolves to nil, the date on the Money object will fall back to `Money.default_date`.

#### `Money.default_date_column`

If you don't supply either of the above options to `monetize`, the gem will search for a default column to set the date on a monetized attribute. By default, this column is `created_at`. That means that if your class looks like this:
```ruby
class Product < ActiveRecord::Base
  monetize :amount_cents
end
```
the following will happen:
```ruby
product = Product.new(amount_cents: 100, created_at: "2020-01-01")

product.amount.date # => "2020-01-01"
```

In case the default column doesn't exist, or its value is nil, the date on the Money object will fall back to `Money.default_date`.

You can also override the default column, or even disable it, which you can find out how to do [here](#default_date_column).

## Configuration

The gem provides a couple of configuration options.

### default_date

With the `money_with_date` gem installed, _all_ Money objects have a date. If you don't supply a date when creating a Money object, a default date will be assigned.

You can override the default date:
```ruby
Money.default_date = -> { Date.today }
```
and fetch it like this:
```ruby
Money.default_date # outputs today's date
```

The default date can be either a callable or a concrete value.
If you set a callable, `Money.default_date` will call the callable and return its value.

By default, `Money.default_date` is set to:
```ruby
Money.default_date = -> { Date.current }
```
if `Date.current` exists (which is the case in Rails projects). If it doesn't exist, the default date is set to:
```ruby
Money.default_date = -> { Date.today }
```

### date_determines_equality

Based on your use case, you might or might not want the `date` attribute to affect whether two Money objects are equal. For example, in some scenarios it makes sense that:
```ruby
Money.new(100, :usd, date: "2010-12-31") == Money.new(100, :usd, date: "2020-01-01")
```
returns `true` (e.g. if you care only about money amounts), while in others it makes sense that it returns `false`.

By default, the date on the Money object **doesn't** affect the equality of the object to other Money objects (in the above scenario, the expression would return `true`).

However, if you need to, you can tell the gem to look at the date when comparing Money objects, so that the above expression would return `false`. You can achieve that by setting:
```ruby
Money.date_determines_equality = true
```

Setting this will affect the following Money methods: `#hash`, `#eql?` and `#<=>`.

### default_date_column

If you use `money-rails` and `monetize`, but don't supply either `with_date` or `with_model_date` options, the gem will try to find a default column to set the date on the monetized attribute.

The default table column for setting the date on Money is `created_at`.

If you'd like to use a different default column, set it with:
```ruby
# config/initializers/money.rb
Money.default_date_column = :my_date_column
```

If the column value is nil, or the column doesn't exist on the table, the date will fall back to `Money.default_date`.

If you don't want the gem to use a default column for setting the date, set this:
```ruby
Money.default_date_column = nil
```

## Supported Versions

`money_with_date` has the following version requirements:
- Ruby: **>= 3.1.0**
- money: **>= 6.14.0** and **<= 7.0.2**
- money-rails: **>= 1.15.0** and **<= 3.0.0**

The gem has been tested against all possible combinations of supported Ruby, Rails, money, and money-rails versions:
- Ruby: `3.1`, `3.2`, `3.3`, `3.4` and `4.0`
- Rails: `~> 6.1.0`, `~> 7.0.0`, `~> 7.1.0`, `~> 7.2.0`, `~> 8.0.0` and `~> 8.1.0`
- money: `6.14.0`, `6.14.1`, `6.16.0`, `6.17.0`, `6.18.0`, `6.19.0`, `7.0.0`, `7.0.1` and `7.0.2`
- money-rails: `1.15.0`, `2.0.0` and `3.0.0`

In addition to running its own test suite, the CI for this gem also runs [money's](https://github.com/RubyMoney/money/tree/main/spec) and [money-rails's](https://github.com/RubyMoney/money-rails/tree/main/spec) test suites with this gem loaded, to prevent regressions. This has been achieved by cloning their test suites from GitHub and requiring this gem in their spec files. For technical information, check the CI [workflow](.github/workflows/ci.yml).

## Compatibility

This gem overrides money's and money-rails's public and _private_ APIs. As such, the gem can break with any new release of either of those gems if their API changes. To ensure breakages don't happen, the gem has been locked only to those versions of money and money-rails which have been fully tested for regressions.

The minimum supported versions are 6.14.0 for money and 1.15.0 for money-rails. Versions older than those cannot be supported as the API in older versions of both gems cannot be extended to provide the functionality which this gem provides.

### Positional bank parameter

Up until version 6.14.0 of money, Money constructor accepted only three positional arguments (amount, currency, and bank):
```ruby
Money.new(1000, :usd, Money.default_bank)
```

From version 6.14.0, the constructor accepts two positional arguments and optional keyword arguments which can be used to override the default bank:
```ruby
Money.new(1000, :usd, bank: Money.default_bank)
```

For backwards-compatibility reasons, in version 6.14.0 and above, you can use either of those approaches to override the default bank.

However, the old approach isn't compatible with this gem because it doesn't allow us to provide a date argument without modifying the constructor.

So, if you want to use this gem, but are currently overriding the default bank with a positional argument, you'll have to refactor your code to use the new approach.

Note that, even if you don't refactor the code, the gem will still work, but all Money objects created that way will be assigned the default date.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Run `bin/console` for an interactive prompt that will allow you to experiment.

To run RuboCop, execute `bundle exec rake rubocop`.

To run unit tests, execute `bundle exec rake spec:unit`. Unit tests can be run with different versions of money, money-rails, and Rails, which you can specify as Rake task arguments. For example, if you want to run unit tests on money 6.14.0, money-rails 1.15.0, and Rails 6.1.4.6, execute: `bundle exec rake "spec:unit[6.14.0, 1.15.0, 6.1.4.6]"`.

To run money regression tests, execute `bundle exec rake spec:money`. You can also run them with a specific version of money: `bundle exec rake "spec:money[6.14.1]"`.

To run money-rails regression tests, execute `bundle exec rake spec:money_rails`. The task also accepts a money-rails version argument: `bundle exec rake "spec:money_rails[1.15.0]"`.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/infinum/money_with_date. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/infinum/money_with_date/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the MoneyWithDate project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/infinum/money_with_date/blob/master/CODE_OF_CONDUCT.md).
