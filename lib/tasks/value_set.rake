namespace :value_sets do
  desc 'import xls for value sets'
  task :load, [:file] => :environment do |task, args|
    file = args.file
    if !file || file.blank?
      raise "USAGE: rake import:value_sets[file_path]"
    else
      vsp = HQMF::ValueSet::Parser.new()
      value_sets = vsp.parse(file, {format: :xls})
      
      value_sets.each do |value_set|
        ValueSet.new(value_set).save!
      end
      
      puts "Imported #{value_sets.count} value #{"set".pluralize(value_sets.count)} from #{file}."
    end
  end
  
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
end