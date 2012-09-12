module Measures
  # Exports measure defintions in a pophealth compatible format
  class Exporter
    # Export a list of patients to a zip file. Contains the proper formatting of a bundle for Cypress, i.e.:
    #
    # bundle.json
    #   title
    #   version
    #   measure_ids[]
    #   patient_ids[]
    #   library_functions[]
    #   measure_patient_results{}
    #     effective_date
    #     measure0000 (contains all populations, including multiples)
    #       IPP[] (contains patient IDs)
    # measures/ (contains types)
    #   eh/ (contains json)
    #   ep/
    # results/ (contains types)
    #   by_patient.json (patient cache)
    #   by_measure.json (query cache)
    # lib/ (contains js libraries for calculation)
    # patients/ (contains decks)
    #   qrda/ (contains formats)
    #     c32/ (contains patients by standard)
    #     ccr/
    #     json/
    #   eh/
    #   ep/
    # src/ (contains original documents)
    #   patients/ (contains html describing patients)
    #     qrda/ (contains html)
    #     eh/
    #     ep/
    #   measures/ (contains decks)
    #     eh/
    #       measure0000/ (contains source files)
    #         0000.html
    #         0000.xls
    #         hqmf1.xml
    #         hqmf2.xml
    #     ep/
    #
    # @param [Hash] measures Tests mapped to their list of meausres.
    # @param [Hash] patients Tests mapped to their list of patients.
    # @param [String] title The title of this bundle.
    # @param [String] version The version of this bundle.
    # @return A bundle containing all measures, matching test patients, and some additional goodies.
    def self.export_bundle(title, version, measures, patients)
      file = Tempfile.new("bundle-#{Time.now.to_i}")
      
      # Define paths to be used while generating the zip file.
      measures_path = "measures"
      libraries_path = "lib"
      patients_path = "patients"
      results_path = "results"
      source_path = "src"
      source_patients_path = File.join(source_path, "patients")
      source_measures_path = File.join(source_path, "measures")
      
      Zip::ZipOutputStream.open(file.path) do |zip|
        # Bundle up all of the measure information.
        measures.each do |test_type, test_measures|
          test_measures.each do |measure|
            measure_path = File.join(measures_path, test_type)
            source_measure_path = File.join(source_measures_path, test_type, measure.measure_id)
            
            # Add JSON definitions of all measures and sub-measures.
            (0..measure.populations.count-1).each do |population_index|
              # Generate the JSON for this measure.
              measure_json = Measures::Exporter.measure_json(measure.measure_id, population_index)
              zip.put_next_entry(File.join(measure_path, "#{measure.measure_id}#{measure_json[:sub_id]}.json"))
              zip << measure_json.to_json
            end
                        
            # Collect the source files.
            source_html = File.read(File.expand_path(File.join(".", "db", "measures", "html", "#{measure.id}.html")))
            source_value_sets = File.read(File.expand_path(File.join(".", "db", "measures", "value_sets", "#{measure.id}.xls")))
            source_hqmf1 = File.read(File.expand_path(File.join(".", "db", "measures", "hqmf", "#{measure.id}.xml")))
            generated_hqmf2 = HQMF2::Generator::ModelProcessor.to_hqmf(measure.as_hqmf_model)
              
            # Add source files to the zip.
            zip.put_next_entry(File.join(source_measure_path, "#{measure.measure_id}.html"))
            zip << source_html
            zip.put_next_entry(File.join(source_measure_path, "#{measure.measure_id}.xls"))
            zip << source_value_sets
            zip.put_next_entry(File.join(source_measure_path, "hqmf1.xml"))
            zip << source_hqmf1
            zip.put_next_entry(File.join(source_measure_path, "hqmf2.xml"))
            zip << generated_hqmf2
            
            # Delete all old results for this measure because they might be out of date.
            MONGO_DB['query_cache'].remove({'measure_id' => measure.measure_id})
            MONGO_DB['patient_cache'].remove({'value.measure_id' => measure.measure_id})
            
            # Calculate the results.
            sub_ids = measure.populations.size > 1 ? ("a".."zz").to_a.first(measure.populations.size) : [nil]
            sub_ids.each do |sub_id|
              effective_date = HQMF::Value.new("TS", nil, measure.measure_period["high"]["value"], true, false, false).to_time_object.to_i
              report = QME::QualityReport.new(measure.measure_id, sub_id, {'effective_date' => effective_date })
              report.calculate(false) unless report.calculated?
            end
          end
        end
        
        # Bundle up all of the test patients.
        patients.each do |test_type, test_patients|
          test_patients.each do |patient|
            filename = TPG::Exporter.patient_filename(patient)
        
            # Define path names.
            c32_path = File.join(patients_path, test_type, "c32", "#{filename}.xml")
            ccr_path = File.join(patients_path, test_type, "ccr", "#{filename}.xml")
            ccda_path = File.join(patients_path, test_type, "ccda", "#{filename}.xml")
            json_path = File.join(patients_path, test_type, "json", "#{filename}.json")
        
            # Generate a C32, CCR, and JSON file for each patient.
            zip.put_next_entry(c32_path)
            zip << HealthDataStandards::Export::C32.export(patient)
            zip.put_next_entry(ccda_path)
            zip << HealthDataStandards::Export::CCDA.export(patient)
            zip.put_next_entry(ccr_path)
            zip << HealthDataStandards::Export::CCR.export(patient)
            zip.put_next_entry(json_path)
            zip << JSON.pretty_generate(JSON.parse(patient.to_json))
            
            # Generate the source HTML.
            html_path = File.join(source_patients_path, test_type, "#{filename}.html")
            zip.put_next_entry(html_path)
            zip << TPG::Exporter.html_contents(patient)
          end
        end
        
        # Gather all measure results by patient and measure.
        measure_ids = measures.values.flatten.map{|measure| measure.measure_id}
        results_by_patient = MONGO_DB['patient_cache'].find({'value.measure_id' => {'$in' => measure_ids}}).to_a
        results_by_measure = MONGO_DB['query_cache'].find({'measure_id' => {'$in' => measure_ids}}).to_a
        
        zip.put_next_entry(File.join(results_path, "by_patient.json"))
        zip << results_by_patient.to_json
        zip.put_next_entry(File.join(results_path, "by_measure.json"))
        zip << results_by_measure.to_json
        
        # Gather all JS library files.
        library_functions = Measures::Exporter.library_functions
        library_functions.each do |name, contents|
          zip.put_next_entry(File.join(libraries_path, "#{name}.js"))
          zip << contents
        end
        
        # Add the bundle metadata.
        bundle_json = Measures::Exporter.bundle_json(title, version, patients.values.flatten, measures.values.flatten, library_functions.keys)
        zip.put_next_entry("bundle.json")
        zip << bundle_json.to_json
      end
      
      file.close
      file
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
        id: measure.measure_id,
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
      end
      
      json
    end

    # This assumes that results have already been calculated for all included measures.
    def self.bundle_json(title, version, patients, measures, library_names)
      patients_ids = patients.map{|patient| patient.id}
      measures_ids = measures.map{|measure| measure.id}
      
      {
        title: title,
        version: version,
        measure_ids: measures_ids,
        patient_ids: patients_ids,
        library_functions: library_functions.keys
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
