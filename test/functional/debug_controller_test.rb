
require 'test_helper'
include Devise::TestHelpers

class DebugControllerTest < ActionController::TestCase
  setup do
    dump_database

    @user = FactoryGirl.create(:user)

    test_source_path = File.join('.','tmp','export_test')
    set_test_source_path(test_source_path)
    FileUtils.mkdir_p test_source_path

    hqmf_file = "test/fixtures/measure-defs/0002/0002.xml"
    value_set_file = "test/fixtures/measure-defs/0002/0002.xls"
    html_file = "test/fixtures/measure-defs/0002/0002.html"
    Measures::Loader.load(hqmf_file, @user, html_file, true, nil, nil, nil, value_set_file)
    
    @measure = Measure.where(hqmf_id: "8A4D92B2-3946-CDAE-0139-77F580AE6690").first
    @measure.user = @user

    @patient = FactoryGirl.create(:record)
    @measure.records << @patient

    sign_in @user
  end

  test "debug libraries" do
    get :libraries, format: 'js'

    assert_response :success
    assert assigns["libraries"].size > 0
  end

end