require File.expand_path('../../../config/environment',  __FILE__)

namespace :bonnie do
  desc 'Load all measures and export a bundle. Optionally, load a white list and calculate concepts.'
  task :initialize, [:measures_dir, :username, :delete_existing, :white_list_path, :include_concepts] do |t, args|
  	Rake::Task["measures:load"].invoke(args.measure_dir, args.username, args.delete_existing)
  	Rake::Task["concepts:load"].invoke if args.include_concepts
  	Rake::Task["value_sets:load_white_list"].invoke(args.white_list_path, args.delete_existing) if args.white_list_path
  	Rake::Task["measures:export"].invoke(args.username, args.delete_existing)
  end
end