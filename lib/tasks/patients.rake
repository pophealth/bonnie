namespace :patients do
  desc 'Load patient records into MongoDB'
  task :load, [:patients_dir, :map_file, :delete_existing] do |t, args|
    
    patient_map = JSON.parse(File.read(args.map_file))

    if args.delete_existing
      deleted_records = Record.destroy_all 
      puts "Deleted #{deleted_records} records."
    end
    initial_records = Record.count

    json_files = Dir.glob("#{args.patients_dir}/**/*.json")
    json_files.each do |patients_file|
      puts "loaded: #{patients_file}"
      patient_json = JSON.parse(File.read(patients_file))
      patient_json['measure_ids'] = patient_map[patient_json['medical_record_number']]
      # patient = Record.new(patient_json)
      # patient.save!
      MONGO_DB['records'].insert patient_json
    end
    
    total_records = Record.count
    delta_records = total_records - initial_records
    puts "Loaded #{delta_records} records. Total records: #{total_records}."
  end

  desc 'Resave all records. Useful when something like code selection has changed but measures do not need to be reloaded'
  task :resave, [] do |t, args|
    patients = Record.all
    total = patients.count
    patients.each_with_index do |patient, i|

      measure_list = patient['measure_ids'] || []
      data_criteria = Measures::PatientBuilder.get_data_criteria(measure_list)
      dropped = Measures::PatientBuilder.check_data_criteria!(patient, data_criteria)

      throw "dropped data criteria for #{patient.first}, #{patient.last}" unless dropped.empty?

      Measures::PatientBuilder.rebuild_patient(patient)
      puts "resaved: #{i+1}/#{total}"
    end


  end
end