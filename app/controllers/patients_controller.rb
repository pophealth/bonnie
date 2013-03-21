class PatientsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :validate_authorization!

  JAN_ONE_THREE_THOUSAND=32503698000000
  RACE_NAME_MAP={'1002-5' => 'American Indian or Alaska Native','2028-9' => 'Asian','2054-5' => 'Black or African American','2076-8' => 'Native Hawaiian or Other Pacific Islander','2106-3' => 'White','2131-1' => 'Other'}
  ETHNICITY_NAME_MAP={'2186-5'=>'Not Hispanic or Latino', '2135-2'=>'Hispanic Or Latino'}

  def show
    @patient = Record.find(params[:id])
    respond_to do |format|
      format.html {
        @measure = current_user.measures.where('_id' => params[:measure_id]).exists? ? current_user.measures.find(params[:measure_id]) : current_user.measures.where('measure_id' => params[:measure_id]).first
        add_breadcrumb @measure['measure_id'], '/measures/' + @measure['measure_id']
        add_breadcrumb 'Test', debug_path(@measure)
        add_breadcrumb "#{@patient.last}, #{@patient.first}", ''
      }
      format.js { }
    end
  end

  def edit
    
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @record = Record.where({'_id' => params[:patient_id]}).first || {}

    measure_list = (@record['measure_ids'] || []) << @measure['measure_id']
    @data_criteria = Measures::PatientBuilder.get_data_criteria(measure_list)
    @dropped_data_criteria = Measures::PatientBuilder.check_data_criteria!(@record, @data_criteria)
    @value_sets = Measure.where({'measure_id' => {'$in' => measure_list}}).map{|m| m.value_sets}.flatten(1).uniq

    add_breadcrumb @measure['measure_id'], '/measures/' + @measure['measure_id']
    add_breadcrumb 'Test', debug_path(@measure)
    add_breadcrumb 'Patient Builder', ''
  end

  def save
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first

    patient = Record.where({'_id' => params['record_id']}).first || HQMF::Generator.create_base_patient(params.select{|k| ['first', 'last', 'gender', 'expired', 'birthdate'].include? k })

    if (params['clone'])
      patient = Record.new(patient.attributes.except('_id'));
      patient.save!
    end

    patient['measure_ids'] ||= []
    patient['measure_ids'] = Array.new(patient['measure_ids']).push(@measure['measure_id']) unless patient['measure_ids'].include? @measure['measure_id']

    params['birthdate'] = Time.parse(params['birthdate']).to_i

    ['first', 'last', 'gender', 'expired', 'birthdate', 'description', 'description_category'].each {|param| patient[param] = params[param]}
    patient['ethnicity'] = {'code' => params['ethnicity'], 'name'=>ETHNICITY_NAME_MAP[params['ethnicity']], 'codeSystem' => 'CDC Race'}
    patient['race'] = {'code' => params['race'], 'name'=>RACE_NAME_MAP[params['race']], 'codeSystem' => 'CDC Race'}

    patient['source_data_criteria'] = JSON.parse(params['data_criteria'])
    patient['measure_period_start'] = params['measure_period_start'].to_i
    patient['measure_period_end'] = params['measure_period_end'].to_i

    insurance_types = {
      'MA' => 'Medicare',
      'MC' => 'Medicaid',
      'OT' => 'Other'
    }
    insurance_provider = InsuranceProvider.new
    insurance_provider.type = params['payer']
    insurance_provider.member_id = '1234567890'
    insurance_provider.name = insurance_types[params['payer']]
    insurance_provider.financial_responsibility_type = {'code' => 'SELF', 'codeSystem' => 'HL7 Relationship Code'}
    insurance_provider.start_time = Time.new(2008,1,1).to_i
    insurance_provider.payer = Organization.new
    insurance_provider.payer.name = insurance_provider.name
    patient.insurance_providers = [insurance_provider]

    Measures::PatientBuilder.rebuild_patient(patient)

    patient['source_data_criteria'].push({'id' => 'MeasurePeriod', 'start_date' => params['measure_period_start'].to_i, 'end_date' => params['measure_period_end'].to_i})

    if @measure.records.include? patient
      render :json => patient.save!
    else
      @measure.records.push(patient)
      render :json => @measure.save!
    end
  end

  def download
    measure = current_user.measures.find(params[:measure_id])
    records = Record.all

    format = params[:download][:format]
    zip = nil
    if format == 'qrda'
      zip = TPG::Exporter.zip_qrda_cat_1_patients({measure.measure_id => records.to_a}, [measure.as_hqmf_model])
    else
      zip = TPG::Exporter.zip(records, format)
    end

    send_file zip.path, :type => 'application/zip', :disposition => 'attachment', :filename => "patients.zip"
  end

  def destroy
    measure = current_user.measures.find(params[:measure_id])
    Record.find(params[:id]).delete
    redirect_to debug_url(measure)
  end

  def validate_authorization!
    authorize! :manage, Measure
  end

  
end