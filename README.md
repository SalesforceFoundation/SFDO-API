# SFDO::API

SFDO-API is a convenient way to manipulate valid Salesforce objects in a target environment. It accepts commands from
the calling script, and then lets the restforce Ruby gem deal directly with the Salesforce API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'SFDO-API'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install SFDO-API

## Usage

To create a simple Account and get the ID for that Account:

  def create_account_via_api(client_name)
    @account_id = create 'Account', Name: client_name
  end

You can also address the Restforce API client directly if you want, for example to issue a 'select' query:

  def create_contact_via_api(client_name, street = '', city = '', state = '', country = '', zip = '')
    @contact_id = create 'Contact', LastName: client_name,
                                    MailingStreet: street,
                                    MailingCity: city,
                                    MailingState: state,
                                    MailingCountry: country,
                                    MailingPostalCode: zip
    @contact_name = client_name
    account_object = @api_client.query("select AccountId from Contact where Id = '#{@contact_id}'")
    my_account_object = account_object.first
    @account_id_for_contact = my_account_object.AccountId
  end

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/SalesforceFoundation/SFDO-API.

