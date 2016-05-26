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

  def delete(type, obj_id)
    api_client do
      @api_client.destroy(type, obj_id)
    end
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
    @org_objects ||= api_client do
      @api_client.describe
    end
  end

  #def get_deletable_objects()
  #  get_org_objects.select(&:deletable).map {|x| x.name}
  #end

  #def initia_conv()
    #super

   # p "this should show up "
    #binding.pry
   # get_deletable_objects.each do |obj|
   #   p "defining method #{obj}"
   #   binding.pry
   #   Module.define_method("delete_#{obj}".to_sym) {|id|
   #     #p "defining method #{obj}"
   #     delete(obj, id)
   #   }
   #   #alias "delete_#{obj}".to_sym :delete
   # end
    #super
  #end


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

    def generic_delete(obj_type, id)
      api_client do
        p "id is " + id.inspect
        #@api_client.destroy(obj_type, id)
        id.each(&:destroy)
      end
    end

    # Given that the developer calls 'delete_contact(id)'
    # When 'contact' is a valid object
    # Then this method_missing method, will translate 'delete_contact' into "generic_delete('contact', id)"

  def method_missing(method_called, *args, &block)
    case method_called.to_s
      when /^delete_all_/
        p "in delete_all"
        breakdown = method_called.to_s.split('_')
        action = breakdown.first
        obj_type = breakdown.last.capitalize
        p *args.inspect
        generic_delete obj_type, *args

      when /^delete_one/
        breakdown = method_called.to_s.split('_')
        action = breakdown.first
        obj_type = breakdown.last.capitalize
        generic_delete obj_type, *args
      #stuff
      when /^create_/
        #other stuff
      else
        super.method_missing
    end
  end

end
# INCLUDE HERE RATHER THAN IN THE PRODUCT-SPECIFIC CODE USING THIS GEM
include SfdoAPI
