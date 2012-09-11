require 'test_helper'

class ImporterTest < ActiveSupport::TestCase
  
  setup do
    
    dump_database
    
    @user = FactoryGirl.create(:user)

    hqmf_file = "test/fixtures/measure-defs/0002/0002.xml"
    value_set_file = "test/fixtures/measure-defs/0002/0002.xls"

    Measures::Loader.load(hqmf_file, value_set_file, @user)
    Measure.all.count.must_equal 1
    @measure = Measure.all.first
    @zip = Tempfile.new(['measures', '.zip'])
    Measures::Exporter.export(@zip, [@measure])
    
    @importer = Measures::Importer.new('bonnie-pophealth-test','localhost',nil)
    @db = @importer.instance_variable_get(:@db)
    
    @db['system.js'].remove({})
    @db['bundles'].drop
    @db['measures'].drop
    @db['selected_measures'].drop
    @db['patient_cache'].drop
    @db['query_cache'].drop
    
  end
  
  test "test importing measures" do
    count = @importer.import(@zip)
    count.must_equal 1
    
    @db['system.js'].count.must_equal 3
    libraries = @db['system.js'].find({}).map {|entry| entry["_id"]}
    
    expected = ["map_reduce_utils", "underscore_min", "hqmf_utils"]
    expected.each {|entry| assert libraries.include? entry}
    
    @db['measures'].count.must_equal 1
    @db['bundles'].count.must_equal 1
    
    measure = @db['measures'].find({nqf_id:'0002'}).first
    bundle = @db['bundles'].find({}).first
    
    expected_bundle_keys = ["_id", "name", "license", "extensions", "measures"]
    expected_bundle_keys.each do |key| 
      assert bundle.keys.include? key
      refute_nil bundle[key]
    end
    bundle["measures"].size.must_equal 1
    measure_id = bundle["measures"][0]
    
    expected_measure_keys = ["_id","id","endorser","name","description","category","steward","population","denominator","numerator","exclusions","map_fn","measure","bundle"]
    expected_measure_keys.each do |key| 
      assert measure.keys.include? key
    end

    measure['_id'].must_equal measure_id
    measure['nqf_id'].must_equal '0002'
    measure['id'].must_equal '2E679CD2-3FEC-4A75-A75A-61403E5EFEE8'
    measure['name'].must_equal "Appropriate Testing for Children with Pharyngitis"
    measure['bundle'].must_equal bundle['_id']
    refute_nil measure['population']
    refute_nil measure['numerator']
    refute_nil measure['map_fn']
    
  end

  test "test dropping measures" do
    @db['bundles'] << {}
    @db['measures'] << {}
    @db['selected_measures'] << {}
    @db['patient_cache'] << {}
    @db['query_cache'] << {}
    
    @db['bundles'].count.must_equal 1
    @db['measures'].count.must_equal 1
    @db['selected_measures'].count.must_equal 1
    @db['patient_cache'].count.must_equal 1
    @db['query_cache'].count.must_equal 1
    
    @importer.drop_measures
    
    @db['bundles'].count.must_equal 0
    @db['measures'].count.must_equal 0
    @db['selected_measures'].count.must_equal 0
    @db['patient_cache'].count.must_equal 0
    @db['query_cache'].count.must_equal 0
    
  end
  
  test "save system js" do
    @importer.save_system_js_fn("foobar","var foo = 'bar'")
    function = @db['system.js'].find({_id:'foobar'})
    function.count.must_equal 1
    function = function.first
    function["_id"].must_equal "foobar"
    function["value"].code.must_equal "function () {\n var foo = 'bar' \n }"
  end
  
end