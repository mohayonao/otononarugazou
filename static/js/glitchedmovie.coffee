$ ->
    'use strict'

    PREVIEW_WIDTH  = 480
    PREVIEW_HEIGHT = 360

    createObjectURL       = (window.URL or window.webkitURL)?.createObjectURL
    requestAnimationFrame = window.webkitRequestAnimationFrame

    app = null

    $(window).on 'dragover', ->
        false

    $(window).on 'drop', (e)->
        if app and createObjectURL
            file = e.originalEvent.dataTransfer.files[0]
            type = file.type.substr 0, 5
            video = document.createElement 'video'
            if type is 'video' and video.canPlayType file.type
                app.setVideo file, ->
                    app.play()
            else 'Oops! Cannot play this movie..'
        false

    unless webkitAudioContext    then return
    unless createObjectURL       then return
    unless requestAnimationFrame then return

    $('#play').on 'click', ->
        app.play()
    $('#pause').on 'click', ->
        app.pause()
    $('#currentTime').on 'change', ->
        app.setCurrentTime ($(this).val()|0) / 10000

    class App
        constructor: ->
            @processor = []

        setVideo: (file, callback)->
            video = document.createElement 'video'
            $(video).on 'loadeddata', =>
                video.muted = true
                @processor.forEach (x)-> x.init video
                callback?()
            $(video).on 'seeked', =>
                if video.paused
                    @processor.forEach (x)-> x.process()
            video.type = file.type
            video.src  = createObjectURL file
            @video = video

        addProcessor: (processor)->
            @processor.push processor

        addSubProcessor: (processor)->
            @processor.forEach (x)-> x.subProcessor = processor

        setCurrentTime: (rate)->
            @video.currentTime = @video.duration * rate

        play: ->
            @video.play()

        pause: ->
            @video.pause()

    class VideoProcessor
        constructor: (target)->
            @subProcessor = null
            @target  = target
            @context = target.getContext '2d'
            @canvas  = document.createElement 'canvas'
            @canvas.context = @canvas.getContext '2d'
            @target.width  = @canvas.width  = PREVIEW_WIDTH
            @target.height = @canvas.height = PREVIEW_HEIGHT
            @prevProcess = 0

        init: (video)->
            $video = $(video)
            $video.on 'play' , => @play()
            $video.on 'pause', => @pause()
            $video.on 'timeupdate', =>
                $('#currentTime').val (video.currentTime / video.duration) * 10000
            [vw, vh] = [video.videoWidth, video.videoHeight]
            [cw, ch] = [@canvas.width   , @canvas.height   ]
            if vw > vh
                h = cw * (vh / vw)
                [@dx, @dy, @dw, @dh] = [0, (ch - h) * 0.5, cw, h]
            else
                w = ch * (vw / vh)
                [@dx, @dy, @dw, @dh] = [(cw - w) * 0.5, 0, w, ch]
            [@sx, @sy, @sw, @sh] = [0, 0, vw, vh]
            @canvas.context.clearRect 0, 0, cw, ch
            @video = video

        play: ->
            @isPaused = false
            requestAnimationFrame => @process()

        pause: ->
            @isPaused = true

        process: ->
            now = +new Date()
            if now - @prevProcess > 60
                @prevProcess = now
                @canvas.context.drawImage @video, @sx, @sy, @sw, @sh, @dx, @dy, @dw, @dh
                src = @canvas.toDataURL 'image/jpeg'

                if @subProcessor
                    binary = @subProcessor.videoProcess atob(src.replace /^.*,/, '')
                    src = ['data:image/jpeg;base64,'
                        btoa(binary.replace /[\u0100-\uffff]/g, (c)->
                            String.fromCharCode c.charCodeAt(0) & 0xff
                        )].join ''

                img = new Image
                img.onload = =>
                    @context.drawImage img, 0, 0
                img.src = src
            if not @isPaused then requestAnimationFrame => @process()

    class AudioProcessor
        constructor: (target)->
            @subProcessor = null
            @target  = target

            @stream = new Float32Array(1024)
            @isPlaying = false

        init: (video)->
            if @isPlaying then @pause()
            $video = $(video)
            $video.on 'play' , => @play()
            $video.on 'pause', => @pause()

            media = @target.createMediaElementSource video
            gain  = @target.createGainNode()
            gain.gain.value = 0.6

            node = @target.createJavaScriptNode 1024, 2, 2
            node.onaudioprocess = @process.bind @

            media.connect gain
            media.connect node

            [@node, @gain, @video] = [node, gain, video]

        play: ->
            @gain.connect @target.destination
            @node.connect @target.destination
            @isPlaying = true

        pause: ->
            @node.disconnect()
            @gain.disconnect()
            @isPlaying = false

        process: (e)->
            unless e then return
            stream = @stream

            L = e.inputBuffer.getChannelData 0
            R = e.inputBuffer.getChannelData 1
            for i in [0...L.length]
                stream[i] = (L[i] + R[i]) * 0.5

            if @subProcessor
                stream = @subProcessor.audioProcess stream

            L = e.outputBuffer.getChannelData 0
            R = e.outputBuffer.getChannelData 1
            for i in [0...L.length]
                L[i] = R[i] = stream[i]

    class GlitchProcessor
        constructor: ->
            @mode  = 0
            @level = 0.2

        videoProcess: do->
            i = 0
            randint   = (a, b)-> ((Math.random() * (b - a + 1)) + 1)|0
            randtable = new Uint8Array(randint(0, 9) for i in [0...4096])

            (src)->
                if @mode is 3
                    src.replace /0/ig, (c)->
                        String.fromCharCode 48 + randtable[i++ & 4095]
                else if Math.random() < 0.5
                    src.replace /0/ig, (c)->
                        if Math.random() < 0.02
                            String.fromCharCode 48 + randtable[i++ & 4095]
                        else c
                else src

        audioProcess: (stream)->
            if @mode is 0 and Math.random() < @level
                @mode = 1
            if @mode is 1
                @mode = 2
                @glitchbuffer = []
                @glitchbufferLength = ((Math.random() * 4)|0) + 1
            if @mode is 2
                @glitchbuffer.push new Float32Array(stream)
                if @glitchbuffer.length is @glitchbufferLength
                    @mode  = 3
                    @glitchindex = 0
                    @glitchindexMax = (((Math.random() * 18)|0) * 2) + 2
            if @mode is 3
                glitchbuffer = @glitchbuffer[@glitchindex % @glitchbufferLength]
                for i in [0...stream.length]
                    stream[i] = glitchbuffer[i]
                @glitchindex += 1
                if @glitchindex is @glitchindexMax
                    @mode = 4
            if @mode is 4
                @glitchindex -= 1
                if @glitchindex is 0
                    @mode = 0
            stream

    app = new App
    app.addProcessor new VideoProcessor(document.getElementById 'preview')
    app.addProcessor new AudioProcessor(new webkitAudioContext)
    app.addSubProcessor new GlitchProcessor()
