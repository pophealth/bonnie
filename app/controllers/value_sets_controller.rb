# require 'json'  TODO: does rails3 need this anymore?

class ValueSetsController < ApplicationController
  respond_to :html, :json
  skip_authorization_check
  
  add_breadcrumb 'value_sets', ""
  
  def index
    @value_sets = ValueSet.limit(5)
  end
  
  def show
    @value_set = ValueSet.find(params[:id])
    @value_set_json = JSON.pretty_generate(JSON.parse(@value_set.to_json))
  end
  
  def edit
    @value_set = ValueSet.find(params[:id])
  end
  
  def new
    @value_set = ValueSet.new
  end
  
  def create
    respond_with do |format|
      format.json {
        # very important to render json here and not text
        # even when debugging because ajaxForm plugin will break
        # binding.pry
        json_form = JSON.parse(params[:data])
        puts json_form.inspect
        render :json => { :message => "success" }
      }
      format.html {
        form_params = params
        form_params
        render :template => 'value_sets/new'
      }
    end

    # make a copy to manipulate
    # p = params
    # turn codes into an array
    # p[:code_sets][:codes]= p[:code_sets][:codes].collect(&:second)
    
    # v = ValueSet.new p[:value_set]
  end
  
end
