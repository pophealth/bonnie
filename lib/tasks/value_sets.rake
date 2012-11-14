namespace :value_sets do
  desc "Load a white list to override default value sets"
  task :load_white_list, [:file, :delete_existing] => :environment do |task, args|
    raise "You must specify a valid path to the white list file" unless args.file
    path = args.file
    
    WhiteList.destroy_all if args.delete_existing
    
    parser = HQMF::ValueSet::Parser.new()
    format ||= HQMF::ValueSet::Parser.get_format(path)
    value_sets = parser.parse(path, {format: format})
    value_sets.each do |value_set|
      if value_set['code_sets'].include? nil
        puts "White list has a bad code set (code set is null)"
        value_set['code_sets'].compact!
      end
      white_list = WhiteList.new(value_set)
      white_list.save!
    end
  end
  
  desc "Download the set of valuesets required by the installed measures"
  task :cache, [:username, :password, :clear] => :setup do |t,args|

    if args[:clear] == 'true'
      ValueSet.all.delete()
    end

  end
  
end