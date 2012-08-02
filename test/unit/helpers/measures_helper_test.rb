require 'test_helper'

class MeasuresHelperTest < ActionView::TestCase
  # create a dummy class because modules can't be instantiated directly
  class DummyClass < ActionView::Base
    include MeasuresHelper
  end
  
  # helper creates a javascript string from a measure number
  test "javascript include for measure debug view" do
    # create a test record/patient
    measure = FactoryGirl.create(:measure)
    FactoryGirl.create(:record)

    dc = DummyClass.new
    js = dc.include_js_debug(measure.id, Record.first.id)
    # some simple content tests to see if the generated javascript is at least close
    assert_match(Regexp.new('var patient'), js)
    assert_match(Regexp.new('hqmfjs.DENOM'), js)
    
    Record.delete_all   # TODO: don't we have rollbacks or transactions on the test environment?
  end
  
end
