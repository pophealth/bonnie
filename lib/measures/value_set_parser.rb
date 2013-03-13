require 'zip/zipfilesystem'
require 'spreadsheet'
require 'roo'

module HQMF
  module ValueSet
    class Parser

      attr_accessor :child_oids
  
      GROUP_CODE_SET = "GROUPING"
  
      ORGANIZATION_INDEX = 0
      OID_INDEX = 1
      CONCEPT_INDEX = 3
      CATEGORY_INDEX = 4
      CODE_SET_INDEX =5
      VERSION_INDEX = 6
      CODE_INDEX = 7
      DESCRIPTION_INDEX = 8
 
      DEFAULT_SHEET = 1


      CODE_SYSTEM_NORMALIZER = {
        'ICD-9'=>'ICD-9-CM',
        'ICD-10'=>'ICD-10-CM',
        'HL7 (2.16.840.1.113883.5.1)'=>'HL7'
      }
      IGNORED_CODE_SYSTEM_NAMES = ['Grouping', 'GROUPING' ,'HL7', "Administrative Sex"]
  
      def initialize()
        @child_oids = []
      end
  
      # import an excel matrix array into mongo
      def parse(file)
        sheet_array = file_to_array(file)
        by_oid_ungrouped = cells_to_hashs_by_oid(sheet_array)
        value_sets = collapse_groups(by_oid_ungrouped)
        translate_json(value_sets)
      end
  
      def collapse_groups(by_oid_ungrouped)
    
        final = []
    
        # select the grouped code sets and fill in the children... also remove the children that are a
        # member of a group.  We remove the children so that we can create parent groups for the orphans
        (by_oid_ungrouped.select {|key,value| value["code_set"].upcase == GROUP_CODE_SET}).each do |key, value|
          # remove the group so that it is not in the orphan list
          by_oid_ungrouped.delete(value["oid"])
          codes = []
          value["codes"].each do |child_oid|
#            codes << by_oid_ungrouped.delete(child_oid)
            # do not delete the children of a group.  These may be referenced by other groups or directly by the measure
            code = by_oid_ungrouped[child_oid]
            @child_oids << child_oid
            puts "\tcode could not be found: #{child_oid}" unless code
            codes << code if code
            # for hierarchies we need to probably have codes be a hash that we select from if we don't find the
            # element in by_oid_ungrouped we may need to look for it in final
          end
          value["code_sets"] = codes
          value.delete("codes")
          value.delete("code_set")
          final << value
        end
    
        # fill out the orphans
        by_oid_ungrouped.each do |key, orphan|
          final << adopt_orphan(orphan)
        end
        
        deleted = []
        final.delete_if {|x| to_delete = x['code_sets'].nil? || x['code_sets'].empty?; deleted << x if to_delete; to_delete }
        deleted.each do |value|
          puts "\tDeleted value set with no code sets: #{value['oid']}"
        end
        final
    
      end
  
      def adopt_orphan(orphan)
        parent = orphan.dup
        parent["code_sets"] = [orphan]
        parent.delete("codes")
        parent.delete("code_set")
        parent
      end
  
      # take an excel matrix array and turn it into an array of db models
      def cells_to_hashs_by_oid(array)

        rows_with_data = array.slice(1..-1).select {|r| !r[OID_INDEX].nil? }

        by_oid = {}
        rows_with_data.each do |row|
          entry = convert_row(row)
          
          existing = by_oid[entry["oid"]]
          if (existing)
            existing["codes"].concat(entry["codes"])
          else
            by_oid[entry["oid"]] = entry
          end
        end
    
        by_oid
      end
  
      private
  
      def convert_row(row)
        value = {
          "key" => normalize_names(row[CATEGORY_INDEX],row[CONCEPT_INDEX]),
          "organization" => row[ORGANIZATION_INDEX],
          "oid" => row[OID_INDEX].strip.gsub(/[^0-9\.]/i, ''),
          "concept" => normalize_names(row[CONCEPT_INDEX]),
          "category" => normalize_names(row[CATEGORY_INDEX]),
          "code_set" => normalize_code_system(row[CODE_SET_INDEX]),
          "version" => row[VERSION_INDEX],
          "codes" => extract_code(row[CODE_INDEX].to_s, row[CODE_SET_INDEX]),
          "description" => row[DESCRIPTION_INDEX]
        }
        value['codes'].map! {|code| code.strip.gsub(/[^0-9\.]/i, '')} if (value['code_set'].upcase == GROUP_CODE_SET)
        value
      end
  
      # Break all the supplied strings into separate words and return the resulting list as a
      # new string with each word separated with '_'
      def normalize_names(*components)
        name = []
        components.each do |component|
          component ||= ''
          name.concat component.gsub(/\W/,' ').split.collect { |word| word.strip.downcase }
        end
        name.join '_'
      end
      
      def normalize_code_system(code_system_name)
        code_system_name = CODE_SYSTEM_NORMALIZER[code_system_name] if CODE_SYSTEM_NORMALIZER[code_system_name]
        return code_system_name if IGNORED_CODE_SYSTEM_NAMES.include? code_system_name
        oid = HealthDataStandards::Util::CodeSystemHelper.oid_for_code_system(code_system_name)
        puts "\tbad code system name: #{code_system_name}" unless oid
        code_system_name
      end
  
      def extract_code(code, set)
    
        code.strip!
        if set=='CPT' && code.include?('-')
          eval(code.strip.gsub('-','..')).to_a.collect { |i| i.to_s }
        else
          [code]
        end
    
      end
  
      def file_to_array(file_path)
        book = book_by_format(file_path)
        book.default_sheet=book.sheets[DEFAULT_SHEET]
        book.to_matrix.to_a
      end

      def book_by_format(file_path)
        format = HQMF::ValueSet::Parser.get_format(file_path)
        if format == :xls
          book = Roo::Excel.new(file_path, nil, :ignore)
        elsif format == :xlsx
          book = Roo::Excelx.new(file_path, nil, :ignore)
        else
          raise "File does not end in .xls or .xlsx"
        end
        book
      end
      def self.get_format(file_path)
        if file_path =~ /xls$/
          :xls
        elsif file_path =~ /xlsx$/
          :xlsx
        end
      end


      
      def translate_json(value_sets)
        value_set_models = []

        value_sets.each do |value_set|
          hds_value_set = HealthDataStandards::SVS::ValueSet.new() 
          hds_value_set['oid'] = value_set['oid']
          hds_value_set['display_name'] = value_set['key']
          hds_value_set['version'] = value_set['version']
          hds_value_set['concepts'] = []

          value_set['code_sets'].each do |code_set|
            code_set['codes'].map{ |code| 
              concept = HealthDataStandards::SVS::Concept.new()
              concept['code'] = code
              concept['code_system'] = nil
              concept['code_system_name'] = code_set['code_set']
              concept['code_system_version'] = code_set['version']
              concept['display_name'] = nil
              hds_value_set['concepts'].concat([concept])
            }
          end
          if hds_value_set['concepts'].include? nil
            puts "Value Set has a bad code set (code set is null)"
            hds_value_set['concepts'].compact!
          end
          value_set_models << hds_value_set
        end
        value_set_models
      end
  
  
    end
  end
end
