require 'test_helper'
require 'concepts/concept_loader'

class ConceptLoaderTest < ActiveSupport::TestCase
  setup do
    ValueSet.delete_all
    Concept.delete_all
  end

  test "create concepts" do
    assert_equal 0, ValueSet.count
    vs = FactoryGirl.create(:value_set)
    cs = FactoryGirl.build(:code_set)
    vs.code_sets << cs
    assert_equal 0, Concept.count
    Concepts::ConceptLoader.create_concepts
    assert_equal 1, Concept.count
    concept = Concept.first
    assert concept.oids.include?("2.16.840.1.113883.3.464.0002.1138")
  end
end