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

  def delete(type, obj_id)
    @api_client.destroy(type, obj_id)
  end

  def is_valid_obj_hash?(object_name, obj_hash, fields_acceptibly_nil)
    required_fields = get_object_describe(object_name).map(&:fieldName)
    #   [name, id, required_field_1__c, etc]
    valid = true
    required_fields.each do |f|

      valid = false if (!obj_hash.key? f.to_sym) && (begin
        !fields_acceptibly_nil[object_name].contains? f
        puts 'This field must be populated in order to create this object in this environment: ' +  f.inspect
      rescue
        false
      end)
    end
    valid
  end

  def get_org_objects()
    #binding.pry
    @org_objects ||= api_client.describe
  end

  def get_deletable_objects()
    get_org_objects.select(&:deletable).map {|x| x.name}
  end

  def initia_conv()
    #super
    require 'pry'
    p "this should show up "
    #binding.pry
    get_deletable_objects.each do |obj|
      method_alias "delete_#{obj}", :delete
    end
    #super
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
# INCLUDE HERE RATHER THAN IN THE PRODUCT-SPECIFIC CODE USING THIS GEM
include SfdoAPI
