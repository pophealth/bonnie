namespace :patients do

  desc 'Load 225 patient records into MongoDB'
  task :load_all do |t|
    initial_records = Record.count
    json_file = File.open(Rails.root.join('test/fixtures/patients/patients.225.json'))
    json_array = []
    json_file.readlines.each do |line|
      json_array << JSON.parse(line)
    end
    
    json_array.each do |e|
      r = Record.new(e)
#      r.id = r.id['$oid']   # fix {"$oid"=>"4fa98071431a5fb25f000002"} as ID problem
      r.save
    end
    
    puts "Loaded #{Record.count - initial_records} Record documents.  Total Records: #{Record.count}."
  end

end