{View, $} = require 'atom-space-pen-views'
ConfigView = require './config-view'
{formatFrame} = require './utils'

module.exports =
class GdbToolbarView extends View
    initialize: (gdb) ->
        @gdb = gdb
        @gdb.exec.onStateChanged @_onStateChanged.bind(this)

    @content: ->
        @div class: 'btn-toolbar', =>
            @div class: 'btn-group', =>
                @button class: 'btn icon icon-bug', click: 'do_connect', outlet: 'connect'
                @button class: 'btn icon icon-circle-slash', click: 'do_disconnect', outlet: 'disconnect', style: 'display: none'
            @div class: 'btn-group', =>
                @button class: 'btn icon icon-jump-left', click: 'do_start', outlet: 'start'
                @button class: 'btn icon icon-playback-play', click: 'do_continue', outlet: 'continue'
                @button class: 'btn icon icon-playback-pause', click: 'do_interrupt', outlet: 'interrupt'
            @div class: 'btn-group', =>
                @button 'Next', class: 'btn', click: 'do_next', outlet: 'next'
                @button 'Step', class: 'btn', click: 'do_step', outlet: 'step'
                @button 'Finish', class: 'btn', click: 'do_finish', outlet: 'finish'
            @div class: 'btn-group', =>
                @button class: 'btn icon icon-tools', click: 'do_config'

            @div class: 'state-display', =>
                @span 'DISCONNECTED', outlet: 'state'

    do_connect: -> @gdb.connect()
    do_disconnect: -> @gdb.disconnect()

    do_start: -> @gdb.exec.start()
    do_continue: -> @gdb.exec.continue()
    do_interrupt: -> @gdb.exec.interrupt()
    do_step: -> @gdb.exec.step()
    do_next: -> @gdb.exec.next()
    do_finish: -> @gdb.exec.finish()

    _onStateChanged: ([state, frame]) ->
        if state == 'DISCONNECTED'
            @disconnect.hide()
            @connect.show()
        else
            @disconnect.show()
            @connect.hide()

        switch state
            when 'DISCONNECTED' then cls = 'text-error'
            when 'EXITED' then cls = 'text-warning'
            when 'STOPPED' then cls = 'text-info'
            when 'RUNNING' then cls = 'text-success'

        @state.removeClass()
        if frame?
            console.log formatFrame(frame)
            @state.text formatFrame(frame)
        else
            @state.text state
        @state.addClass cls

    do_config: ->
        new ConfigView(@gdb)
