require File.expand_path('../../../config/environment',  __FILE__)
require 'pathname'
require 'fileutils'
require './lib/measures/database_access'
require './lib/measures/exporter'

namespace :measures do
  desc 'Export definition for a single measure.'
  task :export,[:hqmf_id] do |t, args|
    measures = Measure.where(:hqmf_id => args.hqmf_id).to_a
    zip = Measures::Exporter.export_bundle(measure, true)
    
    bundle_path = File.join(".", "db", "bundles")
    FileUtils.mkdir_p bundle_path
    FileUtils.mv(zip.path, File.join(bundle_path, "bundle-#{measure.hqmf_id}.zip"))
  end

  desc 'Export definitions for all measures'
  task :export_all, [:calculate] do |t, args|
    calculate = args.calculate != 'false'
    
    measures = Measure.all.to_a
    zip = Measures::Exporter.export_bundle(measures, calculate)
    
    version = APP_CONFIG["measures"]["version"]
    bundle_path = File.join(".", "tmp", "bundles")
    FileUtils.mkdir_p bundle_path
    date_string = Time.now.strftime("%Y-%m-%d")
    FileUtils.mv(zip.path, File.join(bundle_path, "bundle-#{date_string}-#{version}.zip"))
    puts "Exported #{measures.size} measures to #{File.join(bundle_path, "bundle-#{date_string}-#{version}.zip")}"
  end

  desc 'Remove the measures and bundles collection'
  task :drop_measures do
    loader = Measures::Loader.new()
    loader.drop_measures()
  end

  desc 'Load a measure defintion into the DB'
  task :load, [:hqmf_path, :codes_path, :username, :delete_existing] do |t, args|
    hqmf_path = args.hqmf_path
    codes_path = args.codes_path
    username = args.username
    delete_existing = args.delete_existing

    if delete_existing.nil? && username.in?(['true', 'false', nil])
      delete_existing = args.username
      username = args.codes_path
      codes_path = './test/fixtures/measure-defs/' + args.hqmf_path + '/' + args.hqmf_path + '.xls'
      hqmf_path = './test/fixtures/measure-defs/' + args.hqmf_path + '/' + args.hqmf_path + '.xml'
    end

    raise "The path the the HQMF file must be specified" unless hqmf_path
    raise "The path the the Codes file must be specified" unless codes_path
    raise "The username to load the measures for must be specified" unless username

    user = User.by_username username
    raise "The user #{username} could not be found." unless user

    if delete_existing == 'true'
      user.measures.each {|measure| measure.value_sets.destroy_all}
      count = user.measures.destroy_all
      puts "Deleted #{count} measures assigned to #{user.username}"
    end

    Measures::Loader.load(hqmf_path, codes_path, user)
  end

  desc 'Load a measure defintion into the DB'
  task :load_all, [:measures_dir, :username, :delete_existing] do |t, args|
    measures_dir = args.measures_dir.empty? ? './test/fixtures/measure-defs' : args.measures_dir
    raise "The path the the measure definitions must be specified" unless measures_dir
    raise "The username to load the measures for must be specified" unless args.username

    user = User.by_username args.username
    raise "The user #{args.username} could not be found." unless user

    if args.delete_existing
      # Delete all of this user's measures out of the DB
      user.measures.each {|measure| measure.value_sets.destroy_all}
      count = user.measures.destroy_all
      
      # Remove any lingering files saved from the last load
      source_dir = File.join(".", "db", "measures")
      FileUtils.rm_r Dir.glob(source_dir)
      
      puts "Deleted #{count} measures assigned to #{user.username}"
    end
    
    # Add all necessary JS libraries to system
    library_functions = {}
    library_functions['map_reduce_utils'] = File.read(File.join('.','lib','assets','javascripts','libraries','map_reduce_utils.js'))
    library_functions['underscore_min'] = File.read(File.join('.','app','assets','javascripts','_underscore-min.js'))
    library_functions['hqmf_utils'] = HQMF2JS::Generator::JS.library_functions

    library_functions.each do |library, contents|
      QME::Bundle.save_system_js_fn(MONGO_DB, library, contents)
    end

    # Load each measure from the measures directory
    Dir.foreach(measures_dir) do |entry|
      next if entry.starts_with? '.'
      measure_dir = File.join(measures_dir,entry)
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
  end
  
  desc 'Load a quality bundle into the database'
  task :import_bundle, [:bundle_path, :username, :delete_existing] do |task, args|
    raise "The path to the measures zip file must be specified" unless args.bundle_path
    raise "A username to assign the measures to must be specified" unless args.username

    bundle = File.open(args.bundle_path)
    importer = QME::Bundle::Importer.new(args.db_name)
    importer.import(bundle, args.delete_existing)
    
    user = User.by_username args.username
    Measure.all.each {|measure| measure.user = user }
  end

  desc 'Drop all measure defintions from the DB'
  task :drop_all, [:username] do |t, args|
    raise "The username to load the measures for must be specified" unless args.username

    user = User.by_username args.username
    raise "The user #{args.username} could not be found." unless user

    count = user.measures.delete_all
    puts "Deleted #{count} measures assigned to #{user.username}"
  end

  desc 'Convert a measure defintion to a format that can be loaded into popHealth'
  task :build, [:hqmf, :codes, :include_library, :patient] do |t, args|
    FileUtils.mkdir_p File.join(".", "db", "measures")
    hqmf_path = File.expand_path(args.hqmf)
    codes_path = File.expand_path(args.codes)
    filename = Pathname.new(hqmf_path).basename

    measure = Measures::Loader.load(hqmf_path, codes_path, nil, nil, false)
    measure_js = Measures::Exporter.execution_logic(measure)

    if args.patient
      patient_file = File.expand_path(args.patient)
      patient_json = File.read(patient_file)
    end

    out_file = File.join(".", "db", "measures", "#{filename}.js")
    File.open(out_file, 'w') do |f|
      if args.include_library
        library_functions = Measures::Exporter.library_functions
        ['underscore_min', 'map_reduce_utils'].each do |function|
          f.write("#{function}_js = function () { #{library_functions[function]} }\n")
          f.write("#{function}_js();\n")
        end
        f.write(library_functions['hqmf_utils'] + "\n")
      end

      f.write("execute_measure = function(patient) {\n #{measure_js} \n}\n")
      f.write("emitted = []; emit = function(id, value) { emitted.push(value); } \n")
      f.write("ObjectId = function(id, value) { return 1; } \n")

      if args.patient
        f.write("// #########################\n")
        f.write("// ######### PATIENT #######\n")
        f.write("// #########################\n\n")

        f.write("var patient = #{patient_json};\n")
      end

    end

    puts "wrote measure defintion to: #{out_file}"

    class ErbContext < OpenStruct
      def initialize(vars)
        super(vars)
      end
      def get_binding
        binding
      end
    end

    template_str = File.read(File.join('.', 'test', 'fixtures', 'html', 'test_measure.html.erb'))
    template = ERB.new(template_str, nil, '-', "_templ_html")
    params = {'measure_id' => filename}
    context = ErbContext.new(params)
    result = template.result(context.get_binding)

    out_file = File.join(".", "db", "measures", "#{filename}.html")
    File.open(out_file, 'w') do |f|
      f.write(result)
    end

    puts "wrote test html to: #{out_file}"
  end
end
