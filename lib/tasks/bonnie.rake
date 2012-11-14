require File.expand_path('../../../config/environment',  __FILE__)

namespace :bonnie do
  desc 'Load all measures and export a bundle. Optionally, load a white list and calculate concepts.'
  task :initialize, [:measures_dir, :username, :delete_existing, :white_list_path, :static_results_path, :include_concepts, :calculate] do |t, args|
  	Rake::Task["measures:load"].invoke(args.measures_dir, args.username, args.delete_existing)
  	Rake::Task["concepts:load"].invoke(args.username, args.delete_existing) if args.include_concepts == 'true'
  	Rake::Task["value_sets:load_white_list"].invoke(args.white_list_path, args.delete_existing) if args.white_list_path
  	Rake::Task["measures:export"].invoke(args.username, args.static_results_path, args.calculate)
  end
end