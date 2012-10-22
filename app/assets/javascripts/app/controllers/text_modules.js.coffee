$ = jQuery.sub()

class App.TextModuleUI extends App.Controller
  events:
    'click [data-type=save]':   'create',
    'click [data-type=text_module_delete]': 'delete',
    'click [data-type=edit]':               'select',
    'click .close':                         'close',
    'dblclick [data-type=edit]':            'paste',

  constructor: ->
    super

    # fetch item on demand
    fetch_needed = 1
    if App.Collection.count( 'TextModule' ) > 0
      fetch_needed = 0
      @render()

    if fetch_needed
      @reload()

  reload: =>
      App.TextModule.bind 'refresh', =>
        @log 'loading....'
        @render()
        App.TextModule.unbind 'refresh'
      App.Collection.fetch( 'TextModule' )

  render: =>

    ui = @
    ui.Capture = false
    ui.CaptureList = ''

    # define elements to observe
    inputElement = $('textarea')

    # set first text element to active
    ui.area = $( inputElement[0] )

    # remember active text element
    inputElement.bind('focusin', ->
      @uiWidget = ui
      ui.area = $(@)
      update = =>

        left = @uiWidget.area.offset().left
        top  = @uiWidget.area.offset().top
        width = @uiWidget.area.width()
        console.log 'TEXTAREA', left, top, width
        @uiWidget.el.offset( left: left + width + 20, top: top )
        @uiWidget.el.find('.well').removeClass('hide')

        topWindow = $(window).scrollTop() + 50
        if top < topWindow
          @uiWidget.el.offset( top: topWindow )
      ui.interval( update, 150, 'text_module_box' )
    )
    inputElement.bind('focusout', ->
      ui.clearInterval( 'text_module_box' )
    )

    inputElement.bind('keydown', (e) ->

      # lisen if crtl is pressed
      if ui.Capture

        # lookup key
        key = App.ClipBoard.keycode( e.keyCode )

        # remove one char
        if key is 'backspace'
          ui.CaptureList = ui.CaptureList.slice( 0, -1 )

        # take over
        else if key is 'enter'
          objects = ui.objectSearch( ui.CaptureList )
          if objects[0]
            ui._insert( objects[0].content, ui )

            # reset search
            ui.CaptureList = ''
            ui.renderTable()

        # add char to search selection
        else if key is 'space' || key.length is 1
          if key is 'space'
            ui.CaptureList = ui.CaptureList + ' '
          else
            ui.CaptureList = ui.CaptureList + key

          # prevent default key action
          e.preventDefault()

        console.log 'CTRL+', ui.CaptureList
        ui.el.find('#text-module-search').val( ui.CaptureList )
        ui.renderTable( ui.CaptureList )

      # start current search process
      if e.ctrlKey
        ui.Capture = true
    )

    # start current search process
    # do code to test other keys
    inputElement.bind('keyup', (e) ->
      if e.keyCode == 17
        console.log 'CTRL UP - pressed ', ui.CaptureList
        ui.el.find('#text-module-search').val( '' )
        ui.CaptureList = ''
        ui.Capture = false
        ui.renderTable()
    )

    # insert data
    @html App.view('text_module')(
      search: @search,
    )

    # rerender if search phrase has changed
    @el.find('#text-module-search').unbind('keyup').bind('keyup', =>
      search = $('#text-module-search').val()
      @renderTable( search )
    )

    @renderTable('')

  objectSearch: (search) =>
    objects = App.Collection.all(
      type:   'TextModule',
      sortBy: 'name',
      filter: { active: true },
      filterExtended: [ { name: search }, { content: search }, { keywords: search } ],
    )

  renderTable: (search) =>

    objects = @objectSearch(search)

    @el.find('#form-text-module').html('')
    new App.ControllerTable(
      el: @el.find('#form-text-module'),
      header:   [],
      overview: ['name'],
      model:    App.TextModule,
      objects:  objects,
#      radio:    true,
    )

    # remove old popovers
#    @el.find('.popover-inner').parent().remove()
    $('.popover').remove()

    # show user popup    
    @el.find('#form-text-module').find('.item').popover(
      delay: { show: 500, hide: 1200 },
#      placement: 'top',
      placement: 'right',
      title: ->
        id = $(@).data('id')
        text_module = App.Collection.find( 'TextModule', id )
        text_module.name
      content: ->
        id = $(@).data('id')
        text_module = App.Collection.find( 'TextModule', id )
        text_module.content
    )

  paste: (e) =>
    e.preventDefault()
    id = $(e.target).parents('tr').data('id')
    text_module = App.Collection.find( 'TextModule', id )
    @_insert( text_module.content, @ )

  delete: (e) =>
    e.preventDefault()

    # get params
    params = @formParam(e.target)
    text_module = App.Collection.find( 'TextModule', params['text_module_id'] )
    if confirm('Sure?')
      text_module.destroy() 
      @render()

  select: (e) =>
    e.preventDefault()
    id = $(e.target).parents('tr').data('id')
    text_module = App.Collection.find( 'TextModule', id )
    @el.find('#text-module-preview-content').val( text_module.content )
    @el.find('#text_module_name').val( text_module.name )

  create: (e) =>
    e.preventDefault()

    # get params
    params = @formParam(e.target)
    name = params['name']
#    delete params['text_module_name']

    text_module = App.Collection.findByAttribute( 'TextModule', 'name', name )
    if !text_module
      text_module = new App.TextModule

    content = App.ClipBoard.getSelectedLast()
    text_module.load(
      name:    params['name'],
      content: content,
      active:  true,
    )

    # validate form
    errors = text_module.validate()

    # show errors in form
    if errors
      @log 'error new', errors
    else
      ui = @
      text_module.save(
        success: ->
          ui.renderTable()
          ui.log 'save success!'

        error: ->
          ui.log 'save failed!'
      )

  close: (e) =>
    e.preventDefault()
    @el.find('.well').addClass('hide')
    @clearInterval( 'text_module_box' )

  _insert: (contentNew, ui) ->
    position = ui.area.prop('selectionStart')
    content = ui.area.val()
    start = content.substr( 0, position )
    end   = content.substr( position, content.length )

    # check if \n is needed
    startEnd = start.substr( start.length-2, 2 )

    if position is 0 || startEnd is "\n\n"
      startDiver = ''
    else
      startDiver = "\n"
    content = start + startDiver + contentNew + end
    ui.area.val(content)

    # update cursor position
    currentPosition = (position + contentNew.length + startDiver.length )
    ui.area.prop('selectionStart', currentPosition )
    ui.area.prop('selectionEnd', currentPosition )

