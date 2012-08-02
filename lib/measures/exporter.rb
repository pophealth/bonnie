module Measures

  # Exports measure defintions in a pophealth compatible format
  class Exporter
    def self.export(file, measures)

      Zip::ZipOutputStream.open(file.path) do |zip|
        measure_path = "measures"
        json_path = File.join(measure_path, "json")
        library_path = File.join(measure_path, "libraries")

        library_functions = Measures::Exporter.library_functions

        library_functions.each do |name, contents|
          zip.put_next_entry(File.join(library_path, "#{name}.js"))
          zip << contents
        end

        bundle_json = Measures::Exporter.bundle_json(library_functions.keys).to_json
        zip.put_next_entry(File.join(measure_path, "bundle.json"))
        zip << bundle_json

        measures.each do |measure|
          (0..measure.populations.count-1).each do |population_index|
            measure_json = Measures::Exporter.measure_json(measure.measure_id, population_index)
            zip.put_next_entry(File.join(json_path, "#{measure.measure_id}#{measure_json[:sub_id]}.json"))
            zip << measure_json.to_json
          end
        end
      end
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

    def self.bundle_json(library_names)
      {
        name: "Meaningful Use Stage 2 Clinical Quality Measures",
        license: "<p>Performance measures and related data specifications (the \"Measures\") are copyrighted by\nthe noted quality measure providers as indicated in the applicable Measure.  Coding\nvocabularies are owned by their copyright owners.  By using the Measures, a user\n(\"User\") agrees to these Terms of Use.  Measures are not clinical guidelines and do not\nestablish a standard of medical care and quality measure providers are not responsible\nfor any use of or reliance on the Measures.</p>\n\n<p><strong>THE MEASURES AND SPECIFICATIONS ARE PROVIDED \"AS IS\" WITHOUT ANY WARRANTY OF\nANY KIND, AND ANY AND ALL IMPLIED WARRANTIES ARE HEREBY DISCLAIMED, INCLUDING ANY\nWARRANTY OF NON-INFRINGEMENT, ACCURACY, MERCHANTABILITY AND FITNESS FOR A PARTICULAR\nPURPOSE.  NO QUALITY MEASURE PROVIDER, NOR ANY OF THEIR TRUSTEES, DIRECTORS, MEMBERS,\nAFFILIATES, OFFICERS, EMPLOYEES, SUCCESSORS AND/OR ASSIGNS WILL BE LIABLE TO YOU FOR\nANY DIRECT, INDIRECT, SPECIAL, EXEMPLARY, INCIDENTAL, PUNITIVE, AND/OR CONSEQUENTIAL\nDAMAGE OF ANY KIND, IN CONTRACT, TORT OR OTHERWISE, IN CONNECTION WITH THE USE OF THE\nPOPHEALTH TOOL OR THE MEASURES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH LOSS OR DAMAGE.\n</strong></p>\n\n<p>The Measures are licensed to a User for the limited purpose of using, reproducing and\ndistributing the Measures with the popHealth Tool as delivered to User, without any\nmodification, for commercial and noncommercial uses, but such uses are only permitted\nif the copies of the Measures contain this complete Copyright, Disclaimer and Terms\nof Use.  Users of the Measures may not alter, enhance, or otherwise modify the Measures.</p>\n\n<p><strong>NOT A CONTRIBUTION</strong> - The Measures, including specifications and coding,\nas used in the popHealth Tool, are not a contribution under the Apache license. Coding\nin the Measures is provided for convenience only and necessary licenses for use should\nbe obtained from the copyright owners. Current Procedural Terminology \n(CPT<span class=\"reg\">&reg;</span>) &copy; 2004-2010 American Medical Association. \nLOINC<span class=\"reg\">&reg;</span> &copy; 2004 Regenstrief Institute,\nInc. SNOMED Clinical Terms<span class=\"reg\">&reg;</span> \n(SNOMED CT<span class=\"reg\">&reg;</span>) &copy; 2004-2010 International Health\nTerminology Standards Development Organization.</p>",
        extensions: library_names,
        measures: []
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
