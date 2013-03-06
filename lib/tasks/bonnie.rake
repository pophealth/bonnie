require File.expand_path('../../../config/environment',  __FILE__)

namespace :bonnie do
  desc 'Load all measures and export a bundle. Optionally, load a white list and calculate concepts.'
  task :initialize, [:measures_dir, :username, :white_list_path, :vs_username, :vs_password, :calculate, :clear_vs_cache, :delete_existing, :include_concepts] do |t, args|
    use_vsac = !(args.vs_username.nil? or args.vs_password.nil? or args.vs_username.empty? or args.vs_password.empty?)

  	Rake::Task["measures:generate_oids_by_measure"].invoke(args.measures_dir, args.clear_vs_cache) if use_vsac
  	Rake::Task["measures:load"].invoke(args.measures_dir, args.username, args.vs_username, args.vs_password, args.delete_existing, args.clear_vs_cache)
  	Rake::Task["concepts:load"].invoke(args.username, args.delete_existing) if args.include_concepts == 'true'
  	Rake::Task["value_sets:load_white_list"].invoke(args.white_list_path, args.delete_existing) if args.white_list_path
  	Rake::Task["measures:export"].invoke(args.username, args.calculate)
  end

  desc 'Load a measure bundle back into bonnie'
  task :load_bundle, [:bundle_zip, :username, :white_list_path, :type, :json_draft_measures, :delete_existing] do |t, args|

    if args.delete_existing != 'false'
      Rake::Task["db:drop"].invoke()
    end

    username = args.username
    User.create!({agree_license: true, approved: true, password: username, password_confirmation: username, email: "#{username}@example.com", first_name: username, last_name: username, username: username})

  	Rake::Task["measures:load_from_bundle"].invoke(args.bundle_zip, username, args.type, args.json_draft_measures)
  	Rake::Task["bundle:import"].invoke(args.bundle_zip,'true','true',args.type,'false')
  	Rake::Task["value_sets:load_white_list"].invoke(args.white_list_path, 'true') if args.white_list_path
  end

  desc 'compare mongoexport results of patient_cache'
  task :compare_patient_caches, [:left_file, :right_file] do |t, args|
    #mongoexport --jsonArray -o /tmp/local.json -d bonnie-development -c patient_cache -h localhost
    #mongoexport --jsonArray -o /tmp/local.json -d bonnie-production -c patient_cache -h stagevpc25
    raise "The path to both files must be specified" unless args.left_file && args.right_file

    left = JSON.parse(File.read(args.left_file))
    right = JSON.parse(File.read(args.right_file))

    def entry_key(entry)
      "#{entry['value']['medical_record_id']}#{entry['value']['nqf_id']}#{entry['value']['sub_id']}"
    end

    def entry_as_string(entry)
      "#{entry['value']['nqf_id']}#{entry['value']['sub_id']}#{entry['value']['last']},#{entry['value']['first']}"
    end

    right_map = {}
    right.each {|r| key = entry_key(r); right_map[key] = r;}
    left.sort! {|l,r| entry_as_string(l) <=> entry_as_string(r)}
    left.each do |left_value|
      right_value = right_map[entry_key(left_value)]
      HQMF::PopulationCriteria::ALL_POPULATION_CODES.each do |code|
        if left_value['value'][code] != right_value['value'][code]
          puts "\tMISMATCH: #{left_value['value']['nqf_id']}#{right_value['value']['sub_id']} #{left_value['value']['last']}, #{left_value['value']['first']} - #{code}: #{left_value['value'][code]} != #{right_value['value'][code]}" 
        end
      end
    end

  end


end