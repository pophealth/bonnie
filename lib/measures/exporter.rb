module Measures
  class Exporter

    # Export all measures, their test decks, necessary JS libraries, source HQMF files, and expected results to a zip file.
    # Bundled content is first collected and then zipped all together. Content is a hash with top level keys defining directories (e.g. "library_functions") pointing to hashes with filename keys (e.g. "hqmf_utils.js") pointing to their content.
    #
    # @param [Array] measures All measures that we're exporting. Defaults to all measures.
    # @param [Boolean] preparation_needed Whether or not we need to prepare the export first. Defaults to true.
    # @param [Boolean] verbose Give verbose feedback while exporting. Defaults to true.
    # @return A bundle containing all measures, matching test patients, and some additional goodies.
    def self.export_bundle(measures = Measure.all.to_a, calculate = true)
      content = {}
      patient_ids = []
      measure_ids = []

      bundle_path = "."
      library_path = "library_functions"
      measures_path = "measures"
      sources_path = "sources"
      patients_path = "patients"
      result_path = "results"
      codes_path = "value_sets"

      content[library_path] = bundle_library_functions(Measures::Calculator.library_functions)

      # TODO should be contextual to measures
      Measures::Calculator.calculate(!calculate)
      
      Measure::TYPES.each do |type|
        measure_path = File.join(measures_path, type)
        content[measure_path] = {}
        MONGO_DB["measures"].find({type: type}).each do |measure|
          puts "Exporting measure: #{measure['nqf_id']}"
          measure_ids << measure['id']
          content[measure_path].merge! bundle_measure(measure)
        end

        source_path = File.join(sources_path, type)
        content[source_path] = {}
        Measure.where(:type => type).each do |measure|
          content[source_path].merge! bundle_sources(measure)
        end

        patient_path = File.join(patients_path, type)
        content[patient_path] = {}
        patient_exporter = HealthDataStandards::Export::HTML.new

        Record.where(type: type).each do |patient|
          puts "Exporting patient: #{patient.first}#{patient.last}"
          patient_ids << patient.medical_record_number
          content[patient_path].merge! bundle_patient(patient, patient_exporter)
        end
      end
      
      content[bundle_path] = bundle_json(patient_ids, measure_ids, Measures::Calculator.library_functions.keys)
      content[result_path] = bundle_results(measures)
      content[codes_path] = bundle_codes(measures)

      zip_content(content)
    end

    def self.bundle_json(patient_ids, measure_ids, library_names)
      json = {
        title: APP_CONFIG["measures"]["title"],
        measure_period_start: APP_CONFIG["measures"]["measure_period_start"],
        effective_date: APP_CONFIG["measures"]["effective_date"],
        version: APP_CONFIG["measures"]["version"],
        license: APP_CONFIG["measures"]["license"],
        measures: measure_ids,
        patients: patient_ids,
        exported: Time.now.strftime("%Y-%m-%d"),
        extensions: Measures::Calculator.library_functions.keys
      }

      {"bundle.json" => JSON.pretty_generate(json)}
    end

    def self.bundle_library_functions(library_functions)
      content = {}
      library_functions.each do |name, contents|
        content["#{name}.js"] = contents
      end

      content
    end

    def self.bundle_codes(measures)
      codes = {}
      value_sets = measures.map(&:value_set_oids).flatten.uniq
      value_sets.each do |oid|
        code_set_file = File.expand_path(File.join('db','code_sets',"#{oid}.xml"))
        if File.exist? code_set_file
          codes[File.join("xml", "#{oid}.xml")] = File.read(code_set_file)
        else
          puts("\tError generating code set for #{oid}")
        end
      end
      HealthDataStandards::SVS::ValueSet.where({oid: {'$in'=>value_sets}}).to_a.each do |vs|
        codes[File.join("json", "#{vs.oid}.json")] = JSON.pretty_generate(vs.as_json(:except => [ '_id' ]), max_nesting: 250)
      end
      codes
    end
    
    def self.bundle_measure(measure)
      measure_json = JSON.pretty_generate(measure.as_json(:except => [ '_id' ]), max_nesting: 250)

      {
        "#{measure['nqf_id']}#{measure['sub_id']}.json" => measure_json
      }
    end

    def self.bundle_sources(measure)
      source_path = Measures::Loader::SOURCE_PATH
      html = File.read(File.expand_path(File.join(source_path, "html", "#{measure.hqmf_id}.html")))
      hqmf1 = File.read(File.expand_path(File.join(source_path, "hqmf", "#{measure.hqmf_id}.xml")))
      hqmf2 = HQMF2::Generator::ModelProcessor.to_hqmf(measure.as_hqmf_model) rescue puts("\tError generating HQMFv2 for #{measure.measure_id}")
      hqmf_model = JSON.pretty_generate(measure.as_hqmf_model.to_json, max_nesting: 250)

      sources = {}

      sources[File.join(measure.measure_id, "#{measure.measure_id}.html")] = html
      sources[File.join(measure.measure_id, "hqmf1.xml")] = hqmf1
      sources[File.join(measure.measure_id, "hqmf2.xml")] = hqmf2 if hqmf2
      sources[File.join(measure.measure_id, "hqmf_model.json")] = hqmf_model

      sources
      
    end
      
    # TODO make this contextual to measures
    def self.bundle_results(measures)
      results_by_patient = MONGO_DB['patient_cache'].find({}).to_a
      results_by_patient = JSON.pretty_generate(JSON.parse(results_by_patient.as_json(:except => [ '_id' ]).to_json))
      results_by_measure = MONGO_DB['query_cache'].find({}).to_a
      results_by_measure = JSON.pretty_generate(JSON.parse(results_by_measure.as_json(:except => [ '_id' ]).to_json))
      
      {
        "by_patient.json" => results_by_patient,
        "by_measure.json" => results_by_measure
      }
    end

    def self.bundle_patient(patient, exporter=HealthDataStandards::Export::HTML.new)
      filename = TPG::Exporter.patient_filename(patient)

      # c32 = HealthDataStandards::Export::C32.new.export(patient)
      # ccda = HealthDataStandards::Export::CCDA.new.export(patient)
      # ccr = HealthDataStandards::Export::CCR.export(patient)
      
      patient_hash = patient.as_json(except: [ '_id', 'measure_id' ], methods: ['_type'])
      patient_hash['measure_ids'] = patient_hash['measure_ids'].uniq.reject {|id| /.*-.*/.match(id).nil? } if patient_hash['measure_ids']
      remove_nils = Proc.new { |k, v| v.kind_of?(Hash) ? (v.delete_if(&remove_nils); nil) : v.nil? }; 
      patient_hash.delete_if(&remove_nils)
      json = JSON.pretty_generate(JSON.parse(patient_hash.to_json))
      
      html = exporter.export(patient)

      {
        File.join("json", "#{filename}.json") => json,
        File.join("html", "#{filename}.html") => html
      }
    end

    private

    # Create a zip file from all of the bundle content. 
    #
    # @param [Hash] content All content to add to the bundle. Organized with top level directories (e.g. "library_functions") pointing to hashes of files (e.g. "0002/hqmf1.xml") to their content.
    # @return A zip file containing all of the bundle content.
    def self.zip_content(content)
      file = Tempfile.new("bundle-#{Time.now.to_i}")

      Zip::ZipOutputStream.open(file.path) do |zip|
        content.each do |directory_path, files|
          files.each do |file_path, file|
            zip.put_next_entry(File.join(directory_path, file_path))
            zip << file
          end
        end
      end

      file.close
      file
    end
  end
end