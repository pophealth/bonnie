ENV["RAILS_ENV"] = "test"
# require_relative "./simplecov"
require File.expand_path('../../config/environment', __FILE__)

require 'rubygems'

require 'rails/test_help'

require 'minitest/autorun'
require 'minitest/unit'

require 'factory_girl'
FactoryGirl.find_definitions

require 'rake'
require 'turn'

class ActiveSupport::TestCase
  def dump_database
    Mongoid.session(:default).collections.each do |collection|
      collection.drop unless collection.name.include?('system.')
    end
    MONGO_DB.command(getLastError: 1)
  end

  def raw_post(action, body, parameters = nil, session = nil, flash = nil)
    @request.env['RAW_POST_DATA'] = body
    post(action, parameters, session, flash)
  end
  
  def basic_signin(user)
     @request.env['HTTP_AUTHORIZATION'] = "Basic #{ActiveSupport::Base64.encode64("#{user.username}:#{user.password}")}"
  end

  def collection_fixtures(*collection_names)
    collection_names.each do |collection|
      MONGO_DB[collection].drop
      Dir.glob(File.join(Rails.root, 'test', 'fixtures', collection, '*.json')).each do |json_fixture_file|
        fixture_json = JSON.parse(File.read(json_fixture_file))
          MONGO_DB[collection].save(fixture_json)
      end
    end
    MONGO_DB.command(getLastError: 1)
  end
  
  def hash_includes?(expected, actual)
    if (actual.is_a? Hash)
      (expected.keys & actual.keys).all? {|k| expected[k] == actual[k]}
    elsif (actual.is_a? Array )
      actual.any? {|value| hash_includes? expected, value}
    else 
      false
    end
  end
  
  def assert_query_results_equal(factory_result, result)
    factory_result.each do |key, value|
      assert_equal value, result[key] unless key == '_id'
    end
  end
  
  def expose_tempfile(fixture)
    class << fixture
      attr_reader :tempfile
    end
    fixture
  end

  def set_test_source_path(path)
    Measures::Loader.send(:remove_const, 'SOURCE_PATH') if Measures::Loader.const_defined?('SOURCE_PATH')
    Measures::Loader.const_set('SOURCE_PATH', path)
  end

end

class ActionController::TestCase
  include Devise::TestHelpers
end

