require 'test_helper'

class CodeSetOverlapTest < ActiveSupport::TestCase
  test "overlap percentage calculation" do
    cso = CodeSetOverlap.new
    cso.calculate_overlap(["12", "34"], ["34", "56"])
    assert_equal (1 / 3.to_f), cso.overlap_percentage
  end
end