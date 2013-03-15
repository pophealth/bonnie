require File.expand_path('../../../config/environment',  __FILE__)

namespace :bonnie do
  desc 'Load all measures and export a bundle. Optionally, load a white list and calculate concepts.'
  task :initialize, [:measures_dir, :username, :white_list_path, :vs_username, :vs_password, :calculate, :force_xls, :clear_vs_cache, :delete_existing, :include_concepts] do |t, args|
    use_vsac = !(args.force_xls == 'true')

  	Rake::Task["measures:generate_oids_by_measure"].invoke(args.measures_dir, args.clear_vs_cache) if use_vsac
  	Rake::Task["measures:load"].invoke(args.measures_dir, args.username, args.vs_username, args.vs_password, args.delete_existing, args.clear_vs_cache)
  	Rake::Task["concepts:load"].invoke(args.username, args.delete_existing) if args.include_concepts == 'true'
  	Rake::Task["value_sets:load_white_list"].invoke(args.white_list_path, args.delete_existing) if args.white_list_path
  	Rake::Task["measures:export"].invoke(args.username, args.calculate)
  end

  desc 'Load a measure bundle back into bonnie'
  task :load_bundle, [:bundle_zip, :username, :white_list_path, :type, :json_draft_measures, :rebuild_measures, :delete_existing] do |t, args|

    if args.delete_existing != 'false'
      Rake::Task["db:drop"].invoke()
    end

    username = args.username
    User.create!({agree_license: true, approved: true, password: username, password_confirmation: username, email: "#{username}@example.com", first_name: username, last_name: username, username: username})

  	Rake::Task["bundle:import"].invoke(args.bundle_zip,'true','true',args.type,'false')
    Rake::Task["measures:load_from_bundle"].invoke(args.bundle_zip, username, args.type, args.json_draft_measures, args.rebuild_measures)
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
        if left_value && right_value && left_value['value'][code] != right_value['value'][code]
          puts "\tMISMATCH: #{left_value['value']['nqf_id']}#{right_value['value']['sub_id']} #{left_value['value']['last']}, #{left_value['value']['first']} - #{code}: #{left_value['value'][code]} != #{right_value['value'][code]}" 
        elsif !(left_value && right_value)
          left_extract = left_value || {}
          right_extract = right_value || {}
          value = left_extract['value'] || right_extract['value']
#          puts "\tMISSING: #{value['nqf_id']}#{value['sub_id']} #{value['last']}, #{value['first']} - #{code}: #{left_extract['value'][code]} != #{right_extract['value'][code]}" 
        end
      end
    end

  end

  desc 'compare mongoexport results of HDS Value sets'
  task :compare_value_sets, [:left_file, :right_file] do |t, args|
    #mongoexport --jsonArray -o /tmp/local.json -d bonnie-development -c health_data_standards_svs_value_sets -h localhost
    #mongoexport --jsonArray -o /tmp/local.json -d bonnie-production -c health_data_standards_svs_value_sets -h stagevpc25
    raise "The path to both files must be specified" unless args.left_file && args.right_file

    left = JSON.parse(File.read(args.left_file))
    right = JSON.parse(File.read(args.right_file))

    right_map = {}
    right.each {|r| right_map["#{r['oid']}_#{r['_type']}"] = r;}
    left_map = {}
    left.each {|l| left_map["#{l['oid']}_#{l['_type']}"] = l;}

    keys = (left_map.keys + right_map.keys).uniq
    keys.each do |key|
      lvs = left_map[key]
      rvs = right_map[key]
      if !lvs
        puts "\t Left is missing for key: #{key}"
      elsif !rvs
        puts "\t Right is missing for key: #{key}"
      else
        puts "\t#{key}: display doesn't match #{lvs['display_name']} != #{rvs['display_name']}" if lvs['display_name'] != rvs['display_name']
        puts "\t#{key}: version doesn't match #{lvs['version']} != #{rvs['version']}" if "#{lvs['version']}" != "#{rvs['version']}"

        lconcepts = lvs['concepts'].map {|c| "#{c['code_system_name']}_#{c['code']}_#{c['code_system_version']}"}
        rconcepts = rvs['concepts'].map {|c| "#{c['code_system_name']}_#{c['code']}_#{c['code_system_version']}"}

        bad_left = lconcepts - rconcepts
        bad_right = rconcepts - lconcepts

        puts "\t#{key}: unmatching on left: #{bad_left}" unless bad_left.empty?
        puts "\t#{key}: unmatching on right: #{bad_right}" unless bad_right.empty?
      end
    end

  end

  desc 'compare mongoexport of patients'
  task :compare_patients, [:left_file, :right_file] do |t, args|
    #mongoexport --jsonArray -o /tmp/local.json -d bonnie-development -c records -h localhost
    #mongoexport --jsonArray -o /tmp/local.json -d bonnie-production -c records -h stagevpc25
    raise "The path to both files must be specified" unless args.left_file && args.right_file

    def clean_ids(entry)
      entry.delete('_id')
      entry['values'].each {|v| v.delete('_id')} if entry['values']
      entry['reason'].delete('_id') if entry['reason']
      entry['reason'].delete('_type') if entry['reason']
      entry['facility'].delete('_id') if entry['facility']
      entry['payer'].delete('_id') if entry['payer']
      entry
    end

    def entry_to_s(entry)
      "#{entry['start_time']}_#{entry['end_time']}_#{entry['oid']}_#{entry['description']}_#{entry['codes'].keys.sort}_#{entry['codes'].values.flatten.sort}"
    end

    left = JSON.parse(File.read(args.left_file))
    right = JSON.parse(File.read(args.right_file))

    right_map = {}
    right.each {|r| right_map["#{r['medical_record_number']}"] = r;}
    left_map = {}
    left.each {|l| left_map["#{l['medical_record_number']}"] = l;}

    keys = (left_map.keys + right_map.keys).uniq
    keys.each do |key|
      lpatient = left_map[key]
      rpatient = right_map[key]
      if !lpatient
        puts "\t Left is missing for key: #{key}"
      elsif !rpatient
        puts "\t Right is missing for key: #{key}"
      else

        name = "#{lpatient['last']}, #{lpatient['first']}"
        fields = ["birthdate", "ethnicity", "expired", "first", "gender", "languages", "last", "race", "type"]
        fields.each do |field|
          puts "\t#{name}: #{field} doesn't match #{lpatient[field]} != #{rpatient[field]}" if lpatient[field] != rpatient[field]
        end

        lentries = Record::Sections.reduce([]) {|entries, section| entries.concat(lpatient[section.to_s] || []); entries }
        rentries = Record::Sections.reduce([]) {|entries, section| entries.concat(rpatient[section.to_s] || []); entries }

        if (lentries.length != rentries.length)
          puts "\t#{name}: unmatching entry count on left and right"
        else
          lentries.sort! {|l, r| entry_to_s(l) <=> entry_to_s(r) }
          rentries.sort! {|l, r| entry_to_s(l) <=> entry_to_s(r) }

          (0..lentries.length-1).each do |index|
            l = clean_ids(lentries[index])
            r = clean_ids(rentries[index])
            diff = l.diff(r)
            puts puts "\t#{name}: unmatching entry #{l['description']}: #{diff}" unless diff.empty?
          end
        end
      end
    end

  end


end