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

  test "export bundle" do
    file = Tempfile.new(['bundle', '.zip'])
    measures = [@measure]

    Measures::Calculator.calculate(false,measures)
        
    entries = []
    bundle = Measures::Exporter.export_bundle(measures, nil, false)
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
      "sources/ep/0002/0002.html",
      "sources/ep/0002/hqmf1.xml",
      "sources/ep/0002/hqmf2.xml",
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

  test "bundle json" do
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

  test "bundle library functions" do
    functions = {"fun1" => "function() {return 1;}",
      "fun2" => "function() {return 2;}",
      "fun3" => "function() {return 3;}"
    }
    bundled_functions = Measures::Exporter.bundle_library_functions(functions)

    assert_equal functions.size, bundled_functions.size
    assert_equal bundled_functions["fun1.js"], functions["fun1"]
    assert_equal bundled_functions["fun2.js"], functions["fun2"]
    assert_equal bundled_functions["fun3.js"], functions["fun3"]
  end

  test "bundle measure" do
    Measures::Calculator.calculate
    measure = MONGO_DB["measures"].find({}).first
    bundled_measure = Measures::Exporter.bundle_measure(measure)

    assert_equal bundled_measure.size, 1
    assert_equal bundled_measure.keys.first, "0002.json"
  end

  test "bundle sources" do
    source_dir = File.join("test", "fixtures", "export", "measure-sources")
    bundled_sources = Measures::Exporter.bundle_sources(@measure, source_dir)

    assert_equal bundled_sources.size, 3

    source_dir = File.join(source_dir, @measure.hqmf_id)
    assert_not_nil bundled_sources[File.join("0002", "#{@measure.measure_id}.html")]
    assert_not_nil bundled_sources[File.join("0002", "hqmf1.xml")]
    assert_not_nil bundled_sources[File.join("0002", "hqmf2.xml")]
  end

  test "bundle results" do
    Measures::Calculator.calculate
    bundled_results = Measures::Exporter.bundle_results([@measure])

    assert_equal bundled_results.size, 2

    expected_by_patient = ["population", "denominator", "numerator", "denexcep", "exclusions", "antinumerator", "patient_id", "medical_record_id", "first", "last", "gender", "birthdate", "test_id", "provider_performances", "race", "ethnicity", "languages", "logger", "measure_id", "nqf_id", "effective_date"]
    by_patient = JSON.parse(bundled_results["by_patient.json"]).first["value"]
    assert_equal by_patient.keys.size, expected_by_patient.size
    expected_by_patient.each {|field| assert by_patient.include? field}

    expected_by_measure = ["measure_id", "sub_id", "nqf_id", "population_ids", "effective_date", "test_id", "filters", "population", "denominator", "numerator", "antinumerator", "exclusions", "denexcep", "considered", "execution_time"]
    by_measure = JSON.parse(bundled_results["by_measure.json"]).first
    assert_equal by_measure.keys.size, expected_by_measure.size
    expected_by_measure.each {|field| assert by_measure.include? field}
  end

  test "bundle patient" do
    patient_name = "#{@patient.first}_#{@patient.last}"
    expected_formats = [
      "c32/#{patient_name}.xml",
      "ccda/#{patient_name}.xml",
      "ccr/#{patient_name}.xml",
      "json/#{patient_name}.json",
      "html/#{patient_name}.html"]

    bundled_patient = Measures::Exporter.bundle_patient(@patient)

    assert_equal bundled_patient.size, 5
    expected_formats.each {|format| assert bundled_patient.include? format}
  end

  test "zip content" do
    content = {
      "blop" => {"blop.js" => "alert('this is a great library')"},
      "bleep" => {"bleep.json" => "a : b", "bleep2.json" => "c : d"},
      "bloop" => {"bloop.xml" => "<ha>ha</ha>"}
    }
    expected_file_names = ["blop/blop.js", "bleep/bleep.json", "bleep/bleep2.json", "bloop/bloop.xml"]
    expected_file_content = ["alert('this is a great library')", "a : b", "c : d", "<ha>ha</ha>"]
    bundle = Measures::Exporter.zip_content(content)

    file_names = []
    file_content = []
    Zip::ZipFile.open(bundle.path) do |zip|
      zip.entries.each do |entry|
        file_names << entry.name
        file_content << zip.read(entry.name)
        assert entry.size > 0
      end
    end

    file_names.size.must_equal expected_file_names.size
    file_content.size.must_equal expected_file_content.size

    file_names.each {|file_name| assert expected_file_names.include? file_name}
    file_content.each {|file_content| assert expected_file_content.include? file_content}
  end
end