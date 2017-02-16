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
    true_fields = {}

    type = true_object_name(type)
    obj_mash = Hashie::Mash.new obj_hash
    obj_mash.map { |x, y| true_fields.store(true_field_name(x, type),y) }

    binding.pry

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

    #GET TRUE OBJECT NAME BEFORE GETTING TRUE FIELD NAMES
    real_obj_name = true_object_name(obj_name)

    # REMOVE NEWLINES IF ANY
    query = query.gsub(/\n/,' ')
    # REMOVE EXTRA SPACES
    query = query.gsub(/\s{2,}/, ' ')
    # GET FIELDS ONLY
    fields_array = query.split(' from ').first.scan /\w*\s*\s([a-zA-Z0-9_]*)/

    fields_array.each do |field|
      puts "this is field " + field.to_s
      real_field = true_field_name(field, real_obj_name)

      #HANDLE THE OUTPUT FROM true_field_name NOW THAT IT WORKS PROPERLY

      if obj_name != real_obj_name
        query = query.gsub(/\b#{obj_name}\b/, real_obj_name)
      end

      if field[0] != real_field
        query = query.gsub(field[0], real_field)
      end

    end
   results = api_client do
     @api_client.query query
   end
    results
  end

  def is_valid_obj_hash?(object_name, obj_hash, fields_acceptibly_nil)
    #TODO Take incoming field names;parse out namespace/__c values; get true namespace for fields also
    #TODO We do it from here because this is the only place we know about fields on objects
    required_fields = get_required_fields_on_object(object_name).map(&:fieldName)
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

  def true_field_name(field, obj)
    puts "start of true_field_name"

    # See if we've done an object describe on the object
    # If so, return the fields for the object
    # Otherwise do an object describe, save the object description and return the fields with their real names
    @full_describe = {} if @full_describe.nil?

    if @full_describe[obj].nil?

      object_description = get_object_describe(obj)
      fields = object_description.map do |f|
        substituted = f.fieldName.gsub(/\A.*?__/,'').gsub(/__c\z/,'')
        output =  {substituted => f.fieldName}
      end
      #fields.reduce Hash.new, :merge
      @full_describe[obj] = fields.reduce({}, :merge)
    end
    # RETURN THE REAL NAME FROM OUR HASH OF INPUT TO REAL NAMES
    @full_describe[obj][field[0]]
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

  def get_required_fields_on_object(obj_name)
    binding.pry

    @full_describe = {} if @full_describe.nil?

    # THE CODE BELOW IS CALLING get_object_describe BUT IT'S NOT AN OBJECT IT'S A FIELD

    if @full_describe[obj_name].nil?
      @full_describe[obj_name] = get_object_describe(obj_name)
    end

    #MAKE THE CODE BELOW INTO A LOOP TO IGNORE THE 'Id' FIELD/PROPERTY
    @full_describe[obj_name].select(&:required)
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
        return required
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
