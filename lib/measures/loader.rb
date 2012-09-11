module Measures

  # Utility class for loading measure definitions into the database
  class Loader

    def self.load(hqmf_path, value_set_path, user, value_set_format=nil, persist = true, html_path=nil)
      measure = Measure.new

      # Meta data
      measure.user = user

      value_sets = nil
      # Value sets
      if value_set_path
        value_set_parser = HQMF::ValueSet::Parser.new()
        value_set_format ||= HQMF::ValueSet::Parser.get_format(value_set_path)
        value_sets = value_set_parser.parse(value_set_path, {format: value_set_format})
        value_set_models = []
        value_sets.each do |value_set|
          if value_set['code_sets'].include? nil
            puts "Value Set has a bad code set (code set is null)"
            value_set['code_sets'].compact!
          end
          set = ValueSet.new(value_set)
          set.measure = measure
          value_set_models << set
          set.save! if persist
        end
        measure.value_sets = value_set_models unless persist
      end

      # Parsed HQMF
      if hqmf_path
        codes_by_oid = HQMF2JS::Generator::CodesToJson.from_value_sets(measure.value_sets) if (value_sets)

        hqmf_contents = Nokogiri::XML(File.new hqmf_path).to_s
        hqmf = HQMF::Parser.parse(hqmf_contents, HQMF::Parser::HQMF_VERSION_1, codes_by_oid)
        # go into and out of json to make sure that we've converted all the symbols to strings, this will happen going to mongo anyway if persisted
        json = JSON.parse(hqmf.to_json.to_json, max_nesting: 250)

        measure.measure_id = json["id"]
        measure.title = json["title"]
        measure.description = json["description"]
        measure.measure_attributes = json["attributes"]
        measure.populations = json['populations']

        metadata = APP_CONFIG["measures"][measure.measure_id]
        if metadata
          measure.type = metadata["type"]
          measure.category = metadata["category"]
          measure.episode_of_care = metadata["episode_of_care"]
        else
          measure.type = "unknown"
          measure.category = "Miscellaneous"
          measure.episode_of_care = false
        end

        #measure.endorser = params[:measure][:endorser]
        #measure.steward = params[:measure][:steward]

        measure.population_criteria = json["population_criteria"]
        measure.data_criteria = json["data_criteria"]
        measure.source_data_criteria = json["source_data_criteria"]
        measure.measure_period = json["measure_period"]
      end

      # Save original files
      html_out_path = File.join(".", "db", "measures", "html")
      FileUtils.mkdir_p html_out_path
      FileUtils.cp(html_path, File.join(html_out_path,"#{measure._id}.html")) if html_path
      
      value_set_out_path = File.join(".", "db", "measures", "value_sets")
      FileUtils.mkdir_p value_set_out_path
      FileUtils.cp(value_set_path, File.join(value_set_out_path,"#{measure._id}.xls"))
      
      hqmf_out_path = File.join(".", "db", "measures", "hqmf")
      FileUtils.mkdir_p hqmf_out_path
      FileUtils.cp(hqmf_path, File.join(".", "db", "measures", "hqmf", "#{measure._id}.xml"))

      measure.save! if persist
      measure
    end
  end
end
