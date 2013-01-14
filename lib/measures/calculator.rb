module Measures
  class Calculator
	# Refresh all JS libraries, refresh the bundle/measures collections, and calculate measures results.
    #
    # @param [Array] measures All the measures that will be calculated. Defaults to all measures.
    def self.calculate(only_initialize=false, measures = Measure.all)      
      refresh_js_libraries
      
      # QME requires that the bundle collection be populated.
      MONGO_DB['bundles'].drop
      bundle = Measures::Exporter.bundle_json([], [], Measures::Calculator.library_functions.keys)
      MONGO_DB["bundles"].insert(JSON.parse(bundle.values.first))
      
      # Delete all old results for these measures because they might be out of date.
      MONGO_DB['query_cache'].find({}).remove_all unless only_initialize
      MONGO_DB['patient_cache'].find({}).remove_all unless only_initialize
      MONGO_DB['measures'].drop
      
      # Break apart each measure into its submeasures and store as JSON into the measures collection for QME
      measures.each_with_index do |measure, measure_index|
        sub_ids = ("a".."zz").to_a
        measure.populations.each_with_index do |population, index|
          puts "calculating (#{measure_index+1}/#{measures.count}): #{measure.measure_id}#{sub_ids[index]}"
          
          measure_json = Measures::Calculator.measure_json(measure.measure_id, index)
          MONGO_DB["measures"].insert(measure_json)
          measure_id = MONGO_DB["measures"].find({id: measure_json[:id]}).first
          MONGO_DB["bundles"].find({}).update({"$push" => {"measures" => measure_id}})
          
          effective_date = Measure::DEFAULT_EFFECTIVE_DATE
          oid_dictionary = HQMF2JS::Generator::CodesToJson.hash_to_js(Measures::Calculator.measure_codes(measure))
          report = QME::QualityReport.new(measure_json[:id], measure_json[:sub_id], {'effective_date' => effective_date, 'oid_dictionary' => oid_dictionary})
          report.calculate(false) unless report.calculated? || only_initialize
        end
      end
    end

    def self.library_functions
      library_functions = {}
      library_functions['map_reduce_utils'] = File.read(File.join('.','lib','assets','javascripts','libraries','map_reduce_utils.js'))
      library_functions['hqmf_utils'] = HQMF2JS::Generator::JS.library_functions
      library_functions
    end    

    def self.refresh_js_libraries
      MONGO_DB['system.js'].find({}).remove_all
      library_functions.each do |name, contents|
        QME::Bundle.save_system_js_fn(MONGO_DB, name, contents)
      end
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
        continuous_variable: measure.continuous_variable,
        episode_of_care: measure.episode_of_care
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

      if measure.continuous_variable
        observation = measure.population_criteria[measure.populations[population_index][HQMF::PopulationCriteria::OBSERV]]
        json[:aggregator] = observation['aggregator']
      end


      
      referenced_data_criteria = measure.as_hqmf_model.referenced_data_criteria
      json[:data_criteria] = referenced_data_criteria.map{|data_criteria| data_criteria.to_json}
      json[:oids] = measure.value_sets.map{|value_set| value_set.oid}.uniq
      
      population_ids = {}
      HQMF::PopulationCriteria::ALL_POPULATION_CODES.each do |type|
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
    
    def self.quoted_string_array_or_null(arr)
      if arr
        quoted = arr.map {|e| "\"#{e}\""}
        "[#{quoted.join(',')}]"
      else
        "null"
      end
    end
    
    def self.execution_logic(measure, population_index=0, load_codes=false)
      gen = HQMF2JS::Generator::JS.new(measure.as_hqmf_model)
      codes = measure_codes(measure) if load_codes
      
      "
      var patient_api = new hQuery.Patient(patient);

      #{Measures::Calculator.check_disable_logger}

      // clear out logger
      if (typeof Logger != 'undefined') { Logger.logger = []; Logger.rationale={};}
      // turn on logging if it is enabled
      if (Logger.enabled) enableLogging();
      
      #{gen.to_js(population_index, codes)}
      
      var occurrenceId = #{quoted_string_array_or_null(measure.episode_ids)};

      hqmfjs.initializeSpecifics(patient_api, hqmfjs)
      
      var population = function() {
        return executeIfAvailable(hqmfjs.#{HQMF::PopulationCriteria::IPP}, patient_api);
      }
      var denominator = function() {
        return executeIfAvailable(hqmfjs.#{HQMF::PopulationCriteria::DENOM}, patient_api);
      }
      var numerator = function() {
        return executeIfAvailable(hqmfjs.#{HQMF::PopulationCriteria::NUMER}, patient_api);
      }
      var exclusion = function() {
        return executeIfAvailable(hqmfjs.#{HQMF::PopulationCriteria::DENEX}, patient_api);
      }
      var denexcep = function() {
        return executeIfAvailable(hqmfjs.#{HQMF::PopulationCriteria::DENEXCEP}, patient_api);
      }
      var msrpopl = function() {
        return executeIfAvailable(hqmfjs.#{HQMF::PopulationCriteria::MSRPOPL}, patient_api);
      }
      var observ = function(specific_context) {
        #{Measures::Calculator.observation_function(measure, population_index)}
      }
      
      var executeIfAvailable = function(optionalFunction, arg) {
        if (typeof(optionalFunction)==='function')
          return optionalFunction(arg);
        else
          return false;
      }

      if (Logger.enabled) enableMeasureLogging(hqmfjs);

      map(patient, population, denominator, numerator, exclusion, denexcep, msrpopl, observ, occurrenceId,#{measure.continuous_variable});
      "
    end

    def self.observation_function(measure, population_index)

      result = "
        var observFunc = hqmfjs.#{HQMF::PopulationCriteria::OBSERV}
        if (typeof(observFunc)==='function')
          return observFunc(patient_api, specific_context);
        else
          return [];"

      if (measure.custom_functions && measure.custom_functions[HQMF::PopulationCriteria::OBSERV])
        result = "return #{measure.custom_functions[HQMF::PopulationCriteria::OBSERV]}(patient_api, hqmfjs)"
      end

      result

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