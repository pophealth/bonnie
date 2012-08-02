require 'test_helper'
include Devise::TestHelpers

class MeasuresControllerTest < ActionController::TestCase
  setup do
    dump_database

    @user = FactoryGirl.create(:user)
    @measure = FactoryGirl.create(:measure)
    @measure.user = @user
    @measure.save

    sign_in @user
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

  test "create measure with uploaded hqmf 2" do
    Measure.delete_all

    hqmf_file = expose_tempfile(fixture_file_upload("test/fixtures/measure-defs/0043/0043.xml", "text/xml"))
    value_set_file = expose_tempfile(fixture_file_upload("test/fixtures/measure-defs/0043/0043.xls", "application/vnd.ms-excel"))
    html_file = expose_tempfile(fixture_file_upload("test/fixtures/measure-defs/0043/0043.html", "text/html"))
    post :create, { measure: { hqmf: hqmf_file, value_sets: value_set_file, html: html_file} }
    created_measure = Measure.all.first

    assert_equal Measure.all.size, 1
    refute_nil created_measure.population_criteria
    refute_nil created_measure.data_criteria
    refute_nil created_measure.measure_period

    assert_redirected_to edit_measure_url(created_measure)
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

  test "definition returns stage one JSON" do

  end

  test "upsert data criteria" do

    temporal_references = [
      {'type' => 'during', 'reference' => 'measurePeriod'},
      {'type' => 'SBS', 'reference' => 'criteria_a'}
    ]

    subset_operators = [
      {
        'type' => 'MAX',
        'range' => {
          'type' => 'IVL_PQ',
          'high' => {
            'type' => 'PQ',
            'value' => 23,
            'unit' => 'units',
            'inclusive' => true
          },
          'low' => {
            'type' => 'PQ',
            'value' => 23,
            'unit' => 'units',
            'inclusive' => true
          }
        }
      }
    ]

    value = {
        'type' => 'IVL_PQ',
        'low' => {
          'type' => 'PQ',
          'value' => 1,
          'unit' => 'unit'
        },
        'high' => {
          'type' => 'PQ',
          'value' => 1,
          'unit' => 'unit'
        }
      }

    data_criteria = {
      'title' => 'title',
      'description' => 'description',
      'code_list_id' => 'code_list_id',
      'status' => 'active',
      'title' => 'title',
      'code_list_id' => 'clid',
      'property' => 'property',
      'children_criteria' => ['a', 'b', 'c'],
    }

    post :upsert_criteria, data_criteria.merge({
      'id' => @measure._id,
      'criteria_id' => 'id',
      'temporal_references' => JSON.generate(temporal_references),
      'subset_operators' => JSON.generate(subset_operators),
      'category' => 'symptom',
      'subcategory' => 'active',
      'value_type' => 'IVL_PQ',
      'value' => value.to_json
    })

    assert_response :success
    m = Measure.find(@measure._id)

    refute_nil m.data_criteria

    assert_equal m.data_criteria['id']['id'], 'id'
    assert_equal m.data_criteria['id']['type'], 'symptoms'
    assert_equal m.data_criteria['id']['qds_data_type'], 'symptom'
    assert_equal m.data_criteria['id']['standard_category'], 'symptom'
    assert_equal m.data_criteria['id']['status'], 'active'
    assert_equal m.data_criteria['id']['temporal_references'], temporal_references
    assert_equal m.data_criteria['id']['subset_operators'], subset_operators
    assert_equal m.data_criteria['id']['value'], value

    data_criteria.each {|k,v|
      assert_equal m.data_criteria['id'][k], v
    }

  end
end
