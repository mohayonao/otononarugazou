$ ->
    'use strict'

    SAMPLERATE  = 8000
    IMAGE_SIZE  =  400

    gazou_id = location.pathname.substr(1)
    done = loadImage:false, loadAudio:false

    preview = document.createElement 'canvas'
    preview.width = preview.height = IMAGE_SIZE
    preview.context = preview.getContext '2d'
    preview.imageData = preview.context.createImageData IMAGE_SIZE, IMAGE_SIZE
    preview.elem = document.getElementById 'preview'

    if gazou_id
        img = new Image
        img.onload = ->
            drawImageWithImage img
        img.onerror = (e)->
            showAlert 'failed! 画像の読み込みに失敗しました。'
        img.src = "/#{gazou_id}.png"

    $.get '/list', (res)->
        $list = $('#gazou-list')
        res.forEach (id, i)->
            if i >= 12 then return
            $li  = $('<li>')
            $a   = $('<a>').attr href:"/#{id}"
            $img = $('<img>').attr src:"/#{id}.png"
            $list.append $li.append($a.append($img))

    # social-buttons
    social_url = "http://#{location.host}/#{gazou_id}"
    sb = $('#social-buttons')
    $('.hatena', sb).socialbutton 'hatena',
        button:"horizontal", url: social_url
    $('.twitter', sb).socialbutton 'twitter',
        button:'horizontal', lang:'en', url: social_url
    $('.google', sb).socialbutton 'google_plusone',
        size:'medium', lang:'ja', url: social_url
    $('.facebook', sb).socialbutton 'facebook_like',
        button:'button_count', url: social_url

    showAlert = (msg)->
        $('#alert').show('fast')
        $('#alert-message').text msg
    $('#alert-close').on 'click', ->
        $('#alert').hide('fast')

    if timbre?.env != 'webkit'
        showAlert 'Chromeで開いてください。'
        return

    timbre.workerpath = '/js/timbre.min.js'

    loadImage = (file)->
        done.loadImage = done.loadAudio = false
        reader = new FileReader
        reader.onload = ->
            img = new Image
            img.onload = ->
                drawImageWithImage img
            img.onerror = ->
                console.log '画像の読み込みに失敗しました。'
            img.src = reader.result
        reader.readAsDataURL file

    drawImageWithImage = (img)->
        canvas = document.createElement 'canvas'
        canvas.width = canvas.height = IMAGE_SIZE
        if img.width > img.height
            [x, y, size] = [(img.width - img.height) >> 1, 0, img.height]
        else
            [x, y, size] = [0, (img.height - img.width) >> 1, img.width ]
        canvas.context = canvas.getContext '2d'
        canvas.context.drawImage img, x, y, size, size, 0, 0, IMAGE_SIZE, IMAGE_SIZE
        imageData = canvas.context.getImageData 0, 0, IMAGE_SIZE, IMAGE_SIZE
        for i in [0...imageData.data.length]
            preview.imageData.data[i] = imageData.data[i]
        preview.context.putImageData preview.imageData, 0, 0
        preview.elem.src = preview.toDataURL()
        done.loadImage = true

    loadAudio = (file)->
        synth = loadAudio.synth = T('audio')
        synth.onloadeddata = ->
            $('#dialog-play').attr(disabled:false)
            $('#dialog-time').attr(disabled:false)
            $('#dialog-submit').attr(disabled:false)
            $('#dialog-title').text '再生位置を選択して下さい'
        synth.onerror = ->
            showAlert '音楽の読み込みに失敗しました。'
        synth.set(src:file).load()

        $('#dialog-time').val 0
        $('#dialog-time-label').text '0:00'
        $('#dialog-play').attr(disabled:true)
        $('#dialog-time').attr(disabled:true)
        $('#dialog-submit').attr(disabled:true)
        $('#dialog-title').text '読み込み中です...'
        $('#dialog').modal 'show'

    $('#dialog-time').on 'change', ->
        val = $(this).val()
        time = (loadAudio.synth.duration * (val / 1000))|0
        loadAudio.synth.startTime   = time
        loadAudio.synth.endTime     = time + (IMAGE_SIZE * IMAGE_SIZE / SAMPLERATE) * 1000
        loadAudio.synth.currentTime = time
        time = (time * 0.001)|0
        min  = (time / 60)|0
        sec  = ('00' + (time % 60)).substr -2
        $('#dialog-time-label').text "#{min}:#{sec}"

    dialogTimer = T('interval', ->
        if loadAudio.synth.currentTime >= loadAudio.synth.endTime
            $('#dialog-play').click()
    )
    $('#dialog-submit').on 'click', ->
        $('#dialog').modal 'hide'
        buffer = loadAudio.synth.slice loadAudio.synth.startTime, loadAudio.synth.endTime
        drawImageWithAudio buffer._.buffer

    $('#dialog-play').on 'click', ->
        if dialogTimer.isOff
            dialogTimer.on()
            $('i', this).removeClass('icon-play').addClass('icon-pause')
            loadAudio.synth.set(currentTime:loadAudio.synth.startTime).play()
        else
            dialogTimer.off()
            $('i', this).removeClass('icon-pause').addClass('icon-play')
            loadAudio.synth.pause()

    $('#dialog').on 'hidden', ->
        if dialogTimer.isOn then $('#dialog-play').click()

    drawImageWithAudio = (buffer)->
        buffer = stretch buffer
        buffer = new Uint16Array( (x + 1) * 32 for x in buffer )
        data   = preview.imageData.data
        for x, i in buffer
            i0 = (x >>  4) & 0x03
            i1 = (x >>  2) & 0x03
            i2 = (x >>  0) & 0x03
            data[i * 4 + 0] = (data[i * 4 + 0] & 0xfc) | i0
            data[i * 4 + 1] = (data[i * 4 + 1] & 0xfc) | i1
            data[i * 4 + 2] = (data[i * 4 + 2] & 0xfc) | i2
        preview.context.putImageData preview.imageData, 0, 0, 0, 0, IMAGE_SIZE, IMAGE_SIZE
        preview.elem.src = preview.toDataURL()
        done.loadAudio = true

    stretch = (wave)->
        dx  = SAMPLERATE / timbre.samplerate
        len = (wave.length * dx + 0.5)|0
        new Float32Array(
            for i in [0...IMAGE_SIZE * IMAGE_SIZE]
                i0 = (i / len) * wave.length
                i1 = i0 | 0
                dv = i0 - i1
                wave[i1] * (1.0 - dv) + (wave[i1 + 1] or 0) * dv
        )

    Acme = -> @bang()
    Acme.prototype = timbre.fn.buildPrototype Acme, {base:'ar-only'}

    Acme.prototype.bang = ->
        @sample = 0
        @index  = 0
        @value  = 0
        @
    Acme.prototype.seq = ->
        if @index >= IMAGE_SIZE * IMAGE_SIZE * 4 and @callback
            @callback()
        for i in [0...@cell.length]
            if @sample <= 0
                i0 = (preview.imageData.data[@index + 0] or 0) & 0x03
                i1 = (preview.imageData.data[@index + 1] or 0) & 0x03
                i2 = (preview.imageData.data[@index + 2] or 0) & 0x03
                value  = (i0 << 4) + (i1 << 2) + (i2 << 0)
                @value = ((value - 32) / 32) * 0.8
                @index  += 4
                @sample += 1
            @sample -= SAMPLERATE / timbre.samplerate
            @cell[i] = @value
        @cell
    timbre.fn.register "acme", Acme

    master = T('lpf', 3800)
    master.args[0] = T('acme')
    master.args[0].callback = ->
        master.pause()

    $('#play').on 'click', ->
        master.args[0].bang()
        master.play()
    $('#pause').on 'click', ->
        master.pause()

    isUploaded = false
    upload_url = null
    $('#upload').on 'click', ->
        if isUploaded
            return showAlert '処理中です。'
        if not done.loadImage
            return showAlert '画像ファイルを指定してください。'
        if not done.loadAudio
            return showAlert '音声ファイルを指定してください。'

        $(this).attr disabled:true
        $.get '/get_upload_url', (url)->
            upload_url = url
            $('#upload-dialog').modal 'show'

    $('#upload-dialog').on 'shown', ->
        if upload_url
            isUploaded = true
            data = preview.toDataURL 'image/png'
            data = atob(data.replace /^.*,/, '')
            data = new Uint8Array( x.charCodeAt(0) for x in data )
            blob = new Blob([data.buffer], {type:'image/png'})

            formData = new FormData
            formData.append 'file', blob

            $.ajax
                url:upload_url
                data:formData
                processData:false
                contentType:false
                type:'POST'
                success: (gazou_id)->
                    location.href = "/#{gazou_id}"
        upload_url = null

    $(window).on 'drop', (e)->
        file = e.originalEvent.dataTransfer.files[0]
        type = file.type.substr 0, 5
        switch type
            when 'audio' then loadAudio file
            when 'image' then loadImage file
            else showAlert 'よく分からないファイル形式です。'
        false
