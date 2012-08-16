# require 'json'  TODO: does rails3 need this anymore?

class ValueSetsController < ApplicationController
  respond_to :html, :json, :js
  skip_authorization_check
  
  add_breadcrumb 'value_sets', ""
  
  def index
    @value_sets = ValueSet.all
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
    respond_with do |format|
      format.html {
        if params[:code_sets]
          @num_code_sets = params[:code_sets].to_i
        else
          @num_code_sets = 0
        end
      }
    end
  end
  
  def create
    respond_with do |format|
      format.json {
        # very important to render json here and not text
        # even when debugging because ajaxForm plugin will break
        json_form = JSON.parse(params[:data])
        puts json_form.inspect
        render :json => { :message => "success" }
      }
      format.html {
        serialized = FormSerializer.new.serialize_params(params["value_set"])
        new_value_set = ValueSet.new serialized
        new_value_set.save
        # TODO: verify new_value_set has correct number of codesets
        flash[:notice] = "Created value set."
        redirect_to :action => 'show', :id => new_value_set.id
      }
    end
  end
  
end
