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

class @ValueSetFunctions
  test: ->
    console.log("in test()")
  
  bind_add_code: ->
    $('#codes .btn').on "click", ->
      codeField = $('#codes .input-small:last').clone()
      codeField = codeField[0]  # flatten
      new_id = (Number) (codeField.id.match(/(\d+)/))[0]
      new_id++
      new_name = (Number) (codeField.name.match(/(\d+)/))[0]
      new_name++
      codeField.id = codeField.id.replace /(\d+)/, new_id
      codeField.name = codeField.name.replace /(\d+)/, new_name
      $('#codes .controls').append(codeField)
      $('#codes .controls').append("<br>")
