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
    api_client do
      @api_client.describe
    end
  end

  def prefix_to_name
    if @prefix_to_name.nil? || !@prefix_to_name.respond_to?(:contains)
      @prefix_to_name = {}
      org_describe.each do |z|
        @prefix_to_name.store(z.keyPrefix, z.name)
      end
    end
    return @prefix_to_name
  end

  def npsp_managed_obj_names()
    @npsp_managed_obj_names ||= org_describe.select{|x| x.name =~ /^np.*__.*__c/i}.map{|y| y.name}
  end

  def true_object_name(handle) #either an ID or a string name
    from_id = prefix_to_name[handle[0..2]]
    from_name = obj_names_without_namespace[handle]
    if !from_name.nil? || !from_id.nil?
      return from_name if from_id.nil?
      return from_id if from_name.nil?
    end
    return 'invalid'
  end

  def obj_names_without_namespace
    if @obj_names_without_namespace.nil? || !@obj_names_without_namespace.respond_to?(:contains)
      @obj_names_without_namespace = {}
      org_describe.each do |z|
        @obj_names_without_namespace.store(z.name.split("__",2).last, z.name)
      end
    end
    @obj_names_without_namespace
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
    delete_by_id(obj_id)
  end

  def delete_by_id(obj_id)
    api_client do
      @api_client.destroy(true_object_name(obj_id), obj_id)
    end

  end

  def delete_all(id)
    api_client do
      id.each(&:destroy)
    end
  end

  def method_missing(method_called, *args, &block)
    breakdown = method_called.to_s.split('_')
    obj_type = breakdown.last.capitalize

    case method_called.to_s
      when /^delete_all_/
        delete_all *args
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

