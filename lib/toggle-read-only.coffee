module.exports =

  activate: ({editors} = {}) ->
    @commandSubscription = atom.commands.add 'atom-text-editor:not([mini])',
      'read-only:toggle': -> toggleReadOnly(atom.workspace.getActiveTextEditor())
      'core:copy': (e) ->
        editor = e.target?.getModel?()
        return e.abortKeyBinding() unless editor?.__hasTROPatch is true and editor.getBuffer().__isReadOnly is true
        editor.copySelectedText()
    @workspaceSubscription = atom.workspace.observeTextEditors (editor) ->
      patchEditor(editor)
      return editor.setReadOnly(true) if editors[editor.getPath()]
      for extension in atom.config.get('toggle-read-only.autoReadOnly')
        return editor.setReadOnly(true) if editor.getPath()?.endsWith extension

  deactivate: ->
    @commandSubscription.dispose()
    @workspaceSubscription.dispose()

  serialize: ->
    data = {}
    for editor in atom.workspace.getTextEditors()
      data[editor.getPath()] = editor.getBuffer().__isReadOnly is true
    editors: data

toggleReadOnly = (editor) ->
  patchEditor(editor)
  editor.setReadOnly(not editor.getBuffer().__isReadOnly)

patchBuffer = (buffer) ->
  return if buffer.__hasTROPatch is true
  buffer.__hasTROPatch = true
  buffer.__isReadOnly = false
  buffer.__transact = buffer.transact
  buffer.__applyChange = buffer.applyChange
  buffer.setReadOnly = (state) ->
    if state is false
      buffer.__isReadOnly = false
      buffer.transact = buffer.__transact
      buffer.applyChange = buffer.__applyChange
    else
      buffer.__isReadOnly = true
      buffer.transact = ->
      buffer.applyChange = ->
    @emitter.emit 'did-change-path', buffer.getPath() # Force tab update

patchEditor = (editor) ->
  return patchBuffer(editor.getBuffer()) if editor.__hasTROPatch is true
  editor.__hasTROPatch = true
  editor.__getTitle = editor.getTitle
  editor.__getReadOnlyTitle = ->
    "[#{@getFileName() ? 'undefined'}]"
  editor.updateReadOnlyTitle = (state) ->
    if state is false
      editor.getTitle = editor.__getTitle
    else
      editor.getTitle = editor.__getReadOnlyTitle
  editor.setReadOnly = (state) ->
    @getBuffer().setReadOnly(state)
  patchBuffer(editor.getBuffer())
  disp = editor.onDidChangePath((->
    @updateReadOnlyTitle(@getBuffer().__isReadOnly)
  ).bind(editor))
  editor.onDidDestroy ->
    disp.dispose()
  editor.setReadOnly(editor.getBuffer().__isReadOnly) # Sync state with buffer
