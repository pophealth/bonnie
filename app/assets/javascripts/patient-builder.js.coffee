###
  remove birthdate, gender, expired, clinical trial
  create unique from specific/non specific occurrences
  add time, values, fields, negation
  save new patient
###

bonnie = @bonnie || {}

class @bonnie.PatientBuilder
  constructor: (data_criteria, value_sets) ->
    @data_criteria = {}
    @selected_data_criteria = {}
    @value_sets = {}
    @value_sets[s.oid] = s for s in value_sets
    @data_criteria_counter = 0
    for key in _.keys(data_criteria)
      @data_criteria[key] = new bonnie.DataCriteria(key, data_criteria[key], @measure_period)

  orderedValueSets: =>
    _.values(@value_sets).sort((left, right) =>
      left.concept > right.concept)

  nextDataCriteriaId: =>
    @data_criteria_counter+=1

  registerDataCriteria: (criteria) =>
    criteria.start_date = new Date($('#measure_period_start').val()).getTime()
    criteria.end_date = new Date($('#measure_period_start').val()).getTime()
    @selected_data_criteria[criteria.id] = criteria
    @updateTimeline()

  detachDataCriteria: (criteria) =>
    $('.paramGroup[data-criteria-id='+criteria.id+']').detach();
    delete @selected_data_criteria[criteria.id]
    $('#workspace').empty();
    @updateTimeline()

  getDateString: (date) =>
    d = new Date(date)
    val = "#{d.getFullYear()}-#{@fillZeros(d.getMonth()+1)}-#{@fillZeros(d.getDate())}T#{@fillZeros(d.getHours())}:#{@fillZeros(d.getMinutes())}:#{@fillZeros(d.getSeconds())}Z"

  fillZeros: (string) ->
    val = "0#{string}"
    val.substring(val.length-2)

  toggleDataCriteriaTree: (element) =>
    $(element.currentTarget).closest(".paramGroup").find("i").toggleClass("icon-chevron-right").toggleClass("icon-chevron-down")
    category = $(element.currentTarget).data('category');
    children = $(".#{category}_children")
    if (children.is(':visible'))
      children.hide("blind", { direction: "vertical" }, 500)
    else
      children.show("blind", { direction: "vertical" }, 500)

  timelineToDataCriteria: (data_criteria) =>
    bonnie.timeline.getBand(0).setCenterVisibleDate(new Date(data_criteria.start_date))

  highlightSelectedDataCriteria: (minDate, maxDate) =>
    container = $('#patient_data_criteria');
    children = container.children("div");
