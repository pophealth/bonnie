class Concept
  include Mongoid::Document

  field :name, type: String
  field :oids, type: Array, default: []

  has_and_belongs_to_many :measures, inverse_of: nil
  embeds_many :code_sets, as: :code_settable
  embeds_many :concept_relationships

  def build_relationships
    Concept.all.each do |other_concept|
      if other_concept.id != self.id
        cr = ConceptRelationship.new
        cr.concept = self
        cr.related_concept = other_concept
        cr.create_overlaps!
        if cr.any_overlap?
          cr.save!
        else
          cr.destroy
        end
      end
    end
  end

  def find_common_code_for(code_set)
    desired_code_set = code_sets.where(code_set: code_set).first
    if desired_code_set
      code_list = desired_code_set.codes
      code_count = code_list.inject({}) do |count_hash, code|
        count_hash[code] = 1
        count_hash
      end

      # Going with the select method as opposed to using Moigoid finders
      # because I couldn't get them to work with $gt on a child attribute
      overlaps_on_code_set = concept_relationships.select do |cr|
        cr.code_set_overlaps.any? { |cso| cso.code_set == code_set && cso.overlap_percentage > 0.3 }
      end
      overlaps_on_code_set.each do |overlap|
        related_code_set = overlap.related_concept.code_sets.where(code_set: code_set).first
        related_code_set.codes.each do |code|
          if code_count.include?(code)
            code_count[code] = code_count[code] + 1
          end
        end
      end
      code_count.sort.last.first #sort the hash, get the last key/value pair, get the key (first)
    else
      nil
    end
  end
end