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
  task :export, [:calculate] do |t, args|
    calculate = args.calculate != 'false'
    
    measures = Measure.all.to_a
    zip = Measures::Exporter.export_bundle(measures, calculate)
    
    version = APP_CONFIG["measures"]["version"]
    bundle_path = File.join(".", "tmp", "bundles")
    date_string = Time.now.strftime("%Y-%m-%d")
    
    FileUtils.mkdir_p bundle_path
    FileUtils.mv(zip.path, File.join(bundle_path, "bundle-#{date_string}-#{version}.zip"))
    puts "Exported #{measures.size} measures to #{File.join(bundle_path, "bundle-#{date_string}-#{version}.zip")}"
  end

  desc 'Load a directory of measures and value sets into the DB'
  task :load, [:measures_dir, :username, :delete_existing] do |t, args|
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

  desc 'Remove the measures and bundles collection'
  task :drop_measures do
    loader = Measures::Loader.new()
    loader.drop_measures()
  end

  desc 'Drop all measure defintions from the DB'
  task :drop_all, [:username] do |t, args|
    raise "The username to load the measures for must be specified" unless args.username

    user = User.by_username args.username
    raise "The user #{args.username} could not be found." unless user

    count = user.measures.destroy_all
    puts "Deleted #{count} measures assigned to #{user.username}"
  end
end
