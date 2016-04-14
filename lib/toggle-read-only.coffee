module.exports =

  activate: ->
    @commandSubscription = atom.commands.add 'atom-text-editor',
      'read-only:toggle': => @toggleReadOnly(atom.workspace.getActiveTextEditor())
      'core:copy': (e) ->
        editor = atom.workspace.getActiveTextEditor()
        return e.abortKeyBinding() unless editor.getBuffer().__isReadOnly is true
        editor.copySelectedText()
    @workspaceSubscription = atom.workspace.observeTextEditors (editor) =>
      editor.onDidTerminatePendingState =>
        editor.terminatePendingState = => @toggleReadOnly(editor)
      for extension in atom.config.get('toggle-read-only.autoReadOnly')
        return @toggleReadOnly(editor) if editor.getPath().endsWith extension

  deactivate: ->
    @commandSubscription.dispose()
    @workspaceSubscription.dispose()

  toggleReadOnly: (editor) ->
    return unless editor?
    if editor.getBuffer().__isReadOnly
      @disableReadOnly(editor)
    else
      @enableReadOnly(editor)

  disableReadOnly: (editor) ->
    buffer = editor.getBuffer()
    buffer.__isReadOnly = false
    buffer.transact = buffer.__transact
    buffer.applyChange = buffer.__applyChange
    buffer.__transact = null
    buffer.__applyChange = null

    editor.getTitle = editor.__getTitle
    editor.__getTitle = null

    buffer.emitter.emit 'did-change-path', buffer.getPath()

  enableReadOnly: (editor) ->
    buffer = editor.getBuffer()
    buffer.__isReadOnly = true
    buffer.__transact = buffer.transact
    buffer.__applyChange = buffer.applyChange
    buffer.transact = ->
    buffer.applyChange = ->

    editor.__getTitle = editor.getTitle

    editor.getTitle = ->
      "[#{@getFileName() ? 'undefined'}]"

    buffer.emitter.emit 'did-change-path', buffer.getPath()
