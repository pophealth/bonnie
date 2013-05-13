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

  desc 'Load from bundle'
  task :load_from_bundle, [:bundle_zip, :username, :type, :json_draft_measures, :rebuild_measures] do |t, args|
    raise "The path to bundle zip must be specified" unless args.bundle_zip
    raise "The username to load the measures for must be specified" unless args.username

    json_draft_measures = args.json_draft_measures != 'false'
    rebuild_measures = args.rebuild_measures == 'true'

    user = User.by_username args.username
    raise "The user #{args.username} could not be found." unless user
    
    Measures::Loader.load_from_bundle(args.bundle_zip, user.username, args.type, json_draft_measures, rebuild_measures)

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
    Dir.entries(args.measures_dir).sort.each do |entry|
      next if entry.starts_with? '.'
      
      index += 1

      measure_dir = File.join(args.measures_dir,entry)
      hqmf_path = Dir.glob(File.join(measure_dir,'*.xml')).first
      codes_path = Dir.glob(File.join(measure_dir,'*.xls')).first
      html_path = Dir.glob(File.join(measure_dir,'*.html')).first
      
      begin
        measure = Measures::Loader.load(hqmf_path, user, html_path, true, value_set_oids, vs_username, vs_password, codes_path)
        
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

  desc 'Export definitions for all measures'
  task :export_js, [:username] do |t, args|
    calculate = args.calculate != 'false'
    measures = args.username ? User.by_username(args.username).measures.to_a : Measure.all.to_a

    outpath = File.join(".", "tmp", "measures", "js")
    
    FileUtils.rm_r outpath if File.exists?(outpath)
    FileUtils.mkdir_p outpath

    sub_ids = ('a'..'zz').to_a
    measures.each do |measure|
      measure.populations.each_with_index do |population, population_index|
        sub_id = ''
        sub_id = sub_ids[population_index] if measure.populations.count > 1
        measure_id = "#{measure.measure_id}#{sub_id}"
        outfile = File.join(outpath, "#{measure_id}.js")
        js = Measures::Calculator.execution_logic(measure, population_index, true)
        File.open(outfile, 'w') {|f| f.write(js) }
        puts "wrote js for: #{measure_id}"
      end
    end

    puts "Exported javascript for #{measures.size} measures to #{outpath}"
  end

  desc 'Generate measure rationale'
  task :generate_rationale, [] do |t, args|
    
    measures = Measure.all
    patient_map = Record.all.reduce({}) {|patient_map, patient| patient_map[patient.medical_record_number] = patient; patient_map}
    
    basedir = File.join('.', 'tmp','measures','rationale')
    basedir_by_measure = File.join(basedir,'by_measure')
    basedir_by_patient = File.join(basedir,'by_patient')
    FileUtils.rm_r basedir if File.exists?(basedir)
    
    population_keys = ('a'..'zz').to_a
    measures.each do |measure|
      
      measure.populations.each_with_index do |population,index|

        sub_id = nil
        sub_id = population_keys[index] if measure.populations.length > 1
        
        outdir = File.join(basedir_by_measure,measure.measure_id)
        FileUtils.mkdir_p outdir
        
        template_body = Measures::HTML::Writer.generate_nqf_template(measure, population)

        patient_caches = MONGO_DB['patient_cache'].where({'value.nqf_id'=>measure.measure_id, 'value.sub_id'=>sub_id})
        count = 0
        patient_caches.each do |cache|
          if cache['value']['IPP'] > 0
            count+=1
            locals ||= {}
            
            patient = patient_map[cache['value']['medical_record_id']]
            result = Measures::HTML::Writer.finalize_template_body(template_body,cache['value']['rationale'],patient)
            name = "#{cache['value']['last']}_#{cache['value']['first']}"
          
            if (sub_id)
              subdir = File.join(outdir,sub_id)
              FileUtils.mkdir_p subdir
              outfile_by_measure = File.join(subdir, "#{name}.html")
            else
              outfile_by_measure = File.join(outdir, "#{name}.html")
            end
            by_patient_outdir = File.join(basedir_by_patient,name)
            FileUtils.mkdir_p by_patient_outdir
            outfile_by_patient = File.join(by_patient_outdir, "#{measure.measure_id}#{sub_id}.html")
          
            File.open(outfile_by_measure, 'w') {|f| f.write(result) }
            File.open(outfile_by_patient, 'w') {|f| f.write(result) }
          end
        end
        puts "wrote #{count} measure #{measure.measure_id}#{sub_id} patients to: #{outdir}"
      end
    end
  end


  desc 'Generate measure rationale'
  task :generate_smoking_gun, [] do |t, args|
    
    def loop_data_criteria(measure, data_criteria, rationale, result)
      if (rationale[data_criteria.id])

        if data_criteria.type != :derived
          template = HQMF::DataCriteria.template_id_for_definition(data_criteria.definition, data_criteria.status, data_criteria.negation)
          value_set_oid = data_criteria.code_list_id
          begin
            qrda_template = HealthDataStandards::Export::QRDA::EntryTemplateResolver.qrda_oid_for_hqmf_oid(template,value_set_oid)
          rescue
            value_set_oid = 'In QRDA Header (Non Null Value)'
            qrda_template = 'N/A'
          end
          result << {description: data_criteria.description, oid: value_set_oid, template: qrda_template}

          if data_criteria.temporal_references
            data_criteria.temporal_references.each do |temporal_reference|
              if temporal_reference.reference.id != 'MeasurePeriod'
                loop_data_criteria(measure, measure.data_criteria(temporal_reference.reference.id), rationale, result)
              end
            end
          end
        else
          if data_criteria.children_criteria
            data_criteria.children_criteria.each do |child_id|
              loop_data_criteria(measure, measure.data_criteria(child_id), rationale, result)
            end
          end
        end
      end
    end

    def loop_preconditions(measure, parent, rationale, result)
      parent.preconditions.each do |precondition|
        parent_key = "precondition_#{parent.id}"
        key = "precondition_#{precondition.id}"
        if precondition.preconditions.empty?
          data_criteria = measure.data_criteria(precondition.reference.id)
          loop_data_criteria(measure, data_criteria, rationale, result)
        else
          if (rationale[parent_key] && rationale[key]) 
            loop_preconditions(measure, precondition, rationale, result)
          end
        end
      end
    end

    measures = Measure.all
    patient_map = Record.all.reduce({}) {|patient_map, patient| patient_map[patient.medical_record_number] = patient; patient_map}
    
    basedir = File.join('.', 'tmp','measures','smoking_gun')
    FileUtils.rm_r basedir if File.exists?(basedir)
    FileUtils.mkdir_p basedir
    
    population_keys = ('a'..'zz').to_a
    result = {}
    outfile = File.join(basedir, "smoking_gun.json")
    xlsfile_by_measure = File.join(basedir, "smoking_gun_by_measure.xlsx")
    xlsfile_by_patient = File.join(basedir, "smoking_gun_by_patient.xlsx")
    measures.sort {|l,r| l.measure_id <=> r.measure_id }.each do |measure|
      measure.populations.each_with_index do |population,index|

        sub_id = nil
        sub_id = population_keys[index] if measure.populations.length > 1

        result["#{measure.measure_id}#{sub_id}"] ||= {}

        hqmf_measure = measure.as_hqmf_model

        patient_caches = MONGO_DB['patient_cache'].where({'value.nqf_id'=>measure.measure_id, 'value.sub_id'=>sub_id})
        count = 0
        patient_caches.each do |cache|
          if cache['value']['IPP'] > 0

            rationale = cache['value']['rationale']

            result["#{measure.measure_id}#{sub_id}"]["#{cache['value']['first']}_#{cache['value']['last']}"] ||= {}
        
            HQMF::PopulationCriteria::ALL_POPULATION_CODES.each do |pop_code|
              if (population[pop_code])
                population_criteria = hqmf_measure.population_criteria(population[pop_code])
                if population_criteria.preconditions
                  array = []
                  result["#{measure.measure_id}#{sub_id}"]["#{cache['value']['first']}_#{cache['value']['last']}"]["#{pop_code}"] = array
                  parent = population_criteria.preconditions[0]
                  loop_preconditions(hqmf_measure, parent, rationale, array)
                end
              end
            end
        
          end
        end

        puts "wrote #{count} measure #{measure.measure_id}#{sub_id} patients to: #{outfile}"
      end
    end
    File.open(outfile, 'w') {|f| f.write(JSON.pretty_generate(result)) }

    require 'rubyXL'
    
    workbook = RubyXL::Workbook.new
    workbook.worksheets = []

    result.keys.each_with_index do |measure_id, index|
      worksheet = RubyXL::Worksheet.new(workbook)
      workbook.worksheets << worksheet
      worksheet.sheet_name = measure_id

      worksheet.add_cell(0,0,'Patient')
      worksheet.add_cell(0,1,'Attribute')
      worksheet.add_cell(0,2,'Value Set OID')
      worksheet.add_cell(0,3,'Template ID')

      row_index = 1;
      result[measure_id].keys.sort.each_with_index do |patient_name, patient_row|
        worksheet.add_cell(row_index, 0,patient_name)
        row_index+=1
        result[measure_id][patient_name].values.flatten.uniq.sort{|l,r| l[:description] <=> r[:description]}.each do |criteria|
          worksheet.add_cell(row_index, 1, criteria[:description])
          worksheet.add_cell(row_index, 2, criteria[:oid])
          worksheet.add_cell(row_index, 3, criteria[:template])
          row_index+=1
        end
      end

    end


    by_patient = {}
    result.keys.each_with_index do |measure_id, index|
      result[measure_id].keys.sort.each_with_index do |patient_name, patient_row|
        by_patient[patient_name] ||= {}
        by_patient[patient_name][measure_id] ||= result[measure_id][patient_name].values.flatten.uniq.sort{|l,r| l[:description] <=> r[:description]}
      end
    end

    workbook.write(xlsfile_by_measure)

    workbook = RubyXL::Workbook.new
    workbook.worksheets = []

    by_patient.keys.sort.each do |patient_name|
      worksheet = RubyXL::Worksheet.new(workbook)
      workbook.worksheets << worksheet
      worksheet.sheet_name = patient_name

      worksheet.add_cell(0,0,'Measure')
      worksheet.add_cell(0,1,'Attribute')
      worksheet.add_cell(0,2,'Value Set OID')
      worksheet.add_cell(0,3,'Template ID')

      row_index = 1;
      by_patient[patient_name].keys.sort.each do |measure_id|
        worksheet.add_cell(row_index, 0,measure_id)
        row_index+=1
        by_patient[patient_name][measure_id].each do |criteria|
          worksheet.add_cell(row_index, 1, criteria[:description])
          worksheet.add_cell(row_index, 2, criteria[:oid])
          worksheet.add_cell(row_index, 3, criteria[:template])
          row_index+=1
        end
      end
    end

    workbook.write(xlsfile_by_patient)

    puts "wrote #{xlsfile_by_measure}"
    puts "wrote #{xlsfile_by_patient}"


  end
  
end