require 'test_helper'
include Devise::TestHelpers

class MeasuresControllerTest < ActionController::TestCase
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

  teardown do
    test_source_path = File.join('.','tmp','export_test')
    FileUtils.rm_r test_source_path if File.exists?(test_source_path)
    test_source_path = File.join(".", "db", "measures")
    set_test_source_path(test_source_path)
  end

  test "measure index" do
    get :index
    returned_measures = assigns[:measures]

    assert_response :success
    assert_equal returned_measures.size, 1
    assert_equal @measure, returned_measures.first
  end

  test "measure index multiple measures" do
    @measure2 = FactoryGirl.create(:measure)
    @measure2.user = @user
    @measure2.save

    get :index
    assert_response :success
    assert_equal assigns[:measures].size, 2
  end

  test "show measure" do
    get :show, id: @measure.id
    shown_measure = assigns[:measure]

    assert_response :success
    assert_equal shown_measure, @measure
  end

  test "show nqf" do
    get :show_nqf, id: @measure.id
    assert_not_nil assigns[:contents]
  end

  test "publish measure" do
    get :publish, id: @measure.id
    shown_measure = assigns[:measure]

    assert_response :success
    assert shown_measure.published
    refute_nil shown_measure.publish_date
    refute_nil shown_measure.version
  end

  test "get all published measures" do
    get :published
    assert_empty assigns[:measures]

    get :publish, id: @measure.id
    get :published

    assert_response :success
    assert_equal assigns[:measures].size, 1
  end

  test "new measure" do
    get :new

    assert_response :success
    refute_nil assigns[:measure]
  end

  test "edit measure" do
    get :edit, id: @measure.id

    assert_response :success
    assert_equal assigns[:measure], @measure
  end

  test "update measure" do
    updated_title = "A different title"
    updates = { id: @measure.id, measure: { title: "A different title" } }

    post :update, updates
    updated_measure = assigns[:measure]

    assert_redirected_to measure_url(updated_measure)
    assert_equal updated_measure.title, updated_title
  end

  test "destroy measure and redirect to index" do
    assert_equal Measure.all.size, 1
    post :destroy, id: @measure.id
    assert_equal Measure.all.size, 0
  end

  test "definition" do
    get :definition, :format => :json, id: @measure.id
    definition = JSON.parse(response.body)

    expected_definition = ["exclusions", "numerator", "denominator", "population"]
    expected_definition.each {|population| assert_not_nil definition[population]}
  end

  test "population_criteria_definition" do
    get :population_criteria_definition, :format => :json, id: @measure.id, key: "NUMER"
    definition = JSON.parse(response.body)

    assert_not_nil definition["items"]
  end

  test "export" do
    get :export

    assert_response :success
    assert response.header["Content-Disposition"].include? "bundle"
  end


end
