require 'test_helper'

class CalculatorTest < ActiveSupport::TestCase  
  setup do
    dump_database
    
    hqmf_file = "test/fixtures/measure-defs/0002/0002.xml"
    value_set_file = "test/fixtures/measure-defs/0002/0002.xls"
    
    Measures::Loader.load(hqmf_file, @user, nil, true, nil, value_set_file)
    Measure.all.count.must_equal 1
    
    @measure = Measure.all.first
    @patient = FactoryGirl.create(:record)
    @measure.records << @patient
  end

  test "test calculate" do
    Measures::Calculator.calculate

    affected_collections = ["bundles", "draft_measures", "measures", "patient_cache", "query_cache"]
    affected_collections.each {|collection| assert_equal MONGO_DB[collection].find({}).count(), 1}
    assert_equal MONGO_DB["system.js"].find({}).count(), Measures::Calculator.library_functions.size

    patient_result = MONGO_DB["patient_cache"].find({}).first["value"]
    assert_equal patient_result["population"], 1
    assert_equal patient_result["denominator"], 0
    assert_equal patient_result["numerator"], 0
    assert_equal patient_result["denexcep"], 0
    assert_equal patient_result["exclusions"], 0
    assert_equal patient_result["antinumerator"], 0
  end

  test "library functions" do
    library_functions = Measures::Calculator.library_functions
    
    refute_nil library_functions["map_reduce_utils"]
    refute_nil library_functions["hqmf_utils"]
    
    assert library_functions["map_reduce_utils"].length > 0
    assert library_functions["hqmf_utils"].length > 0
  end

  test "measure json" do
    measure_json = Measures::Calculator.measure_json(@measure.measure_id)
    expected_keys = [:id,:nqf_id,:hqmf_id,:hqmf_set_id,:hqmf_version_number,:endorser,:name,:description,:type,:category,:steward,:population,:denominator,:numerator,:exclusions,:map_fn,:population_ids,:data_criteria,:oids]
    required_keys = [:id,:name,:description,:category,:population,:denominator,:numerator,:map_fn,:category,:data_criteria,:oids]

    expected_keys.each {|key| assert measure_json.keys.include? key}
    measure_json.keys.size.must_equal expected_keys.size
    required_keys.each {|key| refute_nil measure_json[key]}

    measure_json[:nqf_id].must_equal "0002"
    measure_json[:hqmf_id].must_equal '8A4D92B2-3946-CDAE-0139-77F580AE6690'
    measure_json[:id].must_equal '8A4D92B2-3946-CDAE-0139-77F580AE6690'
  end

  test "measure codes" do
    measure_codes = Measures::Calculator.measure_codes(@measure)

    measure_codes.length.must_equal 26
    expected = ["2.16.840.1.113883.3.464.0001.231","2.16.840.1.113883.3.464.0001.250","2.16.840.1.113883.3.464.0001.369","2.16.840.1.113883.3.464.0001.373","2.16.840.1.113883.3.464.0001.157","2.16.840.1.113883.3.464.0001.172","2.16.840.1.113883.3.560.100.4","2.16.840.1.113883.3.464.0001.45",
     "2.16.840.1.113883.3.464.0001.48","2.16.840.1.113883.3.464.0001.50","2.16.840.1.113883.3.464.0001.246","2.16.840.1.113883.3.464.0001.247","2.16.840.1.113883.3.464.0001.249","2.16.840.1.113883.3.464.0001.251","2.16.840.1.113883.3.464.0001.252","2.16.840.1.113883.3.464.0001.302",
     "2.16.840.1.113883.3.464.0001.308","2.16.840.1.113883.3.464.0001.341","2.16.840.1.113883.3.464.0001.368","2.16.840.1.113883.3.464.0001.371","2.16.840.1.113883.3.464.0001.385","2.16.840.1.113883.3.464.0001.406","2.16.840.1.113883.3.464.0001.372",
     "2.16.840.1.113883.3.464.0001.397","2.16.840.1.113883.3.464.0001.408","2.16.840.1.113883.3.464.0001.409"]
    measure_codes.keys.sort.must_equal expected.sort
    measure_codes["2.16.840.1.113883.3.464.0001.250"].keys.must_equal ["CPT", "LOINC", "SNOMED-CT"]
    measure_codes["2.16.840.1.113883.3.464.0001.250"]["CPT"].length.must_equal 8
    measure_codes["2.16.840.1.113883.3.464.0001.250"]["LOINC"].length.must_equal 11
    measure_codes["2.16.840.1.113883.3.464.0001.250"]["SNOMED-CT"].length.must_equal 5
  end

  test "measure js" do
    # Testing for code that will execute properly is included in the calculate test.
    measure_js = Measures::Calculator.measure_js(@measure, 0)
    assert_not_nil measure_js
  end


  test "execution logic" do
    # Testing for code that will execute properly is included in the calculate test.
    execution_logic = Measures::Calculator.execution_logic(@measure, 0, false)
    assert_not_nil execution_logic
  end

  test "check disable logger" do
    APP_CONFIG["disable_logging"] = true
    logger = Measures::Calculator.check_disable_logger
    assert logger.include? "Logger.enabled = false"

    APP_CONFIG["disable_logging"] = false
    logger = Measures::Calculator.check_disable_logger
    assert_empty logger
  end
end