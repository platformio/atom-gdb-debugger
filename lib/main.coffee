{CompositeDisposable, Emitter} = require 'atom'
GDB = require './mi/gdb'
DebugPanelView = require './debug-panel-view'
StatusView = require './status-view'
Resizable = require './resizable'
GdbCliView = require './gdb-cli-view'
EditorIntegration = require './editor-integration'
fs = require 'fs'


module.exports = PlatformIOIDEDebugger =
    subscriptions: null
    gdb: null
    projectDir: null

    activate: (state) ->
        @state = state
        @state.panelVisible ?= true

        @provider = new Emitter()
        @provider.stop = @stop.bind this
        @provider.debug = @debug.bind this

    debug: (config) ->
        @gdb = new GDB()
        @statusBarTile = @statusBar?.addLeftTile
            item: new StatusView(@gdb)
            priority: 1000
        @cliPanel = atom.workspace.addBottomPanel
            item: new Resizable 'top', @state.cliSize or 150, new GdbCliView(@gdb)
            visible: false
        @panel = atom.workspace.addRightPanel
            item: new Resizable 'left', @state.panelSize or 300, new DebugPanelView(@gdb)
            visible: false

        @subscriptions = new CompositeDisposable
        @subscriptions.add atom.commands.add 'atom-workspace',
            'platformio-ide-debugger:disconnect': => @stop()
            'platformio-ide-debugger:continue': => @cmdWrap => @gdb.exec.continue()
            'platformio-ide-debugger:interrupt': => @cmdWrap => @gdb.exec.interrupt()
            'platformio-ide-debugger:next': => @cmdWrap => @gdb.exec.next()
            'platformio-ide-debugger:step': => @cmdWrap => @gdb.exec.step()
            'platformio-ide-debugger:finish': => @cmdWrap => @gdb.exec.finish()
            'platformio-ide-debugger:toggle-panel': => @toggle(@panel, 'panelVisible')
            'platformio-ide-debugger:toggle-cli': => @toggle(@cliPanel, 'cliVisible')

        @editorIntegration = new EditorIntegration(@gdb)

        if config.env? then process.env = config.env
        @projectDir = config.projectDir
        if not @projectDir and config.clientArgs.indexOf('--project-dir') > -1
            @projectDir = config.clientArgs[config.clientArgs.indexOf('--project-dir') + 1]

        @gdb.connect(config.clientExecutable, config.clientArgs)
        .then =>
            @gdb.set 'confirm', 'off'
        .then =>
            if config.path then @gdb.setFile config.path
        .then =>
            Promise.all(@gdb.send_cli cmd for cmd in config.initCommands)
        .then =>
            if @projectDir and @state.breakpoints?[@projectDir]
                return Promise.all(
                    @gdb.breaks.insert location for location in @state.breakpoints[@projectDir])
        .then =>
            @gdb.exec.start()
        .then =>
            if @state.panelVisible then @panel.show()
            if @state.cliVisible then @cliPanel.show()            
        .catch (err) =>
            atom.notifications.addError 'Error launching PIO Debugger',
                description: err.toString()
                dismissable: true
            @panel.show()
            @cliPanel.show()

    cmdWrap: (cmd) ->
        ret = cmd()
        if ret.catch
            ret
                .catch (err) ->
                  atom.notifications.addError err.toString()
        else
            atom.notifications.addError('Command failed. Lost connection / process terminated.')
    toggle: (panel, visibleFlag) ->
        if panel.isVisible()
            panel.hide()
        else
            panel.show()
        @state[visibleFlag] = panel.isVisible()

    stop: ->
        @editorIntegration?.destroy()
        @panel?.destroy()
        @cliPanel?.destroy()
        @statusBarTile?.destroy()
        @subscriptions?.dispose()
        if not @gdb
            return
        @gdb.disconnect()
        @gdb.destroy()
        @gdb = null
        @provider.emit 'stop'

    deactivate: ->
        @stop()
        @provider.dispose()
        @statusBar = null;

    consumeStatusBar: (statusBar) ->
        @statusBar = statusBar

    serializeBreakpoints: ->
        items = []
        for id, bkpt of @gdb?.breaks.breaks
            if bkpt.type.endsWith('breakpoint') and bkpt.disp != 'del'
                items.push "#{bkpt.file}:#{bkpt.line}"
        return items

    serialize: ->
      if not @gdb
          return @state
      @state.panelSize = @panel?.getItem().size()
      @state.cliSize = @cliPanel?.getItem().size()
      @state.breakpoints ?= {}
      if @projectDir
          @state.breakpoints[@projectDir] = @serializeBreakpoints()
          for key, value of @state.breakpoints
              if not fs.existsSync(key) then delete @state.breakpoints[key]
      return @state

    provideDebugger: ->
    		return @provider
