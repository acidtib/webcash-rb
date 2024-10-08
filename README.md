# webcash-rb

Webcash is an experimental electronic cash library for decentralized payments.
Webcash facilitates decentralized, peer-to-peer electronic cash transactions. It allows users to send webcash directly to one another and includes mechanisms for detecting double-spending and maintaining monetary supply integrity.

Navigate to https://webcash.org/ for more information, including the Terms of Service.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add webcash-rb
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install webcash-rb
```

## Usage
```ruby
require "webcash"

wallet = Webcash::Wallet.new(
  master_secret: "19be5ea41c71836f78b5691fe69af918a5f003719b7a7e2a30533737c04521fc",
)

# Set the legal agreements to true
wallet.set_legal_agreements_to_true

# Recover webcash using the wallet's master secret.
wallet.recover

# Check webcash in wallet. Remove any spent webcash.
wallet.check

# Insert webcash into the wallet.
wallet.insert("e20:secret:8c2e565a1649b03052833c508b237bacd2c62995c7e8ed5dc9fe644850808192")

# Pay webcash from the wallet.
wallet.pay(4.20)

# Get wallet balance
pp wallet.get_balance
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/acidtib/webcash-rb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/acidtib/webcash-rb/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Webcash project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/acidtib/webcash-rb/blob/master/CODE_OF_CONDUCT.md).
