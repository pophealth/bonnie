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
    puts "Deleted #{deleted_records} record#{deleted_records.pluralize}." if args.delete_existing
    puts "Loaded #{delta_records} record#{delta_records.pluralize}. Total records: #{total_records}."
  end
end