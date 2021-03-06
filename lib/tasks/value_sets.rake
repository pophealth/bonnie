namespace :value_sets do
  desc "Load a white list to override default value sets"
  task :load_white_list, [:white_list_path, :black_list_path] => :environment do |task, args|
    raise "You must specify a valid path to the white list file" unless args.white_list_path
    white_list_path = args.white_list_path
    black_list_path = args.black_list_path
    
    delete_count = 0
    HealthDataStandards::SVS::ValueSet.all.each do |vs|
      concepts = vs.concepts
      match = false
      concepts.each do |c| 
        if (c.white_list || c.black_list)
          c.white_list=false
          c.black_list=false
          match=true
          delete_count+=1
        end
      end
      if match
        vs.concepts = concepts
        vs.save!
      end
    end
    puts "deleted #{delete_count} white/black list entries"

    parser = HQMF::ValueSet::Parser.new()
    value_sets = parser.parse(white_list_path)
    child_oids = parser.child_oids
    white_list_total = 0
    value_sets.each do |value_set|
      existing = HealthDataStandards::SVS::ValueSet.where(oid: value_set.oid).first
      if !existing && child_oids.include?(value_set.oid)
        next
      elsif !existing
        puts "\tMissing: #{value_set.oid}"
        next
      end

      white_list_count = value_set.concepts.length
      white_list_map = value_set.concepts.reduce({}) {|hash, concept| hash[concept.code_system_name]||=Set.new; hash[concept.code_system_name] << concept.code; hash}

      matched_count = 0
      concepts = existing.concepts
      concepts.each do |concept|
        if white_list_map[concept.code_system_name] && white_list_map[concept.code_system_name].include?(concept.code)
          concept.white_list=true
          matched_count+=1
        end
      end

      puts "white list code missing for oid: #{value_set.oid}" unless matched_count == white_list_count
      white_list_total += matched_count

      existing.concepts = concepts
      existing.save!

    end
    puts "loaded: #{white_list_total} white list entries"

    if black_list_path
      parser = HQMF::BlackList::Parser.new()
      black_list = parser.parse(black_list_path)

      black_list_map = black_list.reduce({}) {|hash, concept| hash[concept[:code_system_name]]||=Set.new; hash[concept[:code_system_name]] << concept[:code]; hash}

      black_list_count = 0
      HealthDataStandards::SVS::ValueSet.all.each do |vs|
        concepts = vs.concepts
        match = false
        concepts.each do |concept|
          if black_list_map[concept.code_system_name] && black_list_map[concept.code_system_name].include?(concept.code)
            match = true
            concept.black_list=true
            puts "\twhite list code blacklisted: #{vs.oid}" if concept.white_list
            black_list_count+=1
          end
        end
        if (match)
          vs.concepts = concepts
          vs.save!
        end
      end

      puts "loaded: #{black_list_count} black list entries"


    end

  end
  
  desc "Dump value sets as NLM responses to the value set cache"
  task :export_to_cache, [] => :environment do |t,args|

    code_set_cache_dir = File.join('.','db','code_sets')
    FileUtils.rm_r code_set_cache_dir if File.exists? code_set_cache_dir
    FileUtils.mkdir_p code_set_cache_dir

    used_oids = Measure.all.map {|measure| measure.as_hqmf_model.all_code_set_oids}.flatten.uniq
    value_sets = HealthDataStandards::SVS::ValueSet.all.select {|vs| used_oids.include? vs.oid}

    puts "exporting #{value_sets.length} value sets"

    class RenderingContext < OpenStruct
      def my_binding
        binding
      end
    end

    value_sets.each do |value_set|
      locals = {value_set: value_set}
      rendering_context = RenderingContext.new(locals)
      erb = File.read(File.join('lib','templates','erb','valueset','valueset.xml.erb'))
      eruby = Erubis::EscapedEruby.new(erb)
      result = eruby.result(rendering_context.my_binding)
      File.open(File.join(code_set_cache_dir,"#{value_set.oid}.xml"), 'w') {|f| f.write(result) }
    end

    puts "exported #{value_sets.length} value sets to #{code_set_cache_dir}"



  end

end