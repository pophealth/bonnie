
require 'test_helper'
include Devise::TestHelpers

class MeasureBuilderControllerTest < ActionController::TestCase
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