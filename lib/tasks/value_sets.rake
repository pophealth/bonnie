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
        if value_set['concepts'].include? nil
          puts "Value Set has a bad code set (code set is null)"
          hds_value_set['concepts'].compact!
        end
      white_list = WhiteList.new(value_set.as_json)
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