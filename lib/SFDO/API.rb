require 'SFDO/API/version'
require 'pry'

module SfdoAPI

  def api_client
    if ENV['SF_ACCESS_TOKEN'] and ENV['SF_INSTANCE_URL']
      @api_client ||= Restforce.new(oauth_token: ENV['SF_ACCESS_TOKEN'],
                             instance_url: ENV['SF_INSTANCE_URL'],
                             api_version: '32.0')
      yield
    else
    @api_client ||= Restforce.new api_version: '32.0',
                                  refresh_token: ENV['SF_REFRESH_TOKEN'],
                                  client_id: ENV['SF_CLIENT_KEY'],
                                  client_secret: ENV['SF_CLIENT_SECRET']
    yield
    end
  end
  
  def create(type, obj_hash)
    type = true_object_name(type)
    if is_valid_obj_hash?(type, obj_hash, @fields_acceptibly_nil)
      obj_id = api_client do
        @api_client.create! type, obj_hash
      end
    end
    obj_id
  end

  def select_api(query)
    if query.match /where/i
      obj_name = query[/(?<=from )(.*)(?= where)|$/i]
    else
      obj_name = query[/(?<=from )(.*)$/i]
    end

    real_obj_name = true_object_name(obj_name)

    query = query.gsub(obj_name, real_obj_name)

   results = api_client do
     @api_client.query query
   end
    results
  end

  def is_valid_obj_hash?(object_name, obj_hash, fields_acceptibly_nil)
    #TODO Take incoming field names;parse out namespace/__c values; get true namespace for fields also
    #TODO We do it from here because this is the only place we know about fields on objects
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
    if @org_description.nil? || !@org_description.respond_to?(:contains)
      @org_description = api_client do
        @api_client.describe
      end
    end
    return @org_description
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

  def true_object_name(handle) #either an ID or a string name
    handle = (handle.end_with?("__c") || handle.end_with?("__r")) ? handle[0...-3] : handle
    from_id = prefix_to_name[handle[0..2]]
    from_name = obj_names_without_custom_additions[handle]
    if !from_name.nil? || !from_id.nil?
      return from_name if from_id.nil?
      return from_id if from_name.nil?
    end
    return 'Unable to find object. Be sure to call SFDO-API without preceding namespace or following __c or __r'
  end

  def obj_names_without_custom_additions
    if @obj_names_without_custom_additions.nil? || !@obj_names_without_custom_additions.respond_to?(:contains)
      @obj_names_without_custom_additions = {}
      org_describe.each do |z|
        tmp_var = z.name.split "__"
        save = ""
        case tmp_var.size
          when 2
            save = tmp_var.first
          when 3
            save = tmp_var[1]
          else
            save = tmp_var.last
        end
        @obj_names_without_custom_additions.store(save, z.name)
      end
    end
    @obj_names_without_custom_additions
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

  def update_api(obj)
    api_client do
      @api_client.update(obj.attributes.type, obj)
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
        create obj_type, *args
      when /^select_api/
        select_api *args
      else
        super.method_missing
    end
  end

end
# INCLUDE HERE RATHER THAN IN THE PRODUCT-SPECIFIC CODE USING THIS GEM
include SfdoAPI
