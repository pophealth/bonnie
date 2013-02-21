require File.expand_path('../../../config/environment',  __FILE__)
require 'pathname'
require 'fileutils'
require './lib/measures/database_access'
require './lib/measures/exporter'

namespace :measures do
  
  
  desc 'Load from url file'
  task :load_from_url, [:url, :username] do |t, args|
    raise "The url to measure definitions must be specified" unless args.url
    raise "The username to load the measures for must be specified" unless args.username

    user = User.by_username args.username
    raise "The user #{args.username} could not be found." unless user
    
    data = Measures::Loader.load_from_url(args.url)
    paths = data.map {|key,value| value[:source_path]}
    Measures::Loader.load_paths(paths, user)

  end
  
  desc 'Load a directory of measures and value sets into the DB'
  task :load, [:measures_dir, :username, :vs_username, :vs_password, :delete_existing, :clear_vs_cache] do |t, args|
    raise "The path to the measure definitions must be specified" unless args.measures_dir
    raise "The username to load the measures for must be specified" unless args.username

    user = User.by_username args.username
    raise "The user #{args.username} could not be found." unless user
    
    clear_vs_cache = args.clear_vs_cache=='true'
    vs_username = args.vs_username
    vs_password = args.vs_password
    
    # Delete all of this user's measures out of the DB and remove any lingering files saved from the last load
    if args.delete_existing != 'false'
      #user.measures.each {|measure| measure.value_sets.destroy_all}
      count = user.measures.destroy_all
      
      source_dir = File.join(".", "db", "measures")
      FileUtils.rm_r Dir.glob(source_dir)
      
      HealthDataStandards::SVS::ValueSet.all.delete()
      
      puts "Deleted #{count} measures assigned to #{user.username}"
    end
    
    # remove code_set cache dir
    code_set_cache_dir = File.join('.','db','code_sets')
    FileUtils.rm_r code_set_cache_dir if File.exists? code_set_cache_dir and args.clear_vs_cache == 'true'
    FileUtils.mkdir_p code_set_cache_dir
    
    
    measures_dir_hash = Digest::MD5.hexdigest(args.measures_dir)
    oids_path = File.join(".","db","#{measures_dir_hash}_oids_by_measure.json")
    
    value_set_oids = JSON.parse(File.read(oids_path)) if File.exists?(oids_path)
    
    measure_count = Dir.glob(File.join(args.measures_dir,'**','*.xml')).count
    index = 0
    
    # Load each measure from the measures directory
    Dir.foreach(args.measures_dir) do |entry|
      next if entry.starts_with? '.'
      
      index += 1

      measure_dir = File.join(args.measures_dir,entry)
      hqmf_path = Dir.glob(File.join(measure_dir,'*.xml')).first
      codes_path = Dir.glob(File.join(measure_dir,'*.xls')).first
      html_path = Dir.glob(File.join(measure_dir,'*.html')).first
      
      begin
        measure = Measures::Loader.load(hqmf_path, user, html_path, true, value_set_oids, vs_username, vs_password, codes_path, clear_vs_cache)
        
        puts "(#{index}/#{measure_count}): Measure #{measure.measure_id} (#{measure.title}) successfully loaded.\n"
      rescue Exception => e
        puts "Loading Measure #{entry} failed: #{e.message}: [#{hqmf_path},#{codes_path}] \n"
      end
    end

    Measures::Calculator.refresh_js_libraries
  end

  desc 'Normalize measure files into a directory'
  task :normalize, [:measures_dir] do |t, args|
    raise "The path to the measure definitions must be specified" unless args.measures_dir

    base_dir = File.join('.','tmp','measures','normalize')
    FileUtils.mkdir_p base_dir

    # Load each measure from the measures directory
    Dir.foreach(args.measures_dir) do |entry|
      next if entry.starts_with? '.'

      measure_dir = File.join(args.measures_dir,entry)
      hqmf_path = Dir.glob(File.join(measure_dir,'*.xml')).first
      codes_path = Dir.glob(File.join(measure_dir,'*.xls')).first
      html_path = Dir.glob(File.join(measure_dir,'*.html')).first
      
      measure = Measures::Loader.load(hqmf_path, nil, nil, false)
      
      measure_out_dir = File.join(base_dir,measure.measure_id)
      FileUtils.mkdir_p measure_out_dir
      FileUtils.cp(hqmf_path, File.join(measure_out_dir,"#{measure.measure_id}.xml"))
      FileUtils.cp(codes_path, File.join(measure_out_dir,"#{measure.measure_id}.xls")) if codes_path
      FileUtils.cp(html_path, File.join(measure_out_dir,"#{measure.measure_id}.html"))
      
      puts "copied #{measure.measure_id} resources to #{measure_out_dir}"
      
    end
  end
  
  desc 'Generate oids by measure'
  task :generate_oids_by_measure, [:measures_dir, :clear_cache] do |t, args|
    raise "The path to the measure definitions must be specified" unless args.measures_dir
    
    clear_cache = args.clear_cache=='true'

    measures_dir_hash = Digest::MD5.hexdigest(args.measures_dir)
    outfile = File.join(".","db","#{measures_dir_hash}_oids_by_measure.json")
    File.delete(outfile) if File.exists? outfile and clear_cache
    
    if File.exists? outfile
      puts "Using cached measure oids at: #{outfile}"
    else
      oids_by_measure = {}

      # Load each measure from the measures directory
      Dir.foreach(args.measures_dir) do |entry|
        next if entry.starts_with? '.'

        measure_dir = File.join(args.measures_dir,entry)
        hqmf_path = Dir.glob(File.join(measure_dir,'*.xml')).first

        measure = nil
        original_stdout = $stdout
        $stdout = StringIO.new
        begin
          measure = Measures::Loader.load(hqmf_path, nil, nil, false)
        ensure
          $stdout = original_stdout
        end

        oids_by_measure[measure.hqmf_id] = measure.as_hqmf_model.all_code_set_oids

        puts "pulled #{oids_by_measure[measure.hqmf_id].count} oids from #{measure.measure_id}"
      end

      File.open(outfile, 'w') {|f| f.write(JSON.pretty_generate(oids_by_measure)) }

      puts "Wrote oids by measure to: #{outfile}"
    end

  end
  
  
  desc 'Drop all measure defintions from the DB'
  task :drop, [:username] do |t, args|
    measures = args.username ? User.by_username(args.username).measures : Measure.all
    count = measures.destroy_all
    puts "Deleted #{count} measures assigned to #{user.username}"
  end

  desc 'Export definitions for all measures'
  task :export, [:username, :calculate] do |t, args|
    calculate = args.calculate != 'false'
    measures = args.username ? User.by_username(args.username).measures.to_a : Measure.all.to_a

    zip = Measures::Exporter.export_bundle(measures, calculate)
    version = APP_CONFIG["measures"]["version"]
    bundle_path = File.join(".", "tmp", "bundles")
    date_string = Time.now.strftime("%Y-%m-%d")
    
    FileUtils.mkdir_p bundle_path
    FileUtils.mv(zip.path, File.join(bundle_path, "bundle-#{date_string}-#{version}.zip"))
    puts "Exported #{measures.size} measures to #{File.join(bundle_path, "bundle-#{date_string}-#{version}.zip")}"
  end
  
  desc 'Generate Results Spreadsheet template for static testing results'
  task :generate_results_xls, [:type] do |t, args|
    raise "Type must be specified" unless args.type
    require 'rubyXL'
    
    type = args.type
    
    measures = []
    MONGO_DB["measures"].find({type:type}).each do |measure|
      measures << measure
    end

    measures.sort! {|left,right| "#{left['nqf_id']}#{left['sub_id']}" <=> "#{right['nqf_id']}#{right['sub_id']}"}
    
    workbook_template = RubyXL::Parser.parse(File.join('lib','templates','EH_results_matrix.xlsx'))
    template = Marshal.dump(workbook_template.worksheets[0])
    template_cv = Marshal.dump(workbook_template.worksheets[1])
    
    workbook_template.worksheets = []
    measures.each do |measure|
      worksheet = measure['population_ids'][HQMF::PopulationCriteria::MSRPOPL].nil? ? Marshal.load(template) : Marshal.load(template_cv)
      worksheet.sheet_name = "#{measure['nqf_id']}#{measure['sub_id']}"
      worksheet.add_cell(1,8,measure['name'])
      worksheet.add_cell(2,8,"#{measure['nqf_id']}#{measure['sub_id']}")
      worksheet.add_cell(3,8,measure['subtitle'])
      row = 4
      
      (HQMF::PopulationCriteria::ALL_POPULATION_CODES + ['stratification']).each_with_index do |key, index|
        worksheet.add_cell(row+index,7,key)
        worksheet[row+index][7].change_font_bold(true)
        worksheet.add_cell(row+index,8,measure['population_ids'][key])
      end
      workbook_template.worksheets << worksheet
    end
    
    result_file = File.join('tmp','results_matrix',"results_matrix_#{type}.xlsx")
    workbook_template.write(result_file)
    puts "Wrote result matrix for #{type} to #{result_file}"
  end
  
  desc 'Generate measure html'
  task :measure_html, [] do |t, args|
    
    measures = Measure.all
    
    basedir = File.join('.', 'tmp','measures','rationale')
    tmpdir = File.join(basedir,'tmp')
    FileUtils.rm_r basedir if File.exists?(basedir)
    FileUtils.mkdir_p tmpdir
    
    population_keys = ('a'..'zz').to_a
    measures.each do |measure|
      
      measure.populations.each_with_index do |population,index|

        sub_id = nil
        sub_id = population_keys[index] if measure.populations.length > 1
        
        outdir = File.join(basedir,measure.measure_id)
        FileUtils.mkdir_p outdir
        
        result = Measures::HTML::Writer.generate_nqf_template(measure, population)

        outfile = File.join(tmpdir,"#{measure.measure_id}#{sub_id}.html.erb")
        File.open(outfile, 'w') {|f| f.write(result) }

        patient_caches = MONGO_DB['patient_cache'].where({'value.nqf_id'=>measure.measure_id, 'value.sub_id'=>sub_id})
        patient_caches.each do |cache|
          locals ||= {}
          
          result = Measures::HTML::Writer.finalize_template(measure.measure_id, sub_id, cache, tmpdir)
          name = "#{cache['value']['last']}_#{cache['value']['first']}"
        
          if (sub_id)
            subdir = File.join(outdir,sub_id)
            FileUtils.mkdir_p subdir
            outfile = File.join(subdir, "#{name}.html")
          else
            outfile = File.join(outdir, "#{name}.html")
          end
        
          File.open(outfile, 'w') {|f| f.write(result) }
        end

        
        puts "wrote measure #{measure.measure_id}#{sub_id} patients to: #{outdir}"
      end
      
    end
    
  end
  
end