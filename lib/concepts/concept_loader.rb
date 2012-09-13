module Concepts
  class ConceptLoader
    def self.create_concepts
      ValueSet.all.each do |value_set|
        value_set.code_sets.each do |code_set|
          concept = Concept.find_or_initialize_by(name: code_set.concept)
          concept.oids << code_set.oid unless concept.oids.include?(code_set.oid)
          concept.measures << value_set.measure unless concept.measures.include?(value_set.measure)
          specific_code_set = concept.code_sets.find_or_initialize_by(code_set: code_set.code_set,
                                                                      version: code_set.version)
          if specific_code_set.codes.empty?
            specific_code_set.codes = code_set.codes
          else
            code_set.codes.each do |code|
              specific_code_set.codes << code unless specific_code_set.codes.include?(code)
            end
          end

          concept.save!
        end
      end
    end

  end
end