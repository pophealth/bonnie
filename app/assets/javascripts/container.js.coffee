@queryStructure ||= {}

##########
# Query Structure
##########
# Will need to either update to hold multitple num/denominators or switch to hold just one generic tree
class queryStructure.Query
  constructor: ->
    @structure = new queryStructure.AND(null)

  toJson: ->
    return @structure.toJson()

  rebuildFromJson: (json) ->
    @structure = if json then @buildFromJson(null, json) else new queryStructure.AND(null)

  buildFromJson: (parent, element) ->
    if @getElementType(element) == 'rule'
      return  { 'id': element.id, 'precondition_id': element['precondition_id'] }
    else
      container = @getContainerType(element)
      newContainer = new queryStructure[container](parent, [], element.negation, element['precondition_id'])
      for child in element['items']
        newContainer.add(@buildFromJson(newContainer, child))
      return newContainer

  getElementType: (element) ->
    if element['items']?
      return 'container'
    else
      return 'rule'

  getContainerType: (element) ->
    if element['conjunction']?
      return element['conjunction'].toUpperCase()
    else
      return null


##############
# Containers
##############

class queryStructure.Container
  constructor: (@parent, @children = [], @negation = false, @precondition_id) ->
    @children ||= []

  add: (element, after) ->
    # first see if the element is already part of the children array
    # if it is there is no need to do anything
    index = @children.length
    ci = @childIndex(after)
    if ci != -1
      index = ci + 1
    @children.splice(index,0,element)
    if element.parent && element.parent != this
      element.parent.removeChild(element)
    element.parent = this
    return element

  addAll: (items, after) ->
    for item in items
      after = @add(item,after)

  remove: ->
    if @parent
      @parent.removeChild(this)

  removeChild: (victim) ->
    index = @childIndex(victim)
    if index != -1
      @children.splice(index,1)
      victim.parent = null

  replaceChild: (child, newChild) ->
    index = @childIndex(child)
    if index != -1
      @children[index] = newChild
      child.parent = null
      newChild.parent = this

  moveBefore: (child, other) ->
    i1 = @childIndex(child)
    i2 = @childIndex(other)
    if i1 != -1 && i2 != -1
      child = @children.splice(i2, 1)
      @children.splice(i1-1,0,other)
      return true

    return false

  childIndex: (child) ->
    if child == null
      return -1
    for index, _child of @children
      if _child == child
        return index
    return -1

  clear: ->
    @children = []

  childrenToJson: ->
     childJson = [];
     for child in @children
       js = if child["toJson"] then  child.toJson() else $.extend(true, {}, child)
       childJson.push(js )
     return childJson


class queryStructure.OR extends queryStructure.Container
  constructor: ->
    @conjunction = 'or'
    super

  toJson: ->
    childJson = @childrenToJson()
    return { "conjunction" : "or", "items" : childJson, "negation" : @negation, "parent" : @parent, "precondition_id" : @precondition_id }

  test: (patient) ->
    if (@children.length == 0)
      return true;
    retval = false
    for child in @children
      if (child.test(patient))
        retval = true
        break
    return if @negation then !retval else retval;


class queryStructure.AND extends queryStructure.Container
  constructor: ->
    @conjunction = 'and'
    super

  toJson: ->
    childJson = @childrenToJson()
    return { "conjunction" : "and", "items" : childJson, "negation" : @negation, "parent" : @parent, "precondition_id" : @precondition_id }

  test: (patient) ->
    if (@children.length == 0)
      return true;
    retval = true
    for child in @children
      if (!child.test(patient))
        retval =  false
        break

    return if @negation then !retval else retval

