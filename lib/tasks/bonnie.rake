require File.expand_path('../../../config/environment',  __FILE__)

namespace :bonnie do
  desc 'Load all measures and export a bundle. Optionally, load a white list and calculate concepts.'
  task :initialize, [:measures_dir, :username, :white_list_path, :vs_username, :vs_password, :static_results_path, :calculate, :clear_vs_cache, :delete_existing, :include_concepts] do |t, args|
    use_vsac = !(args.vs_username.nil? or args.vs_password.nil? or args.vs_username.empty? or args.vs_password.empty?)

  	Rake::Task["measures:generate_oids_by_measure"].invoke(args.measures_dir, args.clear_vs_cache) if use_vsac
  	Rake::Task["measures:load"].invoke(args.measures_dir, args.username, args.vs_username, args.vs_password, args.delete_existing, args.clear_vs_cache)
  	Rake::Task["concepts:load"].invoke(args.username, args.delete_existing) if args.include_concepts == 'true'
  	Rake::Task["value_sets:load_white_list"].invoke(args.white_list_path, args.delete_existing) if args.white_list_path
  	Rake::Task["measures:export"].invoke(args.username, args.static_results_path, args.calculate)
  end
end