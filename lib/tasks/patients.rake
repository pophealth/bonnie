namespace :patients do
  desc 'Load 225 patient records into MongoDB'
  task :load, [:patient_dir, :delete_existing] do |t, args|
    patient_dir = "test/fixtures/patients/patients.225.json" unless args.patient_dir
    
    deleted_records = Record.destroy_all if args.delete_existing
    initial_records = Record.count

    json_files = File.open(Rails.root.join(patient_dir))
    json_files.readlines.each do |json|
      patient_json = JSON.parse(json)
      patient = Record.new(patient_json)
      patient.save!
    end
    
    total_records = Record.count
    delta_records = total_records - initial_records
    puts "Deleted #{deleted_records} records." if args.delete_existing
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