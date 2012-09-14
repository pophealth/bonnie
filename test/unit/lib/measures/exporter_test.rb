require 'test_helper'

class ExporterTest < ActiveSupport::TestCase
  
  setup do
    dump_database
    
    hqmf_file = "test/fixtures/measure-defs/0002/0002.xml"
    value_set_file = "test/fixtures/measure-defs/0002/0002.xls"
    
    Measures::Loader.load(hqmf_file, value_set_file, @user)
    Measure.all.count.must_equal 1
    
    @measure = Measure.all.first
  end
  
  test "test exporting measures" do
     file = Tempfile.new(['bundle', '.zip'])
     measures = { "ep" => [@measure] }
     patients = { "ep" => [Record.all.first]}

     entries = []
     bundle = Measures::Exporter.export_bundle(measures, patients)
     Zip::ZipFile.open(bundle.path) do |zipfile|
       zipfile.entries.each do |entry|
         entries << entry.name
         assert entry.size > 0
       end
     end
     
     expected = ["measures/libraries/map_reduce_utils.js",
      "measures/libraries/underscore_min.js",
      "measures/libraries/hqmf_utils.js",
      "measures/bundle.json",
      "measures/json/0002.json"]
      
     entries.size.must_equal expected.size
     entries.each {|entry| assert expected.include? entry}
     expected.each {|entry| assert entries.include? entry}
  end


  test "test library functions" do
    library_functions = Measures::Exporter.library_functions
    
    refute_nil library_functions["map_reduce_utils"]
    refute_nil library_functions["underscore_min"]
    refute_nil library_functions["hqmf_utils"]
    
    assert library_functions["map_reduce_utils"].length > 0
    assert library_functions["underscore_min"].length > 0
    assert library_functions["hqmf_utils"].length > 0
    
  end

  test "test measure json" do
    measure_json = Measures::Exporter.measure_json(@measure.measure_id)
    expected_keys = [:id,:nqf_id,:hqmf_id,:hqmf_set_id,:hqmf_version_number,:endorser,:name,:description,:category,:steward,:population,:denominator,:numerator,:exclusions,:map_fn,:measure,:population_ids]
    required_keys = [:id, :name,:description,:category,:population,:denominator,:numerator,:map_fn,:measure]
    
    expected_keys.each {|key| assert measure_json.keys.include? key}
    measure_json.keys.size.must_equal expected_keys.size
    required_keys.each {|key| refute_nil measure_json[key]}
    
    measure_json[:measure].size.must_equal 5
    measure_json[:nqf_id].must_equal "0002"
    measure_json[:hqmf_id].must_equal '2E679CD2-3FEC-4A75-A75A-61403E5EFEE8'
    measure_json[:id].must_equal '2E679CD2-3FEC-4A75-A75A-61403E5EFEE8'
    
  end
  
  test "test bundle json" do
    library_functions = Measures::Exporter.library_functions.keys
    patient_ids = ["123", "456", "789"]
    measure_ids = ["0001a", "0001b", "0002"]
    
    bundle_json = Measures::Exporter.bundle_json(patient_ids, measure_ids, library_functions)

    bundle_json[:title].must_equal APP_CONFIG["measures"]["title"]
    bundle_json[:version].must_equal APP_CONFIG["measures"]["version"]
    bundle_json[:license].must_equal APP_CONFIG["measures"]["license"]
    bundle_json[:library_functions].must_equal library_functions
    bundle_json[:measure_ids].must_equal measure_ids
    bundle_json[:patient_ids].must_equal patient_ids
  end

  test "test measure codes" do
    measure_codes = Measures::Exporter.measure_codes(@measure)
    
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
end