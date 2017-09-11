# OpsworksShip

Provides a shipping script for AWS OpsWorks apps.

## Installation

This requires the AWS CLI tools to be configured on the machine running the script. [Learn how](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)  

Add this line to your application's Gemfile, probably in the `development` group:

```ruby
gem 'opsworks_ship'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install opsworks_ship
    
### Shipping app code

Create a script (probably in `bin/deploy`) similar to the following:

        #!/usr/bin/env ruby
        
        gem 'opsworks_ship'
        require 'opsworks_ship/deploy'
        
        OpsworksShip::Deploy.new(stack_name: ARGV[0], revision: ARGV[1], app_type: 'rails', app_layer_name_regex: 'rails|sidekiq', hipchat_auth_token: 'my_hipchat_auth_token', hipchat_room_id: 12345).deploy

### Shipping and executing chef code

Create a script (probably in `bin/chef`) similar to the following:

        #!/usr/bin/env ruby
        
        require 'opsworks_ship/chef'
        
        OpsworksShip::Chef.new(stack_name: ARGV[0], revision: ARGV[1], app_type: 'rails', app_layer_name_regex: 'rails|sidekiq', hipchat_auth_token: 'my_hipchat_auth_token', hipchat_room_id: 12345).deploy


## Usage examples

### App code

* `./bin/deploy help`
* `./bin/deploy staging heads/master rails rails|sidekiq`
* `./bin/deploy staging heads/master rails rails|sidekiq my_hipchat_token my_hipchat_room`
* `./bin/deploy production heads/master java "Java App Server" my_hipchat_token my_hipchat_room`

### Chef code

* `./bin/chef help`
* `./bin/chef staging heads/master rails rails|sidekiq`
* `./bin/chef staging heads/my_test_branch rails rails|sidekiq`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/NEWECX/opsworks_ship.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
