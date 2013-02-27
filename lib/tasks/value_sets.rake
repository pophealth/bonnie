namespace :value_sets do
  desc "Load a white list to override default value sets"
  task :load_white_list, [:file, :delete_existing] => :environment do |task, args|
    raise "You must specify a valid path to the white list file" unless args.file
    path = args.file
    
    WhiteList.destroy_all if args.delete_existing != 'false'
    
    parser = HQMF::ValueSet::Parser.new()
    format ||= HQMF::ValueSet::Parser.get_format(path)
    value_sets = parser.parse(path, {format: format})
    child_oids = parser.child_oids
    value_sets.each do |value_set|
      if value_set['concepts'].include? nil
        puts "Value Set has a bad code set (code set is null)"
        hds_value_set['concepts'].compact!
      end
      existing = HealthDataStandards::SVS::ValueSet.where(oid: value_set.oid).first
      if !existing && child_oids.include?(value_set.oid)
        next
      elsif !existing
        puts "\tMissing: #{value_set.oid}"
        next
      end
      existing_map = existing.concepts.reduce({}) {|hash, concept| hash[concept.code_system_name]||=Set.new; hash[concept.code_system_name] << concept.code; hash}
      white_list = WhiteList.new(value_set.as_json)
      match = white_list.concepts.reduce(true) {|match, concept| match &&= existing_map[concept.code_system_name].include? concept.code; match}
      throw "white list code missing for oid: #{value_set.oid}" unless match
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