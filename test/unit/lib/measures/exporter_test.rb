require 'test_helper'

class ExporterTest < ActiveSupport::TestCase  
  setup do
    dump_database
    
    hqmf_file = "test/fixtures/measure-defs/0002/0002.xml"
    value_set_file = "test/fixtures/measure-defs/0002/0002.xls"
    
    Measures::Loader.load(hqmf_file, value_set_file, @user)
    Measure.all.count.must_equal 1
    
    @measure = Measure.all.first
    @patient = FactoryGirl.create(:record)
    @measure.records << @patient
  end

  test "test export bundle" do
    file = Tempfile.new(['bundle', '.zip'])
    measures = [@measure]

    Measures::Calculator.calculate(measures)
        
    entries = []
    bundle = Measures::Exporter.export_bundle(measures, false)
    Zip::ZipFile.open(bundle.path) do |zip|
      zip.entries.each do |entry|
        entries << entry.name
        assert entry.size > 0
      end
    end

    patient_name = "#{@patient.first}_#{@patient.last}"
    expected = ["library_functions/map_reduce_utils.js",
      "library_functions/underscore_min.js",
      "library_functions/hqmf_utils.js",
      "./bundle.json",
      "measures/ep/0002.json",
      "patients/ep/c32/#{patient_name}.xml",
      "patients/ep/ccda/#{patient_name}.xml",
      "patients/ep/ccr/#{patient_name}.xml",
      "patients/ep/json/#{patient_name}.json",
      "patients/ep/html/#{patient_name}.html",
      "results/by_patient.json",
      "results/by_measure.json"]
    
    entries.size.must_equal expected.size
    entries.each {|entry| assert expected.include? entry}
    expected.each {|entry| assert entries.include? entry}
  end

  test "test bundle json" do
    library_functions = Measures::Calculator.library_functions.keys
    patient_ids = ["123", "456", "789"]
    measure_ids = ["0001a", "0001b", "0002"]

    bundle_json = Measures::Exporter.bundle_json(patient_ids, measure_ids, library_functions)
    bundle_json = JSON.parse(bundle_json.values.first)

    bundle_json["title"].must_equal APP_CONFIG["measures"]["title"]
    bundle_json["version"].must_equal APP_CONFIG["measures"]["version"]
    bundle_json["license"].must_equal APP_CONFIG["measures"]["license"]
    bundle_json["extensions"].must_equal library_functions
    bundle_json["measures"].must_equal measure_ids
    bundle_json["patients"].must_equal patient_ids
  end

  test "test bundle library functions" do
    functions = [
      {"fun1" => "function() {return 1;}"},
      {"fun2" => "function() {return 2;}"},
      {"fun3" => "function() {return 3;}"}
    ]
    bundled_functions = Measures::Exporter.bundle_library_functions(functions)

    assert_equal functions.size, bundled_functions.size
    functions.each do |name, contents|
      assert bundled_functions.include? "#{name}.js"
      assert_equal bundled_functions["#{name}.js"], contents
    end
  end

  test "test bundle measure" do
    bundled_measure = Measures::Exporter.bundle_measure(@measure)

    # assert_equal 
    # expected_keys = [:id,:nqf_id,:hqmf_id,:hqmf_set_id,:hqmf_version_number,:endorser,:name,:description,:type,:category,:steward,:population,:denominator,:numerator,:exclusions,:map_fn,:population_ids,:oids,:value_sets,:data_criteria]
    # required_keys = [:id,:name,:description,:category,:population,:denominator,:numerator,:map_fn]
    
    # expected_keys.each {|key| assert measure_json.keys.include? key}
    # measure_json.keys.size.must_equal expected_keys.size
    # required_keys.each {|key| refute_nil measure_json[key]}

    # measure_json[:nqf_id].must_equal "0002"
    # measure_json[:hqmf_id].must_equal '8A4D92B2-3946-CDAE-0139-77F580AE6690'
    # measure_json[:id].must_equal '8A4D92B2-3946-CDAE-0139-77F580AE6690'    

    # measure_json = JSON.pretty_generate(measure.as_json(:except => [ '_id' ]), max_nesting: 250)

    #   {
    #     "#{measure['nqf_id']}#{measure['sub_id']}.json" => measure_json
    #   }
  end

  test "test bundle source" do
    pending "I'm just a lonely lil' test"
  end

  test "test bundle results" do
    pending "I'm just a lonely lil' test"
  end

  test "test bundle patient" do
    pending "I'm just a lonely lil' test"
  end

  test "test zip content" do
    pending "I'm just a lonely lil' test"
  end
end