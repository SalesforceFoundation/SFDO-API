require 'SFDO/API/version'
require 'pry'

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

  def org_describe()
    @org_describe ||= api_client do
      @api_client.describe
    end
  end

  def generate_obj_prefix_to_name
    @prefix_to_name = {}

    @prefix_to_name ||= @org_describe.each do |z|
      @prefix_to_name.store(z.keyPrefix, z.name)
    end
    return @prefix_to_name

    binding.pry
  end

  def npsp_managed_obj_names()
    # GOAL: Delete NPSP objects whether managed or unmanaged
    # Managed will start with np*__
    # Unmanaged will have no prefix but end with __c
    #binding.pry
    @npsp_managed_obj_names ||= @org_describe.select{|x| x.name =~ /^np.*__.*__c/i}.map{|y| y.name}
  end

  def true_object_name(obj_name)
    potentials = npsp_managed_obj_names().select{|x| x =~ /#{obj_name}/i}
    if potentials.size  > 0
      return potentials.first #.split("__.").first + "__."
    elsif org_describe().select{|x| x.name =~ /^#{obj_name}/i}.map{|y| y.name}.size > 0
      return obj_name
      end
  end

  def get_object_describe(object_name)
    api_client do
      org_describe
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

  def delete(type, obj_id)
    # true_object_name returns the wrong value if a custom object name contains the string of a SF object e.g "Account"
    p "obj_type as sent " + type
    p "obj type as returned from true_object_name() " + true_object_name(type)
    api_client do
      @api_client.destroy(true_object_name(type), obj_id)
    end
  end

  #
  #REWRITE TRUE_OBJECT_NAME TO RETURN type depending on obj_id from generate_obj_prefix_to_name
  # using first 3 characters of obj_id
  #

  def delete_all(obj_type, id)
    api_client do
      obj_type = true_object_name(obj_type)
      id.each(&:destroy)
    end
  end


  def method_missing(method_called, *args, &block)
    breakdown = method_called.to_s.split('_')
    obj_type = breakdown.last.capitalize

    #NEED TO ACCOUNT FOR THE CASE WHEN obj_type DOES NOT END IN /*__c/
    #THEN CALL DELETE WITHOUT CALLING true_object_name()

    case method_called.to_s
      when /^delete_all_/
        delete_all obj_type, *args
      when /^delete_one/
        delete obj_type, *args
      when /^create_/
        #TODO
      else
        super.method_missing
    end
  end

end
# INCLUDE HERE RATHER THAN IN THE PRODUCT-SPECIFIC CODE USING THIS GEM
include SfdoAPI
