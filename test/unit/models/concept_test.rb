require 'test_helper'

class ConceptTest < ActiveSupport::TestCase
  setup do
    Concept.delete_all

    @c1 = FactoryGirl.create(:concept)
    @c1.code_sets << FactoryGirl.build(:code_set)
    @c2 = FactoryGirl.create(:concept)
    @c2.code_sets << FactoryGirl.build(:code_set)
    c3 = FactoryGirl.create(:concept)
    c3.code_sets << FactoryGirl.build(:unrelated_code_set)
    @c1.build_relationships

  end

  test "build relationships" do
    assert_equal 1, @c1.concept_relationships.size
    cr = @c1.concept_relationships.first
    assert @c2.id == cr.related_concept.id
  end

  test "find common code for" do
    cc = @c1.find_common_code_for("RxNorm")
    assert ["99201", "99202", "99203", "99204"].include?(cc)
  end
end