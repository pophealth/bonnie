require File.expand_path('../../../config/environment',  __FILE__)

namespace :concepts do
  desc "Load all of the concepts."
  task :load, [:username, :delete_existing] do |t, args|
    raise "The username to load the measures for must be specified" unless args.username
    
    user = User.by_username args.username
    raise "The user #{args.username} could not be found." unless user
    
    if args.delete_existing != 'false'
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
end