#    $('.paramGroup').removeClass('highlight')
    $('.paramItem').removeClass('highlight')
    for child in children
      dc = @selectedDataCriteria($(child).data('criteria-id'))
      dc_start = new Date(dc.start_date)
      dc_end = new Date(dc.end_date)
      if ((dc_start <= maxDate and dc_end >= minDate ))
        $(child).children('.paramItem').addClass('highlight')


  editDataCriteria: (element) =>
    leaf = $(element)

    $('.paramItem').removeClass('editing')
    leaf.children('.paramItem').addClass('editing')

    top = $('#workspace > div').css('top')
    $('#workspace').empty()
    data_criteria = @selectedDataCriteria($(element).data('criteria-id'))
    element = data_criteria.asHtml('data_criteria_edit').appendTo('#workspace')

    offset = leaf.offset().top + leaf.height()/2 - $('#workspace').offset().top - element.height()/2
    offset = 0 if offset < 0
    maxoffset = $('#measureEditContainer').height() - element.outerHeight(true) - $('#workspace').position().top - $('#workspace').outerHeight(true) + $('#workspace').height()+$('#patient_data_criteria').position().top
    offset = maxoffset if offset > maxoffset
    element.css("top", offset)
    arrowOffset = leaf.offset().top + leaf.height()/2 - element.offset().top - $('.arrow-w').outerHeight()/2
    arrowOffset = 0 if arrowOffset < 0
    $('.arrow-w').css('top', arrowOffset)
    element.css("top", top)
    element.animate({top: offset})
    $('.close_edit').click( -> $('#workspace').empty(); $('.paramItem').removeClass('editing') );

    $('#element_start').datetimepicker({
      onSelect: (selectedDate) -> $( "#element_end" ).datetimepicker('option', "minDate", new Date(selectedDate) )
    }).datetimepicker('setDate', new Date(data_criteria.start_date));

    $('#element_end').datetimepicker({
      onSelect: (selectedDate) -> $( "#element_start" ).datetimepicker( "option", "maxDate", new Date(selectedDate) )
    }).datetimepicker('setDate', new Date(data_criteria.end_date));
    
    $(".datetime").datetimepicker()
    
    $('#null_element_end').click(->
      if ($('#null_element_end').is(':checked'))
        $('#element_end').disableSelection()
        $('#element_end').datetimepicker('setDate', new Date(3000,0,1));
        $('#element_end').css('color', '#FFF')
      else
        $('#element_end').enableSelection()
        $('#element_end').datetimepicker('setDate', new Date(new Date($('#element_start').val())));
        $('#element_end').css('color', '#000')
    )

    if (new Date($('#element_end').val())).getTime() == (new Date(3000,0,1)).getTime()
      $('#element_end').disableSelection()
      $('#element_end').datetimepicker('setDate', new Date(3000,0,1));
      $('#element_end').css('color', '#FFF')
      $('#null_element_end').attr('checked', true);

    element.on('change', ('input.value_type[type=radio]')
      ( ->
        e = $(@).parentsUntil('.criteria_field_value, .criteria_value').parent().first()
        e.find('input.value_type[type=radio]').not(@).prop('checked', null)
        e.find('.criteria_value_value').children().show().not('.' +
          switch(if @ instanceof String then @toString() else $(@).val())
            when 'TS' then 'data_criteria_datetime'
            when 'PQ' then 'data_criteria_value'
            when 'CD' then 'data_criteria_oid'
        ).hide()
      )
    )
    value_field = element.find('.criteria_value')
    $.each(data_criteria.value || [], (i, e) =>
      $(value_field[i]).find('input.value_type[type=radio]').filter('[value=' + (e.type || 'PQ') + ']').trigger('click')
      $(value_field[i]).find('select.data_criteria_oid').val(e.code_list_id) if e.type == 'CD'
    )

    element.find('select[name=negation]').val('true' if data_criteria.negation)
    element.find('.negation_reason_oid').slideDown() if data_criteria.negation
    element.find('select[name=negation_code_list_id]').val(data_criteria.negation_code_list_id)

    field_element = $(element).find('.field_value')
    i = 0
    $.each(data_criteria.field_values || {}, (k, e) ->
      $(field_element[i]).find('input.value_type[type=radio]').filter('[value=' + (e.type || 'PQ') + ']').trigger('click')
      $(f = field_element[i++]).find('.field_type').val(k)
      $(f).find('.data_criteria_oid').val(e.code_list_id)
    )

    $('#element_update').click(=>
      data_criteria = @selectedDataCriteria($('#element_id').val())
      data_criteria.start_date = new Date($('#element_start').val()).getTime()
      data_criteria.end_date = new Date($('#element_end').val()).getTime()
      data_criteria.value = []

      $('.criteria_value').each((i, e) =>
        data_criteria.value.push(switch $(e).find('input.value_type[type=radio]:checked').val()
          when 'PQ'
            {
              type: 'PQ'
              value: $(e).find('#element_value').val()
              unit: $(e).find('#element_value_unit').val()
            } if $(e).find('#element_value').val()
          when 'CD'
            {
              type: 'CD'
              code_list_id: $(e).find('.data_criteria_oid').val()
              title: $(e).find('.data_criteria_oid > option:selected').text()
            } if $(e).find('.data_criteria_oid').val()
        )
      )

      data_criteria.negation = $(element).find('select[name=negation]').val()
      data_criteria.negation_code_list_id = if data_criteria.negation then $(element).find('select[name=negation_code_list_id]').val() else null

      data_criteria.field_values = {}
      $(element).find('.field_value').each((i, e) =>
        data_criteria.field_values[$(e).find('.field_type').val()] = switch $(e).find('input.value_type[type=radio]:checked').val()
          when 'PQ'
            {
              type: 'PQ'
              value: $(e).find('#element_value').val()
              unit: $(e).find('#element_value_unit').val()
            } if $(e).find('#element_value').val()
          when 'CD'
            {
              type: 'CD'
              code_list_id: $(e).find('.data_criteria_oid').val()
              title: $(e).find('.data_criteria_oid > option:selected').text()
            } if $(e).find('.data_criteria_oid').val()
          when 'TS'
            {
              type: 'TS'
              value: $(e).find('.datetime').val()
            } if $(e).find('.datetime').val()
      )

      @updateTimeline()
      @timelineToDataCriteria(data_criteria)
      $('#workspace').empty()
      $('.paramItem').removeClass('editing')
    )

  sortSelectedDataCriteria: =>
    container = $('#patient_data_criteria');
    children = container.children("div");

    children.detach().sort((left, right) =>
      left_dc = @selectedDataCriteria($(left).data('criteria-id'))
      right_dc = @selectedDataCriteria($(right).data('criteria-id'))
      @getDateString(left_dc.start_date) > @getDateString(right_dc.start_date) ? 1 : -1;
    );
    container.append(children);



  updateTimeline: =>

    @sortSelectedDataCriteria()

    timelineData = {
    'dateTimeFormat': 'iso8601',
    'events' : []
    }

    for key in _.keys(@selected_data_criteria)
      criteria = @selectedDataCriteria(key)
      start = @getDateString(criteria.start_date)
      end = @getDateString(criteria.end_date)
      event = {'start': start, 'title': "#{criteria.category} #{criteria.status}: #{criteria.title}", 'description': "#{criteria.category} #{criteria.status}: #{criteria.title}", 'id': "#{criteria.id}"}
      event['end'] = end if start != end
      timelineData.events.push(event)

    bonnie.timelineEvents.clear();
    bonnie.timelineEvents.loadJSON(timelineData, '.');
    bonnie.timeline.layout()



  dataCriteria: (id) =>
    @data_criteria[id]
  selectedDataCriteria: (id) =>
    @selected_data_criteria[id]

  save_patient_builder: (form)->
    data_criteria = []
    $('#patient_data_criteria .paramGroup').each((i,e)=>
      data = bonnie.patientBuilder.selected_data_criteria[$(e).data('criteria-id')]
      data_criteria.push({
        id: data.source
        start_date: data.start_date
        end_date: data.end_date
        value: data.value if data.value
        value_unit: data.value_unit if data.value
        negation: data.negation
        negation_code_list_id: data.negation_code_list_id
        field_values: data.field_values
        oid: data.oid
      })
    );
    $(form).ajaxSubmit({
      beforeSubmit: (v) -> v.map((e) ->
        e.value = new Date(e.value).getTime() if e.name == 'birthdate'
        e
      )
      data: {
        measure_period_start: new Date($('#measure_period_start').val()).getTime()
        measure_period_end: new Date($('#measure_period_end').val()).getTime()
        data_criteria: JSON.stringify(data_criteria)
      }
      success: (r)->
        document.location.href = if $(form).data('redirect_matrix') then $(form).find('input.redirect_matrix_url[type=hidden]').val() else $(form).find('input.redirect_url[type=hidden]').val() if r
      error: (XHR, title, r)->
        alert(title + "\n" + r)
    });

