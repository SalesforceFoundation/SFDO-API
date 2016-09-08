# SFDO::API

SFDO-API is a convenient way to use the Salesforce API to manipulate objects in a target org. SFDO-API was intended orginally to
facilitate the sharing of common API calls across multiple source repositories, but the project is evolving to provide powerful
tools for handiling SF objects, like support for managed and unmanaged namespaces, multiple namespaces in an org, etc. 

SFDO-API accepts commands from the calling script, and then lets the restforce Ruby gem deal directly with the Salesforce API.

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

### All examples below are calling code, not SFDO-API code

To create a simple Account and get the ID for that Account:

```ruby
  def create_account_via_api(client_name)
    @account_id = create 'Account', Name: client_name
  end
```

You can also address the Restforce API client directly if you want, for example to issue a 'select' query:

```ruby
  def create_contact_via_api(client_name, street = '', city = '', state = '', country = '', zip = '')
    @contact_id = create 'Contact', LastName: client_name,
                                    MailingStreet: street,
                                    MailingCity: city,
                                    MailingState: state,
                                    MailingCountry: country,
                                    MailingPostalCode: zip
    account_object = @api_client.query("select AccountId from Contact where Id = '#{@contact_id}'")
    my_account_object = account_object.first
    @account_id_for_contact = my_account_object.AccountId
  end
```

To delete a single instance of an object for which you have the Id value
```ruby
  def delete_account_via_api
   delete_one_account(@account_id)
  end
```

```ruby
  def delete_contacts_via_api
    api_client do
      @array_of_contacts.each do |contact_id|
        delete_one_contact(contact_id)
      end
    end
  end
```

To delete all instances of an object 

```ruby
  def delete_household_accounts
    api_client do
      hh_accs = @api_client.query("select Id from Account where Type = 'Household'")
      delete_all_household_account(hh_accs)
    end
  end
```

### Custom Objects

To create instances of custom objects that may have managed or unmanaged namespace use true_object_name. 

```ruby
  def create_gau_via_api(gau_name)
    @gau_id = create "#{true_object_name('General_Accounting_Unit__c')}", Name: gau_name
  end
```

NOTE: in the future we will remove the need to use true_object_name() from calling code when creating and selecting custom objects, 
but for now this is how it works.

When using delete_one_foo or delete_all_foo do not use any namespace value, SFDO-API does that for you

```ruby
  def delete_gaus_via_api
    api_client do
      gaus = @api_client.query("select Id from #{true_object_name('General_Accounting_Unit__c')}")
puts gaus.inspect
      delete_all_General_Accounting_Unit__c(gaus)
    end
  end
```

### Using objects where local override changes required fields

Note that ISVs may override required fields on standard Salesforce objects, and these may be needed for SFDO-API to work properly

```ruby
  # NPSP will automatically create certain fields on certain objects based on required input values for those records.
  # There is no way to know in advance from the API which these are, so we find them empirically and note them here
  # before calling the create() method in SfdoAPI
  @fields_acceptibly_nil = { 'Contact': ['Name'],
                             'Opportunity': ['ForecastCategory'] }
```





## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/SalesforceFoundation/SFDO-API.

