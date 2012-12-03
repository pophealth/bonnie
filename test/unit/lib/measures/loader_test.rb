require 'test_helper'

class LoaderTest < ActiveSupport::TestCase

  setup do
    dump_database
    @user = FactoryGirl.create(:user)
  end

  test "loading measures" do
    hqmf_file = "test/fixtures/measure-defs/0002/0002.xml"
    value_set_file = "test/fixtures/measure-defs/0002/0002.xls"
    html_file = "test/fixtures/measure-defs/0002/0002.html"

    Measures::Loader.load(hqmf_file, @user, html_file, true, nil, value_set_file)
    Measure.all.count.must_equal 1

    measure = Measure.all.first
    refute_nil measure.population_criteria
    refute_nil measure.data_criteria
    refute_nil measure.measure_period
    refute_nil measure.measure_attributes
  end
end
