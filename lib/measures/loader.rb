module Measures
  # Utility class for loading measure definitions into the database
  class Loader
    
    def self.load_hqmf(hqmf_contents, user, codes_by_oid)

      measure = Measure.new
      measure.user = user

      hqmf = HQMF::Parser.parse(hqmf_contents, HQMF::Parser::HQMF_VERSION_1, codes_by_oid)
      # go into and out of json to make sure that we've converted all the symbols to strings, this will happen going to mongo anyway if persisted
      json = JSON.parse(hqmf.to_json.to_json, max_nesting: 250)

      measure.id = json["hqmf_id"]
      measure.measure_id = json["id"]
      measure.hqmf_id = json["hqmf_id"]
      measure.hqmf_set_id = json["hqmf_set_id"]
      measure.hqmf_version_number = json["hqmf_version_number"]
      measure.title = json["title"]
      measure.description = json["description"]
      measure.measure_attributes = json["attributes"]
      measure.populations = json['populations']

      metadata = APP_CONFIG["measures"][measure.hqmf_set_id]
      if metadata
        measure.measure_id = metadata["nqf_id"]
        measure.type = metadata["type"]
        measure.category = metadata["category"]
        measure.episode_of_care = metadata["episode_of_care"]
        measure.episode_id = metadata["episode_id"]
        if (measure.populations.count > 1)
          sub_ids = ('a'..'az').to_a
          measure.populations.each_with_index do |population, population_index|
            sub_id = sub_ids[population_index]
            population_title = metadata['subtitles'][sub_id] if metadata['subtitles']
            measure.populations[population_index]['title'] = population_title if population_title
          end
        end
      else
        measure.type = "unknown"
        measure.category = "Miscellaneous"
        measure.episode_of_care = false
        puts "\tWARNING: Could not find metadata for measure: #{measure.hqmf_set_id}"
      end

      measure.population_criteria = json["population_criteria"]
      measure.data_criteria = json["data_criteria"]
      measure.source_data_criteria = json["source_data_criteria"]
      measure.measure_period = json["measure_period"]
      measure
    end
    
    def self.load_value_sets_from_xls(value_set_path, value_set_format)
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
        value_set_models << set
      end
      value_set_models
    end
    
    def self.load_value_sets_from_service(value_set_oids, measure_id, username='rdingwell', password='TestTest1234')
      
      value_set_models = []
      
      existing_value_set_map = {}
      ValueSet.all.each do |set|
        existing_value_set_map[set.oid] = set
      end
      
      nlm_config = APP_CONFIG["nlm"]

      errors = {}
      api = HealthDataStandards::Util::VSApi.new(nlm_config["ticket_url"],nlm_config["api_url"],username, password)
      
      RestClient.proxy = ENV["http_proxy"]
      value_set_oids[measure_id].each_with_index do |oid,index| 

        set = existing_value_set_map[oid]
        
        if (set.nil?)
          vs_data = api.get_valueset(oid) 
          vs_data.force_encoding("utf-8") # there are some funky unicodes coming out of the vs response that are not in ASCII as the string reports to be
          doc = Nokogiri::XML(vs_data)

          doc.root.add_namespace_definition("vs","urn:ihe:iti:svs:2008")
          vs_element = doc.at_xpath("/vs:RetrieveValueSetResponse/vs:ValueSet")

          if vs_element && vs_element["ID"] == oid
            vs_element["id"] = oid

            vs = HealthDataStandards::SVS::ValueSet.load_from_xml(doc)

            value_set = { 
               key: vs.display_name.parameterize('_'),
               organization: nil,
               oid: oid,
               concept: nil,
               category: nil,
               version: vs.version,
               description: vs.display_name,
               code_sets: [ ],
            }

            concepts_by_system = {}
            vs.concepts.each do |concept|
              concepts_by_system[concept.code_system_name] ||= []
              concepts_by_system[concept.code_system_name] << concept.code
            end

            concepts_by_system.each do |key, values|
              if key != 'AdministrativeSex'
                oid = HealthDataStandards::Util::CodeSystemHelper.oid_for_code_system(key)
                puts "\tbad code system name: #{key}" unless oid
              end
              
              value_set[:code_sets] << { 
                codes: values,
                key: nil,
                organization: nil,
                oid: nil,
                concept: nil,
                category: nil,
                code_set: key,
                version: nil,
                description: nil 
              }
            end
            
            set = ValueSet.new(value_set)
          else
            raise "Value set not found: #{oid}"
          end
        
        else
          value_set = set.attributes
          value_set.delete('_id')
          value_set.delete('measure_id')
          value_set['code_sets'].each do |cs|
            cs.delete('_id')
          end
          set = ValueSet.new(value_set)
        end

        value_set_models << set

      end
      
      value_set_models
      
    end
    
    def self.load(hqmf_path, user, html_path=nil, persist = true, value_set_oids=nil, value_set_path=nil, value_set_format=nil)
      
      hqmf_contents = Nokogiri::XML(File.new hqmf_path).to_s
      measure_id = HQMF::Parser.parse_id(hqmf_contents, HQMF::Parser::HQMF_VERSION_1)

      value_set_models = nil
      # Value sets
      if value_set_oids
        value_set_models = Measures::Loader.load_value_sets_from_service(value_set_oids, measure_id)
      elsif value_set_path
        value_set_models = Measures::Loader.load_value_sets_from_xls(value_set_path, value_set_format)
      end
      
      # Parsed HQMF
      codes_by_oid = HQMF2JS::Generator::CodesToJson.from_value_sets(value_set_models) if (value_set_models.present?)
      measure = Measures::Loader.load_hqmf(hqmf_contents, user, codes_by_oid)
      
      value_set_models.each do |vsm|
        vsm.measure = measure
        vsm.save!
      end if value_set_models
      
      # Save original files
      if (html_path)
        html_out_path = File.join(".", "db", "measures", "html")
        FileUtils.mkdir_p html_out_path
        FileUtils.cp(html_path, File.join(html_out_path,"#{measure.hqmf_id}.html"))
      end
      
      if (value_set_path)
        value_set_out_path = File.join(".", "db", "measures", "value_sets")
        FileUtils.mkdir_p value_set_out_path
        FileUtils.cp(value_set_path, File.join(value_set_out_path,"#{measure.hqmf_id}.xls"))
      end
      
      hqmf_out_path = File.join(".", "db", "measures", "hqmf")
      FileUtils.mkdir_p hqmf_out_path
      FileUtils.cp(hqmf_path, File.join(".", "db", "measures", "hqmf", "#{measure.hqmf_id}.xml"))

      measure.save! if persist
      measure
    end
  end
end
