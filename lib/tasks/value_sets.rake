namespace :value_sets do
  desc "Load a white list to override default value sets"
  task :load_white_list, [:file, :delete_existing] => :environment do |task, args|
    raise "You must specify a valid path to the white list file" unless args.file
    path = args.file
    
    WhiteList.destroy_all if args.delete_existing != 'false'
    
    parser = HQMF::ValueSet::Parser.new()
    format ||= HQMF::ValueSet::Parser.get_format(path)
    value_sets = parser.parse(path, {format: format})
    value_sets.each do |value_set|
        hds_value_set = HealthDataStandards::SVS::ValueSet.new() 
        hds_value_set['oid'] = value_set['oid']
        hds_value_set['display_name'] = value_set['key']
        hds_value_set['version'] = value_set['version']
        hds_value_set['concepts'] = []

        value_set['code_sets'].each do |code_set|
          code_set['codes'].map{ |code| 
            concept = HealthDataStandards::SVS::Concept.new()
            concept['code'] = code
            concept['code_system'] = nil
            concept['code_system_name'] = code_set['code_set']
            concept['code_system_version'] = code_set['version']
            concept['display_name'] = nil
            hds_value_set['concepts'].concat([concept])
          }
        end
        if hds_value_set['concepts'].include? nil
          puts "Value Set has a bad code set (code set is null)"
          hds_value_set['concepts'].compact!
        end
      white_list = WhiteList.new(hds_value_set.as_json)
      white_list.save!
    end
  end
  
  desc "Download the set of valuesets required by the installed measures"
  task :cache, [:username, :password, :clear] => :setup do |t,args|

    if args[:clear] == 'true'
      HealthDataStandards::SVS::ValueSet.all.delete()
    end

  end
  
end