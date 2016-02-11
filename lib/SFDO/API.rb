require 'SFDO/API/version'

module SfdoAPI
  def api_client
    @api_client ||= Restforce.new api_version: '32.0',
                                  refresh_token: ENV['SF_REFRESH_TOKEN'],
                                  client_id: ENV['SF_CLIENT_KEY'],
                                  client_secret: ENV['SF_CLIENT_SECRET']
    yield
  end

  def create(type, obj_hash)
    if is_valid_obj_hash?(type, obj_hash, @fields_acceptibly_nil)
      obj_id = api_client do
        @api_client.create! type, obj_hash
      end
    end
    obj_id
  end

  def is_valid_obj_hash?(object_name, obj_hash, fields_acceptibly_nil)
    required_fields = get_object_describe(object_name).map(&:fieldName)
    #   [name, id, required_field_1__c, etc]
    valid = true
    required_fields.each do |f|
      valid = false unless obj_hash.key? f.to_sym && (begin
        !fields_acceptibly_nil[object_name].contains? f
      rescue
        false
      end)
    end
    valid
  end

  def get_object_describe(object_name)
    api_client do
      @description = @api_client.get("/services/data/v35.0/sobjects/#{object_name}/describe")

      describeobject = Hashie::Mash.new(@description.body)

      required = describeobject.fields.map do |x|
        Hashie::Mash.new(
          fieldName: x.name,
          required: (!x.nillable && !x.defaultedOnCreate),
          default: x.defaultValue)
      end
      required.select(&:required)
    end
  end
end
