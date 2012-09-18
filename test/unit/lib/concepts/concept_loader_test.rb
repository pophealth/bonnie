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

  test "build relationships" do
    assert_equal 0, Concept.count
    c1 = FactoryGirl.create(:concept)
    c1.code_sets << FactoryGirl.build(:code_set)
    c2 = FactoryGirl.create(:concept)
    c2.code_sets << FactoryGirl.build(:code_set)

    Concepts::ConceptLoader.build_relationships

    c1.reload

    assert_equal 1, c1.concept_relationships.size
    cr = c1.concept_relationships.first
    assert c2.id == cr.related_concept.id    
  end
end