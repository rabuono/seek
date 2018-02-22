module ApiTestHelper
  include AuthenticatedTestHelper

  def admin_login
    admin = Factory.create(:admin)
    @current_person = admin
    @current_user = admin.user
    # log in
    post '/session', login: admin.user.login, password: ('0' * User::MIN_PASSWORD_LENGTH)
  end

  def user_login(person)
    @current_person = person
    @current_user = person.user
    post '/session', login: person.user.login, password: ('0' * User::MIN_PASSWORD_LENGTH)
  end

  def self.template_dir
    File.join(Rails.root, 'test', 'fixtures',
              'files', 'json', 'templates')
  end

  def self.render_erb (path, locals)
    content = File.read(File.join(ApiTestHelper.template_dir, path))
    template = ERB.new(content)
    h = locals
    h[:r] = method(:render_erb)
    namespace = OpenStruct.new(h)
    template.result(namespace.instance_eval {binding})
  end

  def load_template(erb_file, hash)
    template_file = File.join(ApiTestHelper.template_dir, erb_file)
    template = ERB.new(File.read(template_file))
    namespace = OpenStruct.new(hash)
    json_obj = JSON.parse(template.result(namespace.instance_eval { binding }))
    return json_obj
  end

  def load_patch_template(hash)
    patch_file = File.join(Rails.root, 'test', 'fixtures',
                                     'files', 'json', 'templates', "patch_#{@clz}.json.erb")
    the_patch = ERB.new(File.read(patch_file))
    namespace = OpenStruct.new(hash)
    to_patch = JSON.parse(the_patch.result(namespace.instance_eval { binding }))
    return to_patch
  end

  # def check_attr_content(to_post, action)
  #   #check some of the content, h = the response hash after the post/patch action
  #   h = JSON.parse(response.body)
  #   h['data']['attributes'].delete("mbox_sha1sum")
  #   h['data']['attributes'].delete("avatar")
  #   h['data']['attributes'].each do |key, value|
  #     next if (to_post['data']['attributes'][key].nil? && action=="patch")
  #     if value.nil?
  #       assert_nil to_post['data']['attributes'][key]
  #     elsif value.kind_of?(Array)
  #       assert_equal value, to_post['data']['attributes'][key].sort!
  #     else
  #       assert_equal value, to_post['data']['attributes'][key]
  #     end
  #   end
  # end

  # def check_relationships_content(m, action)
  #   @to_post['data']['relationships'].each do |key, value|
  #     assert_equal value, h['data']['relationships'][key]
  #   end
  # end ("#{m}_#{clz}").to_sym

  def test_create
    begin
      create_post_values
    rescue NoMethodError
    end

    ['min','max'].each do |m|
      @to_post = load_template("post_#{m}_#{@clz}.json.erb", @post_values[m])

      puts "to_post", @to_post

      if @to_post.blank?
        skip
      end

      # debug note: responds with redirect 302 if not really logged in.. could happen if database resets and has no users
      assert_difference("#{@clz.classify}.count") do
        post "/#{@plural_clz}.json", @to_post
        assert_response :success
      end

      # check some of the content
      h = JSON.parse(response.body)

      hash_comparison(@to_post['data']['attributes'], h['data']['attributes'])
      hash_comparison(populate_extra_attributes, h['data']['attributes'])

      hash_comparison(@to_post['data']['relationships'], h['data']['relationships'])
      hash_comparison(populate_extra_relationships, h['data']['relationships'])
    end
  end

  def test_should_delete_object
    begin
      obj = Factory(("#{@clz}").to_sym, contributor: @current_person)
    rescue NoMethodError
      obj = Factory(("#{@clz}").to_sym)
    end
    assert_difference ("#{@clz.classify.constantize}.count"), -1 do
      delete "/#{@plural_clz}/#{obj.id}.json"
      assert_response :success
    end
    get "/#{@plural_clz}/#{obj.id}.json"
    assert_response :not_found
  end

  def test_create_should_error_on_given_id
    post_clone = JSON.parse(JSON.generate(@to_post))
    post_clone['data']['id'] = '100000000'

    assert_no_difference ("#{@clz.classify.constantize}.count") do
      post "/#{@plural_clz}.json", post_clone
      assert_response :unprocessable_entity
      assert_match "A POST request is not allowed to specify an id", response.body
    end
  end

  def test_create_should_error_on_wrong_type
    post_clone = JSON.parse(JSON.generate(@to_post))
    post_clone['data']['type'] = 'wrong'

    assert_no_difference ("#{@clz.classify.constantize}.count") do
      post "/#{@plural_clz}.json", post_clone
      assert_response :unprocessable_entity
      assert_match "The specified data:type does not match the URL's object (#{post_clone['data']['type']} vs. #{@plural_clz})", response.body
    end
  end

  def test_create_should_error_on_missing_type
    post_clone = JSON.parse(JSON.generate(@to_post))
    post_clone['data'].delete('type')

    assert_no_difference ("#{@clz.classify.constantize}.count") do
      post "/#{@plural_clz}.json", post_clone
      assert_response :unprocessable_entity
      assert_match "A POST/PUT request must specify a data:type", response.body
    end
  end

  def test_update

    #fetch original object
    obj_id = @to_patch['data']['id']
    get "/#{@plural_clz}/#{obj.id}.json"
    assert_response :success
    original = JSON.parse(response.body)

    #update request
    assert_no_difference( "#{@clz.capitalize}.count") do
      patch "/#{@plural_clz}/#{obj_id}.json", @to_patch
     # puts response.body
      assert_response :success
    end

    h = JSON.parse(response.body)

    # Check the changed attributes and relationships
    if @to_patch['data'].key?('attributes')
      hash_comparison(@to_patch['data']['attributes'], h['data']['attributes'])
    end

    if @to_patch['data'].key?('relationships')
      hash_comparison(@to_patch['data']['relationships'], h['data']['relationships'])
    end

    # Check the original, unchanged attributes and relationships
    if original['data'].key?('attributes') && @to_patch['data'].key?('attributes')
      original_attributes = original['data']['attributes'].except(@to_patch['data']['attributes'].keys)
      hash_comparison(original_attributes, h['data']['attributes'])
    end

    if original['data'].key?('relationships') && @to_patch['data'].key?('relationships')
      original_relationships = original['data']['relationships'].except(@to_patch['data']['relationships'].keys)
      hash_comparison(original_relationships, h['data']['relationships'])
    end
  end

  def test_update_should_error_on_wrong_id
    obj = Factory(("#{@clz}").to_sym)

    to_patch = load_patch_template(id: '100000000')

    assert_no_difference ("#{@clz.classify.constantize}.count") do
      put "/#{@plural_clz}/#{obj.id}.json", to_patch
      assert_response :unprocessable_entity
      assert_match "id specified by the PUT request does not match object-id in the JSON input", response.body
    end
  end

  def test_update_should_error_on_wrong_type
    obj = Factory(("#{@clz}").to_sym)
    to_patch = load_patch_template({})
    to_patch['data']['type'] = 'wrong'

    assert_no_difference ("#{@clz.classify.constantize}.count") do
      put "/#{@plural_clz}/#{obj.id}.json", to_patch
      assert_response :unprocessable_entity
      assert_match "The specified data:type does not match the URL's object (#{to_patch['data']['type']} vs. #{@plural_clz})", response.body
    end
  end

  def test_update_should_error_on_missing_type
    obj = Factory(("#{@clz}").to_sym)
    to_patch = load_patch_template({})
    to_patch['data'].delete('type')

    assert_no_difference ("#{@clz.classify.constantize}.count") do
      put "/#{@plural_clz}/#{obj.id}.json", to_patch
      assert_response :unprocessable_entity
      assert_match "A POST/PUT request must specify a data:type", response.body
    end
  end

private

  ##
  # Compare `result` Hash against `source`.
  def hash_comparison(source, result)
    source.each do |key, value|
      deep_comparison(value, result[key], key)
    end
  end

  ##
  # Compares `result` against `source`. If `source` is a Hash, compare each each key/value pair with that in `result`.
  # `key` is used to generate meaningful failure messages if the assertion fails.
  def deep_comparison(source, result, key)
    if source.is_a?(Hash)
      source.each do |sub_key, sub_value|
        actual = result.try(:[], sub_key)
        assert_equal sub_value, actual, "Expected #{key}[#{sub_key}] to be `#{sub_value}` but was `#{actual}`"
      end
    else
      assert_equal source, result, "Expected #{key} to be `#{source}` but was `#{result}`"
    end
  end
end

