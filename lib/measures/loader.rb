module Measures
  # Utility class for loading measure definitions into the database
  class Loader

    SOURCE_PATH = File.join(".", "db", "measures")
    
    def self.load_hqmf(hqmf_contents, user, codes_by_oid)

      hqmf = HQMF::Parser.parse(hqmf_contents, HQMF::Parser::HQMF_VERSION_1, codes_by_oid)
      # go into and out of json to make sure that we've converted all the symbols to strings, this will happen going to mongo anyway if persisted
      json = JSON.parse(hqmf.to_json.to_json, max_nesting: 250)

      measure_oids = codes_by_oid.keys if codes_by_oid
      Measures::Loader.load_hqmf_json(json, user, measure_oids)
    end

    def self.load_hqmf_json(json, user, measure_oids)

      measure = Measure.new
      measure.user = user

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
      measure.value_set_oids = measure_oids

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
    
    def self.load_value_sets_from_xls(value_set_path)
      value_set_parser = HQMF::ValueSet::Parser.new()
      value_sets = value_set_parser.parse(value_set_path)
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

    def self.load_paths(paths, username, rebuild=true, calculate=false, vs_username = nil, vs_password=nil)

      user = User.where({username:username}).first

      measures = []
      paths.each do |path|
        hqmf_path = Dir.glob(File.join(path,'*.xml')).first
        html_path = Dir.glob(File.join(path,'*.html')).first
        json_path = Dir.glob(File.join(path,'*.json')).first
        xls_path = Dir.glob(File.join(path,'*.xls')).first

        measure = nil
        if json_path

          json = JSON.parse(File.read(json_path), max_nesting: 250)
          hqmf_model = HQMF::Document.from_json(json)
          measure = Measures::Loader.load_hqmf_json(json, user, hqmf_model.all_code_set_oids)
          measure.save!
          Measures::Loader.save_sources(measure, hqmf_path, html_path)

        else
          original_stdout = $stdout
          $stdout = StringIO.new
          begin
            measure = Measures::Loader.load(hqmf_path, nil, nil, false)
          ensure
            $stdout = original_stdout
          end

          oids = {measure.hqmf_id => measure.as_hqmf_model.all_code_set_oids} unless (xls_path)

          measure = Measures::Loader.load(hqmf_path, user, html_path, true, oids, vs_username, vs_password, xls_path)
        end
        measures << measure
        puts "successfully loaded: #{measure.measure_id}"

      end

      Measures::Calculator.calculate(!calculate, measures) if(rebuild)

    end

    def self.load_from_bundle(bundle_path, username, type, json_draft_measures, rebuild)

      hash = Digest::MD5.hexdigest(bundle_path)

      base_out_dir = File.join(Rails.root,'tmp','bonnie',hash,'measures')

      FileUtils.rm_r base_out_dir if File.exist? base_out_dir
      FileUtils.mkdir_p(base_out_dir)

      paths = Set.new
      source_root = File.join('sources',type || '**','**')
      Zip::ZipFile.open(bundle_path) do |zip_file|
        entries = zip_file.glob(File.join(source_root,'**.html')) + zip_file.glob(File.join(source_root,'**1.xml'))
        entries += zip_file.glob(File.join(source_root,'**.json')) if json_draft_measures

        entries.each do |entry|
          pathname = Pathname.new(entry.name)
          filename = pathname.basename.to_s
          measure_id = pathname.each_filename().to_a[-2]
          outdir = File.join(base_out_dir,measure_id)
          FileUtils.mkdir_p(outdir)
          paths << outdir
          entry.extract(File.join(outdir,filename))
        end

      end

      load_paths(paths, username, rebuild, rebuild)

    end

    def self.load_from_url(url, use_cached=true)

      uri = URI.parse(url)
      hash = Digest::MD5.hexdigest(url)

      base_out_dir = File.join(Rails.root,'tmp','bonnie',hash)
      source_zip = File.join(base_out_dir, 'measures_source.zip')
      subzip_dir = File.join(base_out_dir, 'subzips')
      measure_out_dir = File.join(base_out_dir, 'measures')

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
      FileUtils.rm_r Dir.glob(subzip_dir) if File.exist? subzip_dir
      FileUtils.rm_r Dir.glob(measure_out_dir) if File.exist? measure_out_dir
      FileUtils.mkdir_p(subzip_dir)
      FileUtils.mkdir_p(measure_out_dir)

      measure_data = []
      Zip::ZipFile.open(source_zip) do |zip_file|
        sub_zips = zip_file.glob(File.join('**','**.zip'))

        extracted_sub_zips = []
        sub_zips.each do |file|
          out_path=File.join(subzip_dir, file.name)
          FileUtils.mkdir_p(File.dirname(out_path))
          zip_file.extract(file, out_path) unless File.exist?(out_path)
          extracted_sub_zips << File.new(out_path)
        end

        measure_data = extract_mat_exports(extracted_sub_zips, measure_out_dir)
      end

      measure_data

    end

    def self.load_mat_exports(files, username)
      Dir.mktmpdir do |dir|
        data = extract_mat_exports(files, dir)

        paths = []
        data.each do |measure_data|
          paths << measure_data['source_path']
          measures = User.by_username(username).measures.where({hqmf_id: measure_data['id']})
          measures.each do |measure|
            HealthDataStandards::SVS::ValueSet.in(oid: measure.value_set_oids).delete_all
            HealthDataStandards::CQM::Measure.where(hqmf_id: measure.hqmf_id).destroy_all
            measure.delete
          end
        end

        load_paths(paths, username, true, true)
      end
    end

    def self.extract_mat_exports(files, dir)
        data = []

        files.each do |file|
          Zip::ZipFile.open(file.path) do |zip_file|

            xml_files = zip_file.glob(File.join('**','**.xml'))
            html_files = zip_file.glob(File.join('**','**.html'))
            xls_files = zip_file.glob(File.join('**','**.xls'))

            measure_id = nil
            fields = nil
            xml_files.select! do |xml_file|
              these_fields = HQMF::Parser.parse_fields(xml_file.get_input_stream.read, HQMF::Parser::HQMF_VERSION_1) rescue {}
              
              if (these_fields['id'])
                measure_id = these_fields['id']
                fields = these_fields
              end
            end

            measure_data = {}
            measure_data = fields.merge(APP_CONFIG["measures"][fields['set_id']]) if APP_CONFIG["measures"][fields['set_id']]

            out_dir=File.join(dir, measure_id)
            FileUtils.mkdir_p(out_dir)

            (xml_files+html_files+xls_files).each do |file|
              zip_file.extract(file, File.join(out_dir,Pathname.new(file.name).basename.to_s))
            end

            measure_data['source_path'] = out_dir
            data << measure_data

          end
        end
        data

    end

    def self.load(hqmf_path, user, html_path=nil, persist = true, value_set_oids=nil, username=nil, password=nil, value_set_path=nil)
      
      
      hqmf_contents = Nokogiri::XML(File.new hqmf_path).to_s
      measure_id = HQMF::Parser.parse_fields(hqmf_contents, HQMF::Parser::HQMF_VERSION_1)['id']

      value_set_models = nil
      # Value sets
      if value_set_oids
        value_set_models = Measures::Loader.load_value_sets_from_service(value_set_oids, measure_id, username, password)
      elsif value_set_path
        value_set_models = Measures::Loader.load_value_sets_from_xls(value_set_path)
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
      
      Measures::Loader.save_sources(measure, hqmf_path, html_path, value_set_path)

      measure.save! if persist
      measure
    end

    def self.save_sources(measure, hqmf_path, html_path, value_set_path=nil)
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
    end
  end
end
