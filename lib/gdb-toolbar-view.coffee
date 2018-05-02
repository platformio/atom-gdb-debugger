{View, $} = require 'atom-space-pen-views'

module.exports =
class GdbToolbarView extends View
    @cmdMask:
        'DISCONNECTED': ['disconnect', 'toggle-cli']
        'EXITED': ['disconnect', 'continue', 'toggle-cli']
        'STOPPED': ['disconnect', 'continue', 'next', 'step', 'finish', 'toggle-cli']
        'RUNNING': ['disconnect', 'interrupt', 'toggle-cli']

    initialize: (gdb) ->
        @gdb = gdb
        @gdb.exec.onStateChanged @_onStateChanged.bind(this)
        for button in @find('button')
            cmd = button.getAttribute 'command'
            this[cmd] = $(button)
            button.addEventListener 'click', @do

    @content: ->
        @div class: 'btn-toolbar', =>
            @div class: 'btn-group', =>
                @button class: 'btn btn-error icon icon-primitive-square', command: 'disconnect', title: 'Stop / Terminate'
                @button class: 'btn btn-success icon icon-playback-play', command: 'continue', title: 'Resume'
                @button class: 'btn btn-warning icon icon-playback-pause', command: 'interrupt', title: 'Suspend'

            @div class: 'btn-group', =>
                @button class: 'btn btn-primary icon icon-move-right', command: 'next', title: 'Step Over'
                @button class: 'btn btn-primary icon icon-move-down', command: 'step', title: 'Step Into'
                @button class: 'btn btn-primary icon icon-move-up', command: 'finish', title: 'Step Return'

            @button class: 'btn icon icon-terminal', command: 'toggle-cli', title: 'Debug console'

    do: (ev) ->
        command = ev.target.getAttribute 'command'
        atom.commands.dispatch atom.views.getView(atom.workspace), "platformio-ide-debugger:#{command}"

    _onStateChanged: ([state, frame]) ->
        enabledCmds = GdbToolbarView.cmdMask[state]
        for button in @find('button')
            if button.getAttribute('command') in enabledCmds
                button.removeAttribute 'disabled'
            else
                button.setAttribute 'disabled', true
