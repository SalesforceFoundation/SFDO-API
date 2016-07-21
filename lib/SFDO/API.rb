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

  def org_describe()
    #binding.pry
    @org_describe ||= api_client do
      @api_client.describe
    end
  end


  def npsp_managed_obj_names()
    #BOOM FIX THIS REGEX
    @npsp_managed_obj_names ||= @org_describe.select{|x| x.name =~ /^np.*__.*__c/i}.map{|y| y.name}
    p ""
    p "this is npsp_managed_obj_names " + @npsp_managed_obj_names.inspect
    p ""
  end

  def managed_package_prefix(obj_name)
    # GOAL: Delete NPSP objects whether managed or unmanaged
    # Managed will start with npsp__
    # Unmanaged will have no prefix but end with __c
    # Other prefixes will always be managed
    # URLs also need tweaking
    # I don't have an unmanaged org handy right now
    p ""
    p "this is obj_name in managed_package_prefix " + obj_name
    p ""
    npsp_managed_obj_names


    potentials = @npsp_managed_obj_names.select{|x| x =~ /obj_name/i}
    binding.pry
    if potentials.size  > 0
      p potentials.first.split("__.")
      return potentials.first.split("__.").first + "__."
    end
    p "it's at least one managed package" if potentials.length > 0
    p potentials.length
    p potentials.inspect
    #binding.pry
  end

  def get_object_describe(object_name)
    api_client do
      org_describe
      managed_package_prefix("npsp__General_Accounting_Unit__c")
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
    api_client do
      @api_client.destroy(type, obj_id)
    end
  end

  def delete_all(obj_type, id)
    api_client do
      #p "id is " + id.inspect
      #@api_client.destroy(obj_type, id)
      id.each(&:destroy)
    end
  end

    # Given that the developer calls 'delete_contact(id)'
    # When 'contact' is a valid object
    # Then this method_missing method, will translate 'delete_contact' into "generic_delete('contact', id)"

  def method_missing(method_called, *args, &block)
    breakdown = method_called.to_s.split('_')
    obj_type = breakdown.last.capitalize
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
