class MatrixController < ApplicationController
  before_filter :authenticate_user!
  before_filter :validate_authorization!

  def index
    add_breadcrumb 'Matrix', '/matrix'
  end

  def generate_matrix
    (params[:id] ? [current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first] : Measure.all.to_a).each{|m|
      MONGO_DB['query_cache'].find({'measure_id' => m['hqmf_id']}).remove_all
      MONGO_DB['patient_cache'].find({'value.measure_id' => m['hqmf_id']}).remove_all
      (m['populations'].length > 1 ? ('a'..'zz').to_a.first(m['populations'].length) : [nil]).each{|sub_id|
        p 'Calculating measure ' + m.measure_id + (sub_id || '') + " (#{m['hqmf_id']})"
        oid_dictionary = HQMF2JS::Generator::CodesToJson.hash_to_js(Measures::Calculator.measure_codes(m))
        options = {'effective_date' => (params['effective_date'] || Measure::DEFAULT_EFFECTIVE_DATE).to_i, 'oid_dictionary' => oid_dictionary }
        qr = QME::QualityReport.new(m['hqmf_id'], sub_id, options)
        qr.calculate(false) unless qr.calculated?
      }
    }
    redirect_to :action => 'index'
  end

  def matrix_data
    select = {}
    ['IPP', 'DENOM', 'NUMER', 'DENEXCEP', 'DENEX', 'MSRPOPL', 'values', 'first', 'last', 'gender', 'measure_id', 'birthdate', 'patient_id', 'sub_id', 'nqf_id'].each {|k| select['value.'+k]=1 }
    render :json => MONGO_DB['patient_cache'].find({}).select(select)
  end

  def validate_authorization!
    authorize! :manage, Measure
  end
  
end