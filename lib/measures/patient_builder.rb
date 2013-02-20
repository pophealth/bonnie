module Measures
  # Utility class for building test patients
  class PatientBuilder
    JAN_ONE_THREE_THOUSAND=32503698000000
    def self.rebuild_patient(patient)

      # clear out patient data
      ['allergies', 'care_goals', 'conditions', 'encounters', 'immunizations', 'medical_equipment', 'medications', 'procedures', 'results', 'social_history', 'vital_signs'].each do |section|
        patient[section] = [] if patient[section]
      end
      patient.medical_record_number ||= Digest::MD5.hexdigest("#{patient.first} #{patient.last}")
      patient.save!
      patient.reload

      values = Hash[
        *Measure.where({'measure_id' => {'$in' => patient['measure_ids'] || []}}).map{|m|
          m.value_sets.map do |value_set|
            preferred_set = WhiteList.where(:oid => value_set.oid).first
            
            if preferred_set.nil?
              concept = Concept.any_in(oids: value_set.oid).first
              preferred_set = concept.clone_and_filter(value_set) if concept.present?
            end
            preferred_set ||= value_set

            [value_set.oid, preferred_set]
          end
        }.map(&:to_a).flatten
      ]

      @data_criteria = Hash[
        *Measure.where({'measure_id' => {'$in' => patient['measure_ids'] || []}}).map{|m|
          m.source_data_criteria.reject{|k,v|
            ['patient_characteristic_birthdate','patient_characteristic_gender', 'patient_characteristic_expired'].include?(v['definition'])
          }
        }.map(&:to_a).flatten
      ]
      
      patient.source_data_criteria.each {|v|
        next if v['id'] == 'MeasurePeriod'
        data_criteria = HQMF::DataCriteria.from_json(v['id'], @data_criteria[v['id']])
        data_criteria.values = []
        result_vals = v['value'] || []
        result_vals = [result_vals] if !result_vals.nil? and !result_vals.is_a? Array 
        result_vals.each do |value|
          data_criteria.values << (value['type'] == 'CD' ? HQMF::Coded.new('CD', nil, nil, value['code_list_id']) : HQMF::Range.from_json('low' => {'value' => value['value'], 'unit' => value['unit']}))
        end if v['value']
        v['field_values'].each do |key, value|
          data_criteria.field_values ||= {}
          value['value'] = Time.strptime(value['value'],"%m/%d/%Y %H:%M").to_time.strftime('%Y%m%d%H%M%S') if (value['type'] == 'TS') 
          data_criteria.field_values[key] = HQMF::DataCriteria.convert_value(value)
        end if v['field_values']
        if v['negation'] == 'true'
          data_criteria.negation = true
          data_criteria.negation_code_list_id = v['negation_code_list_id']
        end
        low = {'value' => Time.at(v['start_date'] / 1000).strftime('%Y%m%d%H%M%S'), 'type'=>'TS' }
        high = {'value' => Time.at(v['end_date'] / 1000).strftime('%Y%m%d%H%M%S'), 'type'=>'TS' }
        high = nil if v['end_date'] == JAN_ONE_THREE_THOUSAND

        data_criteria.modify_patient(patient, HQMF::Range.from_json({'low' => low,'high' => high}), values.values)
      }
      patient.save!

    end

  end


end