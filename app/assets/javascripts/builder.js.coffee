bonnie = @bonnie || {}

class @bonnie.Builder
  constructor: (data_criteria, measure_period, preconditions, fields, value_sets, statuses_by_definition) ->
    @measure_period = new bonnie.MeasurePeriod(measure_period)
    @field_map = fields
    @data_criteria = {}
    @query = new queryStructure.Query()
    @value_sets = {}
    @preconditions = preconditions || {}
    @value_sets[s.oid] = s for s in value_sets
    @statuses_by_definition = statuses_by_definition
    for key in _.keys(data_criteria)
      @data_criteria[key] = new bonnie.DataCriteria(key, data_criteria[key], @measure_period)

  dataKeys: =>
    _.keys(@data_criteria)

  dataCriteria: (key) =>
    @data_criteria[key]

  updateDisplay: () =>
    alert "updating display: " + @data_criteria

  renderMeasureJSON: (data) =>
    @query.rebuildFromJson(data)

    @addParamItems(@query.population.toJson(),$("#initialPopulationItems"))
    @addParamItems((if data.denominator.items.length then @query.denominator.toJson() else 'DENOMINATOR_PLACEHOLDER'),$("#eligibilityMeasureItems"))
    @addParamItems(@query.numerator.toJson(),$("#outcomeMeasureItems"))
    @addParamItems(@query.exclusions.toJson(),$("#exclusionMeasureItems"))
    @addParamItems(@query.exceptions.toJson(),$("#exceptionMeasureItems"))
    @._bindClickHandler()
    
  _bindClickHandler: (selector) ->
    $(selector || '#initialPopulationItems, #eligibilityMeasureItems, #outcomeMeasureItems, #exclusionMeasureItems, #exceptionMeasureItems').find('.paramItem[data-precondition-id], .paramItem[data-criteria-id]').click((event) =>
      $('.paramItem').removeClass('editing')
      return if $('#text_view_styles').prop('disabled')-1
      $('.paramItem[data-criteria-id=' + $(event.currentTarget).data('criteria-id') + '], .paramItem[data-precondition-id=' + $(event.currentTarget).data('precondition-id') + ']').addClass('editing')
      @editDataCriteria(event.currentTarget)
      event.stopPropagation()
    )

  renderCriteriaJSON: (data, target) =>
    @addParamItems(data,target)

  editDataCriteria: (element) =>
    leaf = $(element)

    top = $('#workspace > div').css('top')
    $('#workspace').empty();
    element =
      if data_criteria = @dataCriteria($(element).data('criteria-id'))
        bonnie.template('data_criteria_edit', $.extend({}, data_criteria, {precondition_id: $(element).data('precondition-id')})).appendTo('#workspace')
      else if $(element).data('precondition-id')
        bonnie.template('precondition_edit', {id: $(element).data('precondition-id'), precondition_id: $(element).data('precondition-id')}).appendTo('#workspace')


    offset = leaf.offset().top + leaf.height()/2 - $('#workspace').offset().top - element.height()/2
    offset = 0 if offset < 0
    maxoffset = $('#measureEditContainer').height() - element.outerHeight(true) - $('#workspace').position().top - $('#workspace').outerHeight(true) + $('#workspace').height()
    offset = maxoffset if offset > maxoffset
    element.css("top", offset)
    arrowOffset = leaf.offset().top + leaf.height()/2 - element.offset().top - $('.arrow-w').outerHeight()/2
    arrowOffset = 0 if arrowOffset < 0
    $('.arrow-w').css('top', arrowOffset)
    element.css("top", top)
    element.animate({top: offset})

    if data_criteria
      data_criteria.getProperty = (ns) ->
        obj = this
        y = ns.split(".")
        for i in [0..y.length-1]
          if obj[y[i]]
            obj = obj[y[i]]
          else
            return
        obj

      element.find('select[name=status]').val(data_criteria.status)
      element.find('select[name=category]').val(data_criteria.definition).on('change', ->
        $(this).parents('form').find('select[name=subcategory]').empty().append(
          bonnie.builder.statuses_by_definition[$(this).val()].map( (e)->
            $(document.createElement('option')).val(e).text(e).get(0)
          )
        )
      ).trigger('change');
      element.find('input.value_type[type=radio]').change(
        ( ->
          element.find('input.value_type[type=radio]').not(@).prop('checked', null)
          element.find('.criteria_value_value').children().show().not('.' +
            switch(if @ instanceof String then @toString() else $(@).val())
              when 'PQ' then 'data_criteria_value'
              when 'IVL_PQ' then 'data_criteria_range'
              when 'CD' then 'data_criteria_oid'
          ).hide()
          arguments.callee
        ).call data_criteria.value && data_criteria.value.type || 'PQ'
      ).filter('[value=' + (data_criteria.value && data_criteria.value.type || 'PQ') + ']').prop('checked', 'checked')
      element.find('select.data_criteria_oid').val(data_criteria.value && data_criteria.value.code_list_id)

      element.find('select[name=negation]').val('true' if data_criteria.negation)
      element.find('.negation_reason_oid').slideDown() if data_criteria.negation
      element.find('select[name=negation_code_list_id]').val(data_criteria.negation_code_list_id)

      temporal_element = $(element).find('.temporal_reference')
      $.each(data_criteria.temporal_references, (i, e) ->
        $(temporal_element[i]).find('.temporal_type').val(e.type)
        $(temporal_element[i]).find('.temporal_relation').val(
          (if e.offset && e.offset.value < 0 then 'lt' else 'gt') +
          if e.offset && e.offset.inclusive then 'e' else ''
        )
        $(temporal_element[i]).find('.temporal_range_high_relation').val(if e.range && e.range.high && e.range.high.inclusive then 'lte' else 'lt')
        $(temporal_element[i]).find('.temporal_range_high_unit').val(if e.range && e.range.high then e.range.high.unit)
        $(temporal_element[i]).find('.temporal_range_low_relation').val(if e.range && e.range.low && e.range.low.inclusive then 'gte' else 'gt')
        $(temporal_element[i]).find('.temporal_range_low_unit').val(if e.range && e.range.low then e.range.low.unit)
        $(temporal_element[i]).find('.temporal_drop_zone').each((i, e) ->
          fillDrop(e);
        ).droppable({ tolerance: 'pointer', greedy: true, accept: 'label.ui-draggable', drop: ((e,ui) -> fillDrop(e)) });
      );

      subset_element = $(element).find('.subset_operator')
      $.each(data_criteria.subset_operators, (i, e) ->
        $(subset_element[i]).find('.subset_type').val(e.type)
        if e.range && e.range.low && e.range.high && e.range.low.equals(e.range.high) && e.range.low.inclusive
          $(subset_element[i]).find('.subset_range_type[value=value]').attr('checked', true)
          $(subset_element[i]).find('.data_criteria_value').siblings().hide()
        else
          $(subset_element[i]).find('.subset_range_type[value=range]').attr('checked', true)
          $(subset_element[i]).find('.data_criteria_range').siblings().hide()
          $(subset_element[i]).find('.data_criteria_range_high_relation').val(if e.range && e.range.high && e.range.high.inclusive then 'lte' else 'lt')
          $(subset_element[i]).find('.data_criteria_range_low_relation').val(if e.range && e.range.low && e.range.low.inclusive then 'gte' else 'gt')
      )

      field_element = $(element).find('.field_value')
      i = 0
      $.each(data_criteria.field_values || {}, (k, e) ->
        $(f = field_element[i++]).find('.field_type').val(k)
        $(f).find('.data_criteria_oid').val(e.code_list_id)
      )

  getNextChildCriteriaId: (base, start)=>
    id = start || 1
    id++  while @data_criteria[base + id]
    base+id

  editDataCriteria_submit: (form) =>
    temporal_references = []
    subset_operators = []
    field_values = {}

    $(form).find('.temporal_reference').each((i, e) ->
      temporal_references.push({
        type: $(e).find('.temporal_type').val()
        range: {
          type: 'IVL_PQ'
          high: {
            type: 'PQ'
            value: $(e).find('.temporal_range_high_value').val()
            unit: $(e).find('.temporal_range_high_unit').val()
            'inclusive?': $(e).find('.temporal_range_high_relation').val().indexOf('e') > -1
          } if $(e).find('.temporal_range_high_value').val()
          low: {
            type: 'PQ'
            value: $(e).find('.temporal_range_low_value').val()
            unit: $(e).find('.temporal_range_low_unit').val()
            'inclusive?': $(e).find('.temporal_range_low_relation').val().indexOf('e') > -1
          } if $(e).find('.temporal_range_low_value').val()
        } if $(e).find('.temporal_range_high_value').val() || $(e).find('.temporal_range_low_value').val()
        reference: (
          if $(e).find('.temporal_reference_value').length > 1
            $.post('/measures/' + $(form).find('input[type=hidden][name=id]').val() + '/upsert_criteria', {
              criteria_id: (id = bonnie.builder.getNextChildCriteriaId($(form).find('input[type=hidden][name=criteria_id]').val() + '_CHILDREN_', id))
              children_criteria: $.map($(e).find('.temporal_reference_value'), ((e) -> $(e).val()))
              standard_category: 'temporal'
              type: 'derived'
            }) && id
          else $(e).find('.temporal_reference_value').val()
        )
      }) if $(e).find('.temporal_type').val() && $(e).find('.temporal_reference_value').first().val()
    )
    $(form).find('.subset_operator').each((i, e) ->
      subset_operators.push({
        type: $(e).find('.subset_type').val()
        value: {
          type: 'IVL_PQ'
          high: if $(e).find('.subset_range_type:checked').val() == 'value' then {
            type: 'PQ'
            value: $(e).find('.data_criteria_value_value').val()
            unit: $(e).find('.data_criteria_value_unit').val()
            'inclusive?': true
          } else {
            type: 'PQ'
            value: $(e).find('.data_criteria_range_high_value').val()
            unit: $(e).find('.data_criteria_range_high_unit').val()
            'inclusive?': $(e).find('.data_criteria_range_high_relation').val().indexOf('e') > -1
          } if $(e).find('.data_criteria_range_high_value').val()
          low: if $(e).find('.subset_range_type:checked').val() == 'value' then {
            type: 'PQ'
            value: $(e).find('.data_criteria_value_value').val()
            unit: $(e).find('.data_criteria_value_unit').val()
            'inclusive?': true
          } else {
            type: 'PQ'
            value: $(e).find('.data_criteria_range_low_value').val()
            unit: $(e).find('.data_criteria_range_low_unit').val()
            'inclusive?': $(e).find('.data_criteria_range_low_relation').val().indexOf('e') > -1
          } if $(e).find('.data_criteria_range_low_value').val()
        } if (if $(e).find('.subset_range_type:checked').val() == 'value' then $(e).find('.data_criteria_value_value').val() else $(e).find('.data_criteria_range_high_value').val() || $(e).find('.data_criteria_range_low_value').val())
      })
    )
    $(form).find('.field_value').each((i, e) =>
      field_values[$(e).find('.field_type').val()] = {
        code_list_id: oid = $(e).find('.data_criteria_oid').val()
        title: @value_sets[oid].concept
        type: 'CD'
      } if @value_sets[$(e).find('.data_criteria_oid').val()]
    )
    !$(form).ajaxSubmit({
      data: {
        negation_code_list_id: $(form).find('.negation_reason_oid select').val() if $(form).find('select[name=negation]').val()
        value: JSON.stringify(
          switch $(form).find('.criteria_value input.value_type[type=radio]:checked').val()
            when 'PQ'
              {
                type: 'PQ'
                value: $(form).find('.criteria_value .data_criteria_value_value').val()
                unit: $(form).find('.criteria_value .data_criteria_value_unit').val()
              } if $(form).find('.criteria_value .data_criteria_value_value').val()
            when 'IVL_PQ'
              {
                type: 'IVL_PQ'
                low: {
                  type: 'PQ'
                  value: $(form).find('.criteria_value .data_criteria_range_low_value').val()
                  unit: $(form).find('.criteria_value .data_criteria_range_low_unit').val()
                } if $(form).find('.criteria_value .data_criteria_range_low_value').val()
                high: {
                  type: 'PQ'
                  value: $(form).find('.criteria_value .data_criteria_range_high_value').val()
                  unit: $(form).find('.criteria_value .data_criteria_range_high_unit').val()
                } if $(form).find('.criteria_value .data_criteria_range_high_value').val()
              } if $(form).find('.criteria_value .data_criteria_range_low_value').val() || $(form).find('.criteria_value .data_criteria_range_high_value').val()
            when 'CD'
              {
                type: 'CD'
                code_list_id: $(form).find('.criteria_value .data_criteria_oid').val()
                title: $(form).find('.criteria_value .data_criteria_oid > option:selected').text()
              } if $(form).find('.criteria_value .data_criteria_oid').val()
        )

        temporal_references: JSON.stringify(temporal_references) if !$.isEmptyObject(temporal_references)
        subset_operators: JSON.stringify(subset_operators) if !$.isEmptyObject(subset_operators)
        field_values: JSON.stringify(field_values) if !$.isEmptyObject(field_values)
      }
      success: (r) =>
        @data_criteria[r.id] = new bonnie.DataCriteria(r.id, r, @measure_period)
        @addParamItems(@query.population.toJson(),$("#initialPopulationItems").empty())
        @_bindClickHandler("#initialPopulationItems")
        @addParamItems(@query.denominator.toJson(),$("#eligibilityMeasureItems").empty())
        @_bindClickHandler("#eligibilityMeasureItems")
        @addParamItems(@query.numerator.toJson(),$("#outcomeMeasureItems").empty())
        @_bindClickHandler("#outcomeMeasureItems")
        @addParamItems(@query.exclusions.toJson(),$("#exclusionMeasureItems").empty())
        @_bindClickHandler("#exclusionMeasureItems")
        @addParamItems(@query.exceptions.toJson(),$("#exceptionMeasureItems").empty())
        @_bindClickHandler("#exceptionMeasureItems")

        @showSaved('#workspace')

        $('.paramItem[data-criteria-id=' + $('#workspace form > input[name=criteria_id]').val() + ']').stop(true).css('background-color', '#AAD9FF').animate({'background-color': '#DDF0FF'}, 1200, ->
            $(@).css('background-color', '').addClass('editing')
        );
    });

  showSaved: (e) =>
    $(e).find('.edit_save_message').empty().append('<span style="color: green">Saved!</span>')
    setTimeout (->
      $(e).find(".edit_save_message > span").fadeOut ->
        $(this).remove()
    ), 3000

  pushTree: (queryObj) =>
    finder = queryObj
    f = (while finder.parent
      finder = finder.parent
    ).pop()

    switch f
      when @query.population
        $("#initialPopulationItems").empty()
        @saveTree(@query.population.toJson(), 'IPP', 'Initial Patient Population')
        @_bindClickHandler("#initialPopulationItems")
      when @query.denominator
        $("#eligibilityMeasureItems").empty()
        @saveTree(@query.denominator.toJson(), 'DENOM', 'Denominator')
        @_bindClickHandler("#eligibilityMeasureItems")
      when @query.numerator
        $("#outcomeMeasureItems").empty()
        @saveTree(@query.numerator.toJson(), 'NUMER', 'Numerator')
        @_bindClickHandler("#outcomeMeasureItems")
      when @query.exclusions
        $("#exclusionMeasureItems").empty()
        @saveTree(@query.exclusions.toJson(), 'DENEX', 'Denominator Exclusions')
        @_bindClickHandler("#exclusionMeasureItems")
      when @query.exceptions
        $("#exceptionMeasureItems").empty()
        @saveTree(@query.exceptions.toJson(), 'EXCEP', 'Denominator Exceptions')
        @_bindClickHandler("#exceptionMeasureItems")

  saveTree: (query, key, title) ->
    ((o) ->
      delete o.parent
      for k of o
        arguments.callee o[k]  if typeof o[k] is "object"
    ) query = query

    $.post(bonnie.builder.update_url, {'csrf-token': $('meta[name="csrf-token"]').attr('content'), data: {'conjunction?': true, type: key, title: title, preconditions: query}}, (r) =>
      for key in _.keys(r.data_criteria)
        @data_criteria[key] = new bonnie.DataCriteria(key, r.data_criteria[key], @measure_period)
      @renderMeasureJSON(r.population_criteria)
    )

  addParamItems: (obj,elemParent,parent_obj) =>
    builder = bonnie.builder
    items = obj["items"]
    data_criteria = builder.dataCriteria(obj.id) if (obj.id)
    parent = obj.parent
    makeDropFn = (self) ->
      queryObj = obj.parent ? obj
      dropFunction = (event,ui) ->

        target = event.target

        orig = ui.draggable.data('logic-id') ? {}
        dropY = event.pageY
        child_items = $(@).children(".paramGroup")
        after = null
        before = child_items[0] if child_items.length
        pos = 0
        for item,i in child_items
          item_top = $(item).offset().top;
          item_height = $(item).height();
          item_mid = item_top + Math.round(item_height/2)
          if item_mid > dropY
            break
        if i > 0
          after  = queryObj.children[i-1]
        else
          after = null
        if i < child_items.length
          before   = queryObj.children[i]
        else
          before = null
        pos = i
        id = $(ui.draggable).data('criteria-id')

        if queryObj instanceof queryStructure.Container
          tgt = queryObj
        else
          tgt = queryObj.parent
        if (orig.parent? && orig.parent is tgt)
          # Dropped on my own box
          g = tgt.childIndexByKey(orig,'precondition_id')
          c1 = tgt.removeAtIndex(g)
          if c1
            tgt.add(c1[0],after)
          #else
            # could we still add the object if the remove fails?
            #tgt.add(orig,after)
          $(ui.draggable).remove()
        else
          if (orig.parent? && orig.parent isnt tgt)
            # dropped on different box
            g = orig.parent.childIndexByKey(orig,'precondition_id')
            c1 = orig.parent.removeAtIndex(g)
            if c1
              tgt.add(c1[0], after)
            #else
              # what to do if we don't pull the item off the original container?
              # tgt.add(orig,after)
            if orig.parent.children.length < 2
              # there is only 1 child left in my container
              # remove and push the child to the grandparent
              lastChild = orig.parent.removeAtIndex(0).pop()
              p = orig.parent.parent.childIndexByKey(orig.parent,'myid')
              orig.parent.parent.removeAtIndex(p)
              lastChild.parent = orig.parent.parent
              orig.parent.parent.children.splice(p,0,lastChild)

            $(ui.draggable).remove()
          else
            # dropped from outside / left sidebar
            tgt.add(
              id: id
              data_criteria: self.data_criteria[id]
            after
            )
        $(ui.helper).remove();
        _.bind(self._out,@)()
        $('#workspace').empty()
        bonnie.builder.pushTree(queryObj)
      return dropFunction

    makeItemDropFn = (self) ->
      queryObj = obj
      dropFunction = (event,ui) ->

        target = event.target
        orig = ui.draggable.data('logic-id') ? {}

        id = $(ui.draggable).data('criteria-id')

        tgt = obj
        parent = obj.parent
        # if you are dropping on an item that is a temporal reference, the item has no parent attribute so just skip entirely for now
        if parent
          if (orig.parent? && orig.parent isnt tgt)
            # item was dropped on a different container
            g = orig.parent.childIndexByKey(orig,'precondition_id')
            c1 = orig.parent.removeAtIndex(g)
            g = parent.childIndexByKey(obj,'precondition_id')
            c2 = parent.removeAtIndex(g)
            if c1 && c2
              if parent.conjunction ==  'or'
                child = new queryStructure.AND()
              else
                child = new queryStructure.OR()
              child.parent = parent
              child.add(c1[0])
              child.add(c2[0])
              parent.children.splice(g,0,child)
            #else
              # what to do if the object remove fails?
            # now we need to clean up the orig.parent - we do not want to leave an empty AND or OR container there
            if orig.parent.children.length < 2
              # there is only 1 child left in my container
              lastChild = orig.parent.removeAtIndex(0).pop()
              p = orig.parent.parent.childIndexByKey(orig.parent,'myid')
              orig.parent.parent.removeAtIndex(p)
              lastChild.parent = orig.parent.parent
              orig.parent.parent.children.splice(p,0,lastChild)
            $(ui.draggable).remove()
          else
            # dropped from outside / left sidebar
            g = parent.childIndexByKey(obj,'precondition_id')
            c1 = parent.removeAtIndex(g)
            if c1
              if parent.conjunction ==  'or'
                child = new queryStructure.AND()
              else
                child = new queryStructure.OR()
              child.parent = parent
              child.add(c1[0])
              child.add(
                id: id
                data_criteria: self.data_criteria[id]
              )
              parent.children.splice(g,0,child)
            #else
              # what to do if the object remove fails?
        else
          alert("No parent on this item. Can't add data criteria")

        $(ui.helper).remove();
        _.bind(self._out,@)()
        $('#workspace').empty()
        bonnie.builder.pushTree(queryObj)
      return dropFunction


    if $(elemParent).not(".ui-droppable").hasClass('paramItem')
      $(elemParent).data("query-struct",parent)

      elemParent.droppable(
          over:  @._over
          tolerance:'pointer'
          greedy: true
          accept:'label.ui-draggable, .paramText, .logicLeaf'
          out:  @._out
          drop: makeDropFn(@)
      )

    if (data_criteria?)
      if (data_criteria.subset_operators?)
        for subset_operator in data_criteria.subset_operators
          $(elemParent).append("<span class='#{subset_operator.type} subset-operator'>#{subset_operator.title()}</span>")
        parent_obj = obj

      if (data_criteria.children_criteria?)
        items = data_criteria.childrenCriteriaItems()

      else
        # we dont have a nested measure clause, add the item to the bottom of the list
        # if (!elemParent.hasClass("paramItem"))
        items = data_criteria.temporalReferenceItems()
        if items && !parent_obj?
          parent_obj = obj
        elemParent = bonnie.template('param_group', obj).appendTo(elemParent).find(".paramItem:last").data('logic-id', obj)
        $(elemParent).parent().find('.display_name').click((e)->
          $(this).toggleClass('collapsed')
          $(this).siblings().slideToggle()
          e.stopPropagation()
        )
        elemParent.droppable(
          over:  @._overItem
          tolerance:'pointer'
          greedy:true
          accept:'label.ui-draggable, .paramText, .logicLeaf'
          out:  @._out
          drop: makeItemDropFn(@)
        )
        $item = data_criteria.asHtml('data_criteria_logic')

        $item.appendTo(elemParent)

        ###
        here we need to decide if we are dragging the .paramItem or the parent .paramGroup
        The parent .paramGroup has the thicker left border, and looks like it should all be
        part of the same draggable 'item' on the screen.
        ###
        elemParent.draggable(
          helper:"clone"
          revert:true
          distance:3
          xhandle: ".paramGroup"
          opacity:1
          zIndex:10000
          start: (event,ui) ->
            $(event.target).closest(".paramGroup").addClass("dragged")
            $(ui.helper).find('.paramText').siblings().hide()
            $(ui.helper).width($(@).closest('.paramItem').width()+12)
          stop: (event,ui) ->
            $(event.target).closest(".paramGroup").removeClass("dragged")
        )
        elemParent.data('group_id',obj.group_id) if obj.group_id
    else if obj == 'DENOMINATOR_PLACEHOLDER'
      bonnie.template('param_group').appendTo(elemParent).find(".paramItem:last").data('logic-id', obj).append(bonnie.template('data_criteria_logic', {title: 'Denominator consists only of IPP', category: 'initial patient population'}));

    if ($.isArray(items))
      conjunction = obj['conjunction']
      builder.renderParamItems(conjunction, items, elemParent, obj,parent_obj)

  _over: ->
    $(@).parents('.paramItem').removeClass('droppable')
    $(@).addClass('droppable')
  _overGroup: ->
    $(@).toggleClass('droppable3',true)
  _outGroup: ->
    $(@).toggleClass('droppable3',false)
  _overItem: ->
    $(@).parents('.paramItem').removeClass('droppable2')
    $(@).addClass('droppable2')

  _out: ->
    $(@).removeClass('droppable').removeClass('droppable2')

  renderParamItems: (conjunction, items, elemParent, obj,parent_obj) =>
    neg = (obj.negation || false) && obj.negation != 'false'
    builder = bonnie.builder
    data_criteria = @dataCriteria(obj.id) if (obj.id)
    group_id = obj.group_id

    makeGroupDropFn = (self) ->
      queryObj = obj.parent ? obj
      currentItem = data_criteria.children_criteria
      parent_obj = parent_obj
      dropFn = (event,ui) ->
        origId = ui.draggable.data('criteria-id') ? null
        target = event.currentTarget
        dropY = event.pageY
        child_items = $(@).children(".paramGroup")
        after = null
        before = child_items[0] if child_items.length
        pos = 0
        group_id = $(ui.draggable).data('group_id')
        for item,i in child_items
          item_top = $(item).offset().top;
          item_height = $(item).height()
          item_mid = item_top + Math.round(item_height/2)
          if item_mid > dropY
            break
        pos = i
        if group_id? && queryObj?.id == group_id
          # Moving within my own box
          k = _.indexOf(currentItem,origId)
          c1 = currentItem.splice(k,1) if k > -1
          # need to readjust the drop position because we've remove a previous element
          pos = pos - 1 if k < pos
        currentItem.splice(pos,0,origId) if origId?
        $(ui.helper).remove()
        _.bind(self._outGroup,@)()
        $('#workspace').empty()
        bonnie.builder.pushTree(parent_obj)
      return dropFn

    if items.length > 1
      elemParent = bonnie.template('param_group', $.extend({}, obj, {conjunction: conjunction || items[0] && items[0].conjunction})).appendTo(elemParent).find(".paramItem:last").data('logic-id', obj)
      # here is where we check for subset group criteria, and add droppable handler
      # subset groups have children array with an id on each item
      if items[0]?.children?[0]?.id?
        # we're inside a group data criteria
        group_id = obj.id
        elemParent.droppable(
          greedy:true
          over: @._overGroup
          out: @._outGroup
          tolerance: 'pointer'
          accept: 'label.ui-draggable, .paramText, .logicLeaf'
          drop: makeGroupDropFn(@)
        )

      $(elemParent).parent().find('.display_name').click((e)->
        $(this).toggleClass('collapsed')
        $(this).siblings().slideToggle();
        e.stopPropagation()
      );



    $.each(items, (i,node) ->
      $(elemParent).append("<span class='not'>not</span>") if neg

      if (node.temporal)
        $(elemParent).append("<span class='#{node.conjunction} temporal-operator'>#{node.title}</span><span class='block-down-arrow'></span>")
      node.group_id = group_id ? null
      builder.addParamItems(node,elemParent,parent_obj)
      if (i < items.length-1 and !node.temporal)
        next = items[i+1]
        conjunction = node.conjunction if !conjunction
        $(elemParent).append("<span class='conjunction "+conjunction+"'>"+conjunction+"</span>")
    )


  toggleDataCriteriaTree: (element) =>
    $(element.currentTarget).closest(".paramGroup").find("i").toggleClass("icon-chevron-right").toggleClass("icon-chevron-down")
    category = $(element.currentTarget).data('category');
    children = $(".#{category}_children")
    if (children.is(':visible'))
      children.hide("blind", { direction: "vertical" }, 500)
    else
      children.show("blind", { direction: "vertical" }, 500)

  addDataCriteria: (criteria) =>
    @data_criteria[criteria.id] = criteria = new bonnie.DataCriteria(criteria.id, criteria)
    $c = $('#dataCriteria>div.paramGroup[data-category="' + criteria.buildCategory() + '"]');
    if $c.length
      $e = $c.find('span')
      $e.text(parseInt($e.text()) + 1)
    else
      $c = $('
        <div class="paramGroup" data-category="' + criteria.buildCategory() + '">
          <div class="paramItem">
            <div class="paramText ' + criteria.buildCategory() + '">
              <label>' + criteria.standard_category + '(<span>1</span>)</label>
            </div>
          </div>
        </div>
      ').insertBefore('#dataCriteria .paramGroup[data-category=newDataCriteria]')
    $('
      <div class="paramItem">
        <div class="paramText">
          <label>' + criteria.title + (if criteria.status then ': '+ criteria.status else '') + '</label>
        </div>
      </div>
    ').appendTo(
      $(
        $c.nextUntil('#dataCriteria .paramGroup', '#dataCriteria .paramChildren')[0] ||
        $('<div class="paramChildren ' + criteria.buildCategory() + '_children" style="background-color: #F5F5F5;"></div>').insertAfter($c)
      )
    )

  delete_criteria_handler: ->
    find = (e, arr, key)->
     for k of arr
       return Number(k) if e[key] == arr[k][key]

    criteria_id = $(this).parentsUntil("#workspace").last().find("form > input[type=hidden][name=criteria_id]").val()
    precondition_id = $(this).parentsUntil("#workspace").last().find("form > input[type=hidden][name=precondition_id]").val()
    bonnie.template("confirm_criteria_delete",
      criteria_id: criteria_id
      precondition_id: precondition_id
    ).bind("hidden", ->
      $(this).remove()
    ).on("click", "input#confirm_criteria_delete_confirm", ->
      e = $("[data-precondition-id=" + precondition_id + "]").data("logic-id")
      if !e.parent.parent
        bonnie.builder.pushTree($.extend(e.parent, {children: []}));
      else if e.parent && e.parent.children.length <3
        bonnie.builder.pushTree(e.parent.parent.children.splice(find(e.parent, e.parent.parent.children, 'precondition_id'), 1, $.extend((if find(e, e.parent.children, 'precondition_id') then e.parent.children[0] else e.parent.children[1]), {parent: e.parent.parent}))[0])
      else
        bonnie.builder.pushTree(e.parent.children.splice(find(e, e.parent.children, 'precondition_id'), 1)[0])
      $('#confirm_criteria_delete').modal('hide')
      $('#workspace').empty()
      bonnie.builder._bindClickHandler()
    ).appendTo(document.body).modal()

  add_new_criteria: ->
    bonnie.template('data_criteria_new').appendTo(document.body).modal()
    $('#data_criteria_new select[name=category]').trigger('change')

class Page
  constructor: (data_criteria, measure_period, update_url, preconditions, fields, value_sets, statuses_by_definition) ->
    bonnie.builder = new bonnie.Builder(data_criteria, measure_period, preconditions, fields, value_sets, statuses_by_definition)
    bonnie.builder['update_url'] = update_url

  initialize: () =>
    $(document).on('click', '#dataCriteria .paramGroup', bonnie.builder.toggleDataCriteriaTree)
    $('.nav-tabs li').click((element) -> $('#workspace').empty() if !$(element.currentTarget).hasClass('active') )
