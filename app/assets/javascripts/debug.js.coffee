# log to a div
append_div = (div, message) ->
  div.append(message)
  div.append('\n')

initialize_measure = ->
  code_element = $('.CodeRay')
  log_element = $('#log')
  execute_measure(patient[0])

  for e in emitted[0].logger
    do (e) ->
      append_div(log_element, e)

init_js_load = ->
  # reusable selectors
  code_element = $('.CodeRay')
  log_element = $('#log')

  code_element.hide()

  $("#run_numerator_link").click (event) ->
    Logger.logger = [] if Logger?
    log_element.empty()
    patient_api = new hQuery.Patient(patient[0]);
    executeIfAvailable(hqmfjs.NUMER, patient_api)
    for e in Logger.logger
      do (e) ->
        append_div(log_element, e)

  $('#run_denominator_link').click (event) ->
    Logger.logger = [] if Logger?
    log_element.empty()
    patient_api = new hQuery.Patient(patient[0]);
    executeIfAvailable(hqmfjs.DENOM, patient_api)
    for e in Logger.logger
      do (e) ->
        append_div(log_element, e)

  $("#run_ipp_link").click (event) ->
    Logger.logger = [] if Logger?
    log_element.empty()
    patient_api = new hQuery.Patient(patient[0]);
    executeIfAvailable(hqmfjs.IPP, patient_api)
    for e in Logger.logger
      do (e) ->
        append_div(log_element, e)

  $("#run_exclusions_link").click (event) ->
    Logger.logger = [] if Logger?
    log_element.empty()
    patient_api = new hQuery.Patient(patient[0]);
    executeIfAvailable(hqmfjs.DENEX, patient_api)
    for e in Logger.logger
      do (e) ->
        append_div(log_element, e)

  $("#run_exceptions_link").click (event) ->
    Logger.logger = [] if Logger?
    log_element.empty()
    patient_api = new hQuery.Patient(patient[0]);
    executeIfAvailable(hqmfjs.DENEXCEP, patient_api)
    for e in Logger.logger
      do (e) ->
        append_div(log_element, e)

  $('#toggle_code_link').click (event) ->
    if (code_element.is(":visible") == true)
      code_element.hide()
      log_element.show()
    else
      code_element.show()
      log_element.hide()

executeIfAvailable = (optionalFunction, arg) ->
  if (typeof(optionalFunction)=='function')
    optionalFunction(arg)
  else
    false

populate_test_table = () ->
  # column totals
  population_total = 0
  denominator_total = 0
  numerator_total = 0
  exclusions_total = 0
  exceptions_total = 0

  for p in patient
    do (p) ->
      execute_measure(p)

  for e in emitted
    do (e) ->
      # select the row with the patient id
      row = $('#patients_' + e.patient_id).parent().parent()

      # TODO: this is not DRY
      # colorize and checkmark table cells based on results
      if e.IPP
        population_total += 1  
        cell = $(row).children(":nth-child(2)")
        cell.css('background-color', '#EEE')      #light gray
        cell.html('&#x2713;')

      if e.DENOM
        denominator_total += 1  
        cell = $(row).children(":nth-child(3)")
        cell.css('background-color', '#99CCFF')   #light blue
        cell.html('&#x2713;')

      if e.NUMER || e.MSRPOPL
        numerator_total += 1  
        cell = $(row).children(":nth-child(4)")
        cell.css('background-color', '#CCFFCC')   #light green
        values = ''
        values = ' [' + e.values.join(',') + ']' if (e.values and e.values.length > 0)
        cell.html('&#x2713;' + values)

      if e.DENEX
        exclusions_total += 1  
        cell = $(row).children(":nth-child(5)")
        cell.css('background-color', '#FFCC99')   #light orange
        cell.html('&#x2713;')

      if e.DENEXCEP
        exceptions_total++
        cell = $(row).children(":nth-child(6)")
        cell.css('background-color', '#EEE')
        cell.html('&#x2713')

  # set total columns
  total_row = $('#patients').find('.total').find('.span2')
  total_row.eq(1).html(population_total)
  total_row.eq(2).html(denominator_total)
  total_row.eq(3).html(numerator_total)
  total_row.eq(4).html(exclusions_total)
  total_row.eq(5).html(exceptions_total)

# add row highlighting when rolling over inspect link
bind_inspect_highlight = () ->
  # select all rows with the inspect link only
  # $('#patients .inspect:contains("inspect")').hover(
  #   -> $(this).parent().css('background-color', '#f5f5f5'),
  #   -> $(this).parent().css('background-color', 'white')
  # )
  false

# keep track of population criteria id and update test button href
# so that the debugger can handle multiple population criterias
change_test_button_params = (e) ->
  # save test button element for later, we will change a url parameter in the button href
  test_button = $('#pageButtons .btn').eq(1)

  # split on ? in case we already have updated the href
  base_url = test_button.attr('href').split("?")[0]

  # regex to find the population criteria number selected in the dropdown
  definition_number_matches = e.match /.*\/(\d+)\/definition/
  if definition_number_matches
    population_criteria_number = definition_number_matches[1]
  else
    population_criteria_number = 0
  population_criteria_number++     # off by one fix

  # make button link pass a url param
  test_button.attr('href', base_url + "?population_criteria=" + population_criteria_number)

# select all patients
select_all_patients = (e) ->
  if (e)
    e.preventDefault()
  $('#patients .name :checkbox').each (i) ->
    $(this).attr('checked', true)

# deselect all patients
deselect_all_patients = (e) ->
  if (e)
    e.preventDefault()
  $('#patients .name :checkbox').each (i) ->
    $(this).attr('checked', false)

# select patient checkboxes that were previously selected in the form
reselect_patients = () ->
  deselect_all_patients()
  for p in patient
    do (p) ->
      $('#patients_' + p._id).attr('checked', true)
