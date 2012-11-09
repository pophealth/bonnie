require File.expand_path('../../../config/environment',  __FILE__)
require 'pathname'
require 'fileutils'
require './lib/measures/database_access'
require './lib/measures/exporter'

namespace :measures do
  desc 'Load a directory of measures and value sets into the DB'
  task :load, [:measures_dir, :username, :delete_existing] do |t, args|
    raise "The path to the measure definitions must be specified" unless args.measures_dir
    raise "The username to load the measures for must be specified" unless args.username

    user = User.by_username args.username
    raise "The user #{args.username} could not be found." unless user

    # Delete all of this user's measures out of the DB and remove any lingering files saved from the last load
    if args.delete_existing
      user.measures.each {|measure| measure.value_sets.destroy_all}
      count = user.measures.destroy_all
      
      source_dir = File.join(".", "db", "measures")
      FileUtils.rm_r Dir.glob(source_dir)
      
      puts "Deleted #{count} measures assigned to #{user.username}"
    end
    
    # Load each measure from the measures directory
    Dir.foreach(args.measures_dir) do |entry|
      next if entry.starts_with? '.'

      measure_dir = File.join(args.measures_dir,entry)
      hqmf_path = Dir.glob(File.join(measure_dir,'*.xml')).first
      codes_path = Dir.glob(File.join(measure_dir,'*.xls')).first
      html_path = Dir.glob(File.join(measure_dir,'*.html')).first
      begin
        measure = Measures::Loader.load(hqmf_path, codes_path, user, nil, true, html_path)
        puts "Measure #{measure.measure_id} (#{measure.title}) successfully loaded.\n"
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
      
      measure = Measures::Loader.load(hqmf_path, nil, nil, nil, false, nil)
      
      measure_out_dir = File.join(base_dir,measure.measure_id)
      FileUtils.mkdir_p measure_out_dir
      FileUtils.cp(hqmf_path, File.join(measure_out_dir,"#{measure.measure_id}.xml"))
      FileUtils.cp(codes_path, File.join(measure_out_dir,"#{measure.measure_id}.xls")) if codes_path
      FileUtils.cp(html_path, File.join(measure_out_dir,"#{measure.measure_id}.html"))
      
      puts "copied #{measure.measure_id} resources to #{measure_out_dir}"
      
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
  
end