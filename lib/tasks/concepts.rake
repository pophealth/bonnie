require File.expand_path('../../../config/environment',  __FILE__)

namespace :concepts do
  desc "Load all of the concepts."
  task :load_all, [:username, :delete_existing] do |t, args|
    raise "The username to load the measures for must be specified" unless args.username
    
    user = User.by_username args.username
    raise "The user #{args.username} could not be found." unless user
    
    if args.delete_existing
      # Delete all of this user's value sets and concepts
      count = Concept.all.destroy_all # TODO make this actually delete by user
      puts "Deleted #{count} concepts assigned to #{user.username}'s measures"
    end
    
    user.measures.entries.each do |measure|
      puts "Building concepts for measure #{measure.measure_id} - #{measure.title}"
      measure.value_sets.each do |value_set|
        Concepts::ConceptLoader.create_concepts(value_set)
      end
    end
    Concepts::ConceptLoader.build_relationships
  end
  
  desc "Apply all concepts to filter value sets"
  task :apply_all do |t, args|
    ValueSet.all.entries.each do |value_set|
      concept = Concept.any_in(oids: value_set.oid).first
      next if concept.nil?
      
      value_set.code_sets.each do |code_set|
        common_code = concept.find_common_code_for(code_set)
      end
    end
  end
end