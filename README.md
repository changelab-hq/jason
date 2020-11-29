# Jason

## The goal

I wanted:
 - Automatic updates to client state based on database state
 - Automatic persistence to database
 - Redux for awesome state management
 - Optimistic updates

I also wanted to avoid writing essentially the same code multiple times in different places to handle common CRUD-like operations. Combine Rails schema definition files, REST endpoints, Redux actions, stores, reducers, handlers for websocket payloads and the translations between them, and it adds up to tons of repetitive boilerplate. Every change to the data schema requires updates in five or six files. This inhibits refactoring and makes mistakes more likely.

Jason attempts to minimize this repitition by auto-generating API endpoints, redux stores and actions from a single schema definition. Further it adds listeners to ActiveRecord models allowing the redux store to be subscribed to updates from a model or set of models.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jason'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install jason

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/jason. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/jason/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Jason project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/jason/blob/master/CODE_OF_CONDUCT.md).
