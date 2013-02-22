module Measures
  # Utility class for loading measure definitions into the database
  class Loader

    SOURCE_PATH = File.join(".", "db", "measures")
    
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
      measure.cms_id = json["cms_id"]
      measure.title = json["title"]
      measure.description = json["description"]
      measure.measure_attributes = json["attributes"]
      measure.populations = json['populations']
      measure.value_set_oids = codes_by_oid.keys if codes_by_oid

      metadata = APP_CONFIG["measures"][measure.hqmf_set_id]
      if metadata
        measure.measure_id = metadata["nqf_id"]
        measure.type = metadata["type"]
        measure.category = metadata["category"]
        measure.episode_of_care = metadata["episode_of_care"]
        measure.continuous_variable = metadata["continuous_variable"]
        measure.episode_ids = metadata["episode_ids"]
        puts "\tWARNING: Episode of care does not align with episode ids existance" if ((!measure.episode_ids.nil? && measure.episode_ids.length > 0) ^ measure.episode_of_care)
        if (measure.populations.count > 1)
          sub_ids = ('a'..'az').to_a
          measure.populations.each_with_index do |population, population_index|
            sub_id = sub_ids[population_index]
            population_title = metadata['subtitles'][sub_id] if metadata['subtitles']
            measure.populations[population_index]['title'] = population_title if population_title
          end
        end
        measure.custom_functions = metadata["custom_functions"]
      else
        measure.type = "unknown"
        measure.category = "Miscellaneous"
        measure.episode_of_care = false
        measure.continuous_variable = false
        puts "\tWARNING: Could not find metadata for measure: #{measure.hqmf_set_id}"
      end

      measure.population_criteria = json["population_criteria"]
      measure.data_criteria = json["data_criteria"]
      measure.source_data_criteria = json["source_data_criteria"]
      puts "\tCould not find episode ids #{measure.episode_ids} in measure #{measure.measure_id}" if (measure.episode_ids && measure.episode_of_care && (measure.episode_ids - measure.source_data_criteria.keys).length > 0)
      measure.measure_period = json["measure_period"]
      measure
    end
    
    def self.load_value_sets_from_xls(value_set_path, value_set_format)
      value_set_parser = HQMF::ValueSet::Parser.new()
      value_set_format ||= HQMF::ValueSet::Parser.get_format(value_set_path)
      value_sets = value_set_parser.parse(value_set_path, {format: value_set_format})
      value_sets
    end
    
    def self.load_value_sets_from_service(value_set_oids, measure_id, username, password)
      
      value_set_models = []
      
      existing_value_set_map = {}
      HealthDataStandards::SVS::ValueSet.all.each do |set|
        existing_value_set_map[set.oid] = set
      end
      
      nlm_config = APP_CONFIG["nlm"]

      errors = {}
      api = HealthDataStandards::Util::VSApi.new(nlm_config["ticket_url"],nlm_config["api_url"],username, password)
      
      codeset_base_dir = File.join('.','db','code_sets')
      FileUtils.mkdir_p(codeset_base_dir)

      RestClient.proxy = ENV["http_proxy"]
      value_set_oids[measure_id].each_with_index do |oid,index| 

        set = existing_value_set_map[oid]
        
        if (set.nil?)
          
          vs_data = nil
          
          cached_service_result = File.join(codeset_base_dir,"#{oid}.xml")
          if (File.exists? cached_service_result)
            vs_data = File.read cached_service_result
          else
            vs_data = api.get_valueset(oid) 
            vs_data.force_encoding("utf-8") # there are some funky unicodes coming out of the vs response that are not in ASCII as the string reports to be
            File.open(cached_service_result, 'w') {|f| f.write(vs_data) }
          end
          
          doc = Nokogiri::XML(vs_data)

          doc.root.add_namespace_definition("vs","urn:ihe:iti:svs:2008")
          
          vs_element = doc.at_xpath("/vs:RetrieveValueSetResponse/vs:ValueSet")

          if vs_element && vs_element["ID"] == oid
            vs_element["id"] = oid

            set = HealthDataStandards::SVS::ValueSet.load_from_xml(doc)
          else
            raise "Value set not found: #{oid}"
          end
        
        else
          value_set = set.attributes
          value_set.delete('_id')
          value_set.delete('measure_id')
          value_set['concepts'].each do |cs|
            cs.delete('_id')
          end
          set = HealthDataStandards::SVS::ValueSet.new(value_set)
        end

        value_set_models << set

      end
      
      value_set_models
      
    end

    def self.load_paths(paths, username)

      user = User.where({username:username}).first

      paths.each do |path|
        hqmf_path = Dir.glob(File.join(path,'*.xml')).first
        html_path = Dir.glob(File.join(path,'*.html')).first

        measure = nil
        original_stdout = $stdout
        $stdout = StringIO.new
        begin
          measure = Measures::Loader.load(hqmf_path, nil, nil, false)
        ensure
          $stdout = original_stdout
        end

        oids = {measure.hqmf_id => measure.as_hqmf_model.all_code_set_oids}

        Measures::Loader.load(hqmf_path, user, html_path, true, oids, 'rdingwell', 'TestTest1234')
        puts "loaded: #{hqmf_path}"

      end

