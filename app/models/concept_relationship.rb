class ConceptRelationship
  include Mongoid::Document

  embedded_in :concept
  belongs_to :related_concept, class_name: 'Concept', inverse_of: nil
  embeds_many :code_set_overlaps

  def any_overlap?
    code_set_overlaps.any? { |cso| cso.overlap_percentage > 0.0 }
  end

  def create_overlaps!
    concept.code_sets.each do |cs|
      related_cs = related_concept.code_sets.where(code_set: cs.code_set,
                                                     version: cs.version).first
      if related_cs
        cso = CodeSetOverlap.new(code_set: cs.code_set)
        cso.calculate_overlap(cs.codes, related_cs.codes)
        self.code_set_overlaps << cso
      end
    end
  end
end