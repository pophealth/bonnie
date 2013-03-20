class DebugController < ApplicationController

  before_filter :authenticate_user!
  before_filter :validate_authorization!

  def show
    @population = (params[:population] || 0).to_i
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @patients = Record.all.sort {|l,r| "#{l.last}, #{l.first}" <=> "#{r.last}, #{r.first}"}
    @calculate = params[:calculate] == 'true'

    add_breadcrumb @measure['measure_id'], '/measures/' + @measure['measure_id']
    add_breadcrumb 'Test', ''
  end

  def inspect
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @patient = Record.find(params[:patient_id])
    @population = (params[:population] || 0).to_i

    add_breadcrumb @measure['measure_id'], measure_path(@measure['measure_id'])
    add_breadcrumb 'Test', debug_path(@measure['measure_id'])
    add_breadcrumb 'Inspect Patient', ''

  end
  
  def libraries
    respond_to do |wants|
      wants.js do
        @libraries = Measures::Calculator.library_functions
        render :content_type => "application/javascript"
      end
    end
  end

  def rationale
    @measure = current_user.measures.where('_id' => params[:id]).exists? ? current_user.measures.find(params[:id]) : current_user.measures.where('measure_id' => params[:id]).first
    @patient = Record.find(params[:patient_id])
    @population = (params[:population] || 0).to_i
    template = Measures::HTML::Writer.generate_nqf_template(@measure, @measure.populations[@population])
    @contents = Measures::HTML::Writer.finalize_template_body(template,"getRationale()",@patient)

    add_breadcrumb @measure['measure_id'], measure_path(@measure['measure_id'])
    add_breadcrumb 'Test', debug_path(@measure['measure_id'])
    add_breadcrumb 'Rationale', ''

  end

  def validate_authorization!
    authorize! :manage, Measure
  end
  

  
end