#      calculate!!!
    end

    def self.load_from_url(url, use_cached=true)

      uri = URI.parse(url)
      hash = Digest::MD5.hexdigest(url)

      base_out_dir = File.join(Rails.root,'tmp','bonnie',hash)
      source_zip = File.join(base_out_dir, 'measures_source.zip')
      first_dir = File.join(base_out_dir, 'first_unzip')
      final_dir = File.join(base_out_dir, 'measures')

      if (!File.exists? source_zip || !use_cached)
        FileUtils.rm_r Dir.glob(base_out_dir) if File.exist? base_out_dir
        FileUtils.mkdir_p(base_out_dir)
        proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']
        connector = Net::HTTP
        if(proxy)
          proxy_uri = URI(proxy)
          connector = Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port)
        end
        connector.start(uri.host) { |http| open(source_zip, "wb") { |file| file.write(http.get(uri.path).body) } }
      end
      FileUtils.rm_r Dir.glob(first_dir) if File.exist? first_dir
      FileUtils.rm_r Dir.glob(final_dir) if File.exist? final_dir
      FileUtils.mkdir_p(first_dir)
      FileUtils.mkdir_p(final_dir)

      measure_data = []
      Zip::ZipFile.open(source_zip) do |zip_file|
        zip_file.each do |file|
          if file.name.match(/.*\.zip/)
            
            out_path=File.join(first_dir, file.name)
            FileUtils.mkdir_p(File.dirname(out_path))
            zip_file.extract(file, out_path) unless File.exist?(out_path)

            Zip::ZipFile.open(out_path) do |sub_zip|
              file_map = {}
              sub_zip.each do |sub_file|
                if sub_file.name.match(/.*\.xml/) || sub_file.name.match(/.*\.html/)
                  if sub_file.name.match(/.*\.xml/)
                    fields = HQMF::Parser.parse_fields(sub_file.get_input_stream.read, HQMF::Parser::HQMF_VERSION_1) rescue {}
                    if fields['id']
                      metadata = APP_CONFIG["measures"][fields['set_id']]
                      file_map[:hqmf] = sub_file
                      file_map[:fields] = fields.merge(metadata)
                    end
                  elsif sub_file.name.match(/.*\.html/)
                    file_map[:html] = sub_file
                  end
                end
              end

              nqf_id = file_map[:fields]['nqf_id']
              final_measure_path=File.join(final_dir, nqf_id)
              FileUtils.mkdir_p(final_measure_path)

              sub_zip.extract(file_map[:hqmf], File.join(final_measure_path,"#{nqf_id}.xml"))
              sub_zip.extract(file_map[:html], File.join(final_measure_path,"#{nqf_id}.html"))
              measure_data << {'source_path' => final_measure_path}.merge(file_map[:fields])
            end
          end
        end
      end

      measure_data

    end
    
    def self.load(hqmf_path, user, html_path=nil, persist = true, value_set_oids=nil, username=nil, password=nil, value_set_path=nil, value_set_format=nil)
      
      
      hqmf_contents = Nokogiri::XML(File.new hqmf_path).to_s
      measure_id = HQMF::Parser.parse_fields(hqmf_contents, HQMF::Parser::HQMF_VERSION_1)['id']

      value_set_models = nil
      # Value sets
      if value_set_oids
        value_set_models = Measures::Loader.load_value_sets_from_service(value_set_oids, measure_id, username, password)
      elsif value_set_path
        value_set_models = Measures::Loader.load_value_sets_from_xls(value_set_path, value_set_format)
      end
      

      if (value_set_models.present?)
        loaded_value_sets = HealthDataStandards::SVS::ValueSet.all.map(&:oid)
        value_set_models.each { |vsm| vsm.save! unless loaded_value_sets.include? vsm.oid } if persist
        codes_by_oid = HQMF2JS::Generator::CodesToJson.from_value_sets(value_set_models) 
      end

      # Parsed HQMF
      measure = Measures::Loader.load_hqmf(hqmf_contents, user, codes_by_oid)

      if value_set_models
        measure.value_set_oids = value_set_models.map(&:oid)
      end
      
      # Save original files
      if (html_path)
        html_out_path = File.join(SOURCE_PATH, "html")
        FileUtils.mkdir_p html_out_path
        FileUtils.cp(html_path, File.join(html_out_path,"#{measure.hqmf_id}.html"))
      end
      
      if (value_set_path)
        value_set_out_path = File.join(SOURCE_PATH, "value_sets")
        FileUtils.mkdir_p value_set_out_path
        FileUtils.cp(value_set_path, File.join(value_set_out_path,"#{measure.hqmf_id}.xls"))
      end
      
      hqmf_out_path = File.join(SOURCE_PATH, "hqmf")
      FileUtils.mkdir_p hqmf_out_path
      FileUtils.cp(hqmf_path, File.join(hqmf_out_path, "#{measure.hqmf_id}.xml"))

      measure.save! if persist
      measure
    end
  end
end
