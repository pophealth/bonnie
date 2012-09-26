module Measures
  # Exports measure defintions in a pophealth compatible format
  class Exporter
    # Do all preparation for exporting a bundle.
    # We make sure all JS libraries are loaded, refresh the bundle/measures collections, and calculate measures results.
    #
    # @param [Array] measures All the measures that will be calculated for export. Defaults to all measures.
    def self.prepare_export(measures = Measure.all)      
      refresh_js_libraries
      
      # QME requires that the bundle collection be populated.
      MONGO_DB['bundles'].drop
      bundle = Measures::Exporter.bundle_json([], [], library_functions.keys)
      bundle_id = MONGO_DB["bundles"] << bundle
      
      # Delete all old results for these measures because they might be out of date.
      MONGO_DB['query_cache'].remove({})
      MONGO_DB['patient_cache'].remove({})
      MONGO_DB['measures'].drop
      Record.where(type: 'qrda').destroy
      
      # Break apart each measure into its submeasures and store as JSON into the measures collection for QME
      measures.each_with_index do |measure, measure_index|
        sub_ids = ("a".."zz").to_a
        measure.populations.each_with_index do |population, index|
          puts "calculating (#{measure_index+1}/#{measures.count}): #{measure.measure_id}#{sub_ids[index]}"
          
          measure_json = Measures::Exporter.measure_json(measure.measure_id, index)
          measure_id = MONGO_DB["measures"] << measure_json

          MONGO_DB["bundles"].update({}, {"$push" => {"measures" => measure_id}})
          
          effective_date = HQMF::Value.new("TS", nil, measure.measure_period["high"]["value"], true, false, false).to_time_object.to_i
          report = QME::QualityReport.new(measure_json[:id], measure_json[:sub_id], {'effective_date' => effective_date })
          report.calculate(false) unless report.calculated?
        end
        qrda_patient(measure).save
      end
    end
    
    # Export all measures, their test decks, necessary JS libraries, and expected results to a zip file.
    #
    # @param [Array] measures All measures that we're exporting. Defaults to all measures.
    # @param [Boolean] preparation_needed Whether or not we need to prepare the export first. Defaults to true.
    # @return A bundle containing all measures, matching test patients, and some additional goodies.
    def self.export_bundle(measures = Measure.all.to_a, preparation_needed = true)
      prepare_export if preparation_needed

      file = Tempfile.new("bundle-#{Time.now.to_i}")
      patient_ids = []
      measure_ids = []

      Zip::ZipOutputStream.open(file.path) do |zip|
        library_functions_to_zip(zip, "library_functions")
        
        types = ["qrda"].concat Measure::TYPES
        types.each do |type|
          measure_ids.concat measures_to_zip(zip, type)
          Measure.where(:type => type).each do |measure|
            puts "Exporting: #{measure.measure_id}"
            source_to_zip(zip, File.join("sources", type), measure) rescue nil
          end
          Record.where(type: type).each do |patient|
            patient_ids << patient_to_zip(zip, File.join("patients", type), patient)
          end
        end
        
        bundle_to_zip(zip, measure_ids, patient_ids)
        results_to_zip(zip, "results", measures)
      end
      
      file.close
      file
    end

    def self.library_functions_to_zip(zip, path)
      Measures::Exporter.library_functions.each do |name, contents|
        zip.put_next_entry(File.join(path, "#{name}.js"))
        zip << contents
      end
    end
    
    def self.measures_to_zip(zip, type)
      measure_ids = []
      MONGO_DB["measures"].find({type: type}).each do |measure_json|
        measure_ids << measure_json["id"]
        zip.put_next_entry(File.join(File.join("measures", type), "#{measure_json['nqf_id']}#{measure_json['sub_id']}.json"))
        zip << JSON.pretty_generate(measure_json.as_json(:except => [ '_id' ]), max_nesting: 250)
      end
      
      measure_ids
    end

    def self.source_to_zip(zip, path, measure)
      # Collect the source files.
      source_html = File.read(File.expand_path(File.join(".", "db", "measures", "html", "#{measure.id}.html")))
      source_value_sets = File.read(File.expand_path(File.join(".", "db", "measures", "value_sets", "#{measure.id}.xls")))
      source_hqmf1 = File.read(File.expand_path(File.join(".", "db", "measures", "hqmf", "#{measure.id}.xml")))
      generated_hqmf2 = HQMF2::Generator::ModelProcessor.to_hqmf(measure.as_hqmf_model)

      # Add source files to the zip.
      zip.put_next_entry(File.join(path, measure.measure_id, "#{measure.measure_id}.html"))
      zip << source_html
      zip.put_next_entry(File.join(path, measure.measure_id, "#{measure.measure_id}.xls"))
      zip << source_value_sets
      zip.put_next_entry(File.join(path, measure.measure_id, "hqmf1.xml"))
      zip << source_hqmf1
      zip.put_next_entry(File.join(path, measure.measure_id, "hqmf2.xml"))
      zip << generated_hqmf2
    end
    
    def self.bundle_to_zip(zip, measure_ids, patient_ids)
      bundle = Measures::Exporter.bundle_json(patient_ids, measure_ids, library_functions.keys)
      zip.put_next_entry("bundle.json")
      zip << JSON.pretty_generate(bundle)
    end
    
    def self.results_to_zip(zip, path, measures)
      results_by_patient = MONGO_DB['patient_cache'].find({}).to_a
      results_by_measure = MONGO_DB['query_cache'].find({}).to_a
      
      zip.put_next_entry(File.join(path, "by_patient.json"))
      zip << results_by_patient.to_json
      zip.put_next_entry(File.join(path, "by_measure.json"))
      zip << results_by_measure.to_json
    end

    def self.patient_to_zip(zip, path, patient)
      begin
      filename = TPG::Exporter.patient_filename(patient)
    rescue
      binding.pry
    end
  
      zip.put_next_entry(File.join(path, "c32", "#{filename}.xml"))
      zip << HealthDataStandards::Export::C32.export(patient)      
      
      zip.put_next_entry(File.join(path, "ccda", "#{filename}.xml"))
      zip << HealthDataStandards::Export::CCDA.export(patient)
      
      zip.put_next_entry(File.join(path, "ccr", "#{filename}.xml"))
      zip << HealthDataStandards::Export::CCR.export(patient)
      
      zip.put_next_entry(File.join(path, "json", "#{filename}.json"))
      zip << JSON.pretty_generate(JSON.parse(patient.as_json(:except => [ '_id', 'measure_id' ]).to_json))
      
      zip.put_next_entry(File.join(path, "html", "#{filename}.html"))
      zip << TPG::Exporter.html_contents(patient)
      
      patient.medical_record_number
    end

    def self.qrda_patient(measure)
      measure_needs = {}
      measure_value_sets = {}
      measure_needs[measure.hqmf_id] = measure.as_hqmf_model.referenced_data_criteria
      measure_value_sets[measure.hqmf_id] = measure.value_sets
      
      patients = HQMF::Generator.generate_qrda_patients(measure_needs, measure_value_sets)
      patients[measure.hqmf_id]
    end

    def self.library_functions
      library_functions = {}
      library_functions['map_reduce_utils'] = File.read(File.join('.','lib','assets','javascripts','libraries','map_reduce_utils.js'))
      library_functions['underscore_min'] = File.read(File.join('.','app','assets','javascripts','_underscore-min.js'))
      library_functions['hqmf_utils'] = HQMF2JS::Generator::JS.library_functions
      library_functions
    end
    
    def self.measure_json(measure_id, population_index=0)
      population_index ||= 0
      
      measure = Measure.by_measure_id(measure_id).first
      buckets = measure.parameter_json(population_index, true)
      
      json = {
        id: measure.hqmf_id,
        nqf_id: measure.measure_id,
        hqmf_id: measure.hqmf_id,
        hqmf_set_id: measure.hqmf_set_id,
        hqmf_version_number: measure.hqmf_version_number,
        endorser: measure.endorser,
        name: measure.title,
        description: measure.description,
        type: measure.type,
        category: measure.category,
        steward: measure.steward,
        population: buckets["population"],
        denominator: buckets["denominator"],
        numerator: buckets["numerator"],
        exclusions: buckets["exclusions"],
        map_fn: measure_js(measure, population_index),
        measure: popHealth_denormalize_measure_attributes(measure)
      }
      
      if (measure.populations.count > 1)
        sub_ids = ('a'..'az').to_a
        json[:sub_id] = sub_ids[population_index]
        population_title = measure.populations[population_index]['title']
        json[:subtitle] = population_title
        json[:short_subtitle] = population_title
        json[:hqmf_id] = measure.hqmf_id
        json[:hqmf_set_id] = measure.hqmf_set_id
        json[:hqmf_version_number] = measure.hqmf_version_number
      end
      
      population_ids = {}
      ['IPP','DENOM','NUMER','EXCL','DENEXCEP'].each do |type|
        population_key = measure.populations[population_index][type]
        population_criteria = measure.population_criteria[population_key]
        if (population_criteria)
          population_ids[type] = population_criteria['hqmf_id']
        end
      end
      stratification = measure['populations'][population_index]['stratification']
      if stratification
        population_ids['stratification'] = stratification 
      end
      json[:population_ids] = population_ids
      json
    end

    def self.refresh_js_libraries
      MONGO_DB['system.js'].remove({})
      Measures::Exporter.library_functions.each do |name, contents|
        QME::Bundle.save_system_js_fn(MONGO_DB, name, contents)
      end
    end

    def self.bundle_json(patient_ids, measure_ids, library_names)
      {
        title: APP_CONFIG["measures"]["title"],
        version: APP_CONFIG["measures"]["version"],
        license: APP_CONFIG["measures"]["license"],
        measures: measure_ids,
        patients: patient_ids,
        exported: Time.now.strftime("%Y-%m-%d"),
        extensions: library_functions.keys
      }
    end

    def self.popHealth_denormalize_measure_attributes(measure)
      measure_attributes = {}

      return measure_attributes unless (APP_CONFIG['generate_denormalization'])

      attribute_template = {"type"=> "array","items"=> {"type"=> "number","format"=> "utc-sec"}}

      data_criteria = measure.data_criteria_by_oid
      value_sets = measure.value_sets

      value_sets.each do |value_set|
        criteria = data_criteria[value_set.oid]
        if (criteria)
          template = attribute_template.clone
          template["standard_concept"] = value_set.concept

          template["standard_category"] = criteria["standard_category"]
          template["qds_data_type"] = criteria["qds_data_type"]

          value_set.code_sets.each do |code_set|
            template["codes"] ||= []
            unless (code_set.oid.nil?)
              template["codes"] << {
                "set"=> code_set.code_set,
                "version"=> code_set.version,
                "values"=> code_set.codes
              }
            else
              Kernel.warn("Bad Code Set found for value set: #{value_set.oid}")
            end
          end
          measure_attributes[value_set.key] = template
        else
          #Kernel.warn("Value set not used by a data criteria #{value_set.oid}")
        end

      end

      return measure_attributes
    end

    def self.measure_codes(measure)
      HQMF2JS::Generator::CodesToJson.from_value_sets(measure.value_sets)
    end

    private

    def self.measure_js(measure, population_index)
      "function() {
        var patient = this;
        var effective_date = <%= effective_date %>;

        hqmfjs = {}
        <%= init_js_frameworks %>
        
        #{execution_logic(measure, population_index)}
      };
      "
    end
    
    def self.execution_logic(measure, population_index=0)
      gen = HQMF2JS::Generator::JS.new(measure.as_hqmf_model)
      codes = measure_codes(measure)
      "
      var patient_api = new hQuery.Patient(patient);

      #{Measures::Exporter.check_disable_logger}

      // clear out logger
      if (typeof Logger != 'undefined') Logger.logger = [];
      // turn on logging if it is enabled
      if (Logger.enabled) enableLogging();
      
      #{gen.to_js(codes, population_index)}

      hqmfjs.initializeSpecifics(patient_api, hqmfjs)
      
      var population = function() {
        return executeIfAvailable(hqmfjs.IPP, patient_api);
      }
      var denominator = function() {
        return executeIfAvailable(hqmfjs.DENOM, patient_api);
      }
      var numerator = function() {
        return executeIfAvailable(hqmfjs.NUMER, patient_api);
      }
      var exclusion = function() {
        return executeIfAvailable(hqmfjs.EXCL, patient_api);
      }
      var denexcep = function() {
        return executeIfAvailable(hqmfjs.DENEXCEP, patient_api);
      }
      
      var executeIfAvailable = function(optionalFunction, arg) {
        if (typeof(optionalFunction)==='function')
          return optionalFunction(arg);
        else
          return false;
      }

      if (Logger.enabled) enableMeasureLogging(hqmfjs);

      map(patient, population, denominator, numerator, exclusion, denexcep);
      "
    end

    def self.check_disable_logger
      if (APP_CONFIG['disable_logging'])
        "      // turn off the logger \n"+
        "      Logger.enabled = false;\n"
      else
        ""
      end
    end

  end
end
