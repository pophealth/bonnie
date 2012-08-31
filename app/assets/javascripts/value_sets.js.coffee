# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
	codeField = $(".codeField:last").clone()
	$("#addCode").on "click", ->
		d= new Date()
		n= d.valueOf()
		codeField.attr("id", "value_set_#{n}")
		codeField.attr("value", "")
		$("#codes").append(codeField.clone())
		return false


validate_oid = new RegExp("\d+\.\d+")


# namespace the javascript functions inside a class
class ValueSetFunctions
  
  constructor: ->
    # set up backbone-forms with some critical defaults and settings
    # this class should be instantiated only on pages that plan on using it
    # so we won't get too much overhead or unnecessary client-side js stuff
    
    # Use BootstrapModal for object List editor
    Backbone.Form.editors.List.Modal.ModalAdapter = Backbone.BootstrapModal;

    # Main model definition
    # declared as a constant to namespace it
    # TODO: can we just do the Rails inclusion thing where each view includes
    # it's own coffescript?  Instead of worrying about everyone loading everything?
    @VALUE_SET_MODEL = Backbone.DeepModel.extend({
        schema: {
            oid: { validators: [validate_oid] },
            description: 'Text',
            category: { type: 'Select', options: ['encounter', 'procedure', 'communication'] },
            concept: 'Text',
            organization: 'Text',
            version: 'Text',
            key: 'Text',
            code_sets:    { type: 'List', itemType: 'Object', subSchema: {
                code_set: { validators: ['required'] },
                category:      { type: 'Select', options: ['encounter', 'procedure', 'communication'] },
                concept: 'Text',
                description: 'Text',
                codes:      { type: 'List' },
                key: 'Text',
                oid: 'Text',
                organization: 'Text',
                version: 'Text'
            }}
        }
    })
    
  
  # create a form using the backbone-form plugin for the new action
  new_form: ->
    # example pre-populated object that would fill in the form
    # value_set = new @VALUE_SET_MODEL({
    #         oid: '1.2.3',
    #         description: 'description',
    #         category: 'procedure',
    #         concept: 'concept',
    #         organization: 'organization',
    #         version: 'version',
    #         key: 'key',
    #         code_sets: [
    #             { code_set: 'ICD-9-CM', category: 'category', codes: [1,2] }
    #         ]
    # })
    value_set = new @VALUE_SET_MODEL()
    
    form = new Backbone.Form({ model: value_set }).render()
    $('#backbone-form').prepend(form.el)
    $('#new-value-set').on "click", (e) ->
      data = form.getValue()
      url = '/value_sets.json'
      # todo: remove this response = below
      response = $.post url, 
        data: data
        (response) ->
          if response.message == 'success'
            window.location = response.redirect
  
  
  edit_form: ->
    # get the id from a hidden field
    id = $('#value_set_id').attr('_id')
    
    # json fetch
    value_set_js_object = this.get_value_set(id)
    
    # instantiate a backbone model from the plain old js object
    value_set = new @VALUE_SET_MODEL(value_set_js_object)
    
    form = new Backbone.Form({model: value_set}).render()
    $('#backbone-form').prepend(form.el)
    
    # wire up the update button to do an ajax update
    $('#update-value-set').on "click", (e) ->
      $.ajax
        async: false  
        type: "PUT"
        url: "/value_sets/#{id}.json"
        data: form.getValue()
        dataType: "json"
        success: (data) =>
          @value_set = data
          # TODO: flash notice here
          # $("#flash_notice").html(<%=escape_javascript(flash.delete(:notice)) %>');


  # gets a value_set object from rails into coffeescript as json
  get_value_set: (id) ->
    @value_set = ""
    $.ajax
      async: false  
      type: "GET"
      url:  "/value_sets/#{id}"
      dataType: "json"
      success: (data) =>
        @value_set = data
    return @value_set