class PatientBuilderPage
  constructor: (data_criteria, value_sets, patient) ->
    bonnie.patientBuilder = new bonnie.PatientBuilder(data_criteria, value_sets)
    if patient
      $(window).load(->
        for data_criteria in patient
          if data_criteria.id == 'MeasurePeriod'
            $('#measure_period_start').datetimepicker('setDate', new Date(data_criteria.start_date));
            $('#measure_period_end').datetimepicker('setDate', new Date(data_criteria.end_date));
            onLoadTimeline();
          else
            criteria = fillDrop({target: $('#patient_data_criteria')}, {draggable: $('[data-criteria-id=' + data_criteria.id + ']')});
            criteria.start_date = data_criteria.start_date
            criteria.end_date = data_criteria.end_date
            criteria.value = data_criteria.value
            criteria.value_unit = data_criteria.value_unit
            criteria.negation = data_criteria.negation
            criteria.negation_code_list_id = data_criteria.negation_code_list_id
            criteria.field_values = data_criteria.field_values

            bonnie.patientBuilder.timelineToDataCriteria(criteria)
        bonnie.patientBuilder.updateTimeline()
        $('#workspace .close_edit').click()
      )

  initialize: () =>
    $(document).on('click', '#dataCriteria .paramGroup', bonnie.patientBuilder.toggleDataCriteriaTree)
