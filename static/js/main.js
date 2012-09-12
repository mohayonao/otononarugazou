// Generated by CoffeeScript 1.3.3
(function() {

  $(function() {
    'use strict';

    var Acme, IMAGE_SIZE, SAMPLERATE, dialogTimer, done, drawImageWithAudio, drawImageWithImage, gazou_id, img, isMobile, isUploaded, loadAudio, loadImage, master, preview, sb, showAlert, social_url, stretch, upload_url;
    SAMPLERATE = 8000;
    IMAGE_SIZE = 400;
    gazou_id = location.pathname.substr(1);
    done = {
      loadImage: false,
      loadAudio: false
    };
    showAlert = function(msg) {
      $('#alert').show('fast');
      return $('#alert-message').text(msg);
    };
    $('#alert-close').on('click', function() {
      return $('#alert').hide('fast');
    });
    preview = document.createElement('canvas');
    preview.width = preview.height = IMAGE_SIZE;
    preview.context = preview.getContext('2d');
    preview.imageData = preview.context.createImageData(IMAGE_SIZE, IMAGE_SIZE);
    preview.elem = document.getElementById('preview');
    drawImageWithImage = function(img) {
      var size, x, y, _ref, _ref1;
      if (img.width > img.height) {
        _ref = [(img.width - img.height) >> 1, 0, img.height], x = _ref[0], y = _ref[1], size = _ref[2];
      } else {
        _ref1 = [0, (img.height - img.width) >> 1, img.width], x = _ref1[0], y = _ref1[1], size = _ref1[2];
      }
      preview.context.drawImage(img, x, y, size, size, 0, 0, IMAGE_SIZE, IMAGE_SIZE);
      preview.imageData = preview.context.getImageData(0, 0, IMAGE_SIZE, IMAGE_SIZE);
      preview.elem.src = preview.toDataURL();
      return done.loadImage = true;
    };
    if (gazou_id) {
      img = new Image;
      img.onload = function() {
        return drawImageWithImage(img);
      };
      img.onerror = function(e) {
        return showAlert('画像の読み込みに失敗しました。');
      };
      img.src = "/" + gazou_id + ".png";
    }
    isMobile = (function() {
      var ua;
      ua = navigator.userAgent;
      return ['iPhone', 'Android', 'iPad', 'iPod'].some(function(x) {
        return ua.indexOf(x) !== -1;
      });
    })();
    if (isMobile) {
      return $('#desc-for-mobile').show();
    }
    loadImage = function(file) {
      var reader;
      done.loadImage = done.loadAudio = false;
      reader = new FileReader;
      reader.onload = function() {
        img = new Image;
        img.onload = function() {
          return drawImageWithImage(img);
        };
        img.onerror = function() {
          return console.log('画像の読み込みに失敗しました。');
        };
        return img.src = reader.result;
      };
      return reader.readAsDataURL(file);
    };
    $.get('/list', function(list) {
      var $list, fetch;
      $list = $('#gazou-list');
      fetch = function() {
        var $a, $li, id;
        id = list.shift();
        if (!id) {
          return;
        }
        $li = $('<li>');
        $a = $('<a>').attr({
          href: "/" + id
        });
        img = new Image;
        img.onload = fetch;
        img.src = "/" + id + ".png";
        return $list.append($li.append($a.append(img)));
      };
      return fetch();
    });
    social_url = "http://" + location.host + "/" + gazou_id;
    sb = $('#social-buttons');
    $('.hatena', sb).socialbutton('hatena', {
      button: "horizontal",
      url: social_url
    });
    $('.twitter', sb).socialbutton('twitter', {
      button: 'horizontal',
      lang: 'en',
      url: social_url
    });
    $('.google', sb).socialbutton('google_plusone', {
      size: 'medium',
      lang: 'ja',
      url: social_url
    });
    $('.facebook', sb).socialbutton('facebook_like', {
      button: 'button_count',
      url: social_url
    });
    $(window).on('dragover', function(e) {
      return false;
    });
    $(window).on('drop', function(e) {
      var file, type;
      file = e.originalEvent.dataTransfer.files[0];
      type = file.type.substr(0, 5);
      switch (type) {
        case 'image':
          loadImage(file);
          break;
        case 'audio':
          if ((typeof timbre !== "undefined" && timbre !== null ? timbre.env : void 0) === 'webkit') {
            loadAudio(file);
          } else {
            showAlert('音声ファイルは Chrome でのみ扱えます。');
          }
          break;
        default:
          showAlert('よく分からないファイル形式です。');
      }
      return false;
    });
    if (!(typeof timbre !== "undefined" && timbre !== null ? timbre.isEnabled : void 0)) {
      return $('#desc-for-nosound').show();
    }
    timbre.workerpath = '/js/timbre.min.js';
    Acme = function() {
      return this.bang();
    };
    Acme.prototype = timbre.fn.buildPrototype(Acme, {
      base: 'ar-only'
    });
    Acme.prototype.bang = function() {
      this.sample = 0;
      this.index = 0;
      this.value = 0;
      return this;
    };
    Acme.prototype.seq = function() {
      var i, i0, i1, i2, value, _i, _ref;
      if (this.index >= IMAGE_SIZE * IMAGE_SIZE * 4 && this.callback) {
        this.callback();
      }
      for (i = _i = 0, _ref = this.cell.length; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
        if (this.sample <= 0) {
          i0 = (preview.imageData.data[this.index + 0] || 0) & 0x03;
          i1 = (preview.imageData.data[this.index + 1] || 0) & 0x03;
          i2 = (preview.imageData.data[this.index + 2] || 0) & 0x03;
          value = (i0 << 4) + (i1 << 2) + (i2 << 0);
          this.value = ((value - 32) / 32) * 0.8;
          this.index += 4;
          this.sample += 1;
        }
        this.sample -= SAMPLERATE / timbre.samplerate;
        this.cell[i] = this.value;
      }
      return this.cell;
    };
    timbre.fn.register('acme', Acme);
    master = T('lpf', 3800);
    master.args[0] = T('acme');
    master.args[0].callback = function() {
      return master.pause();
    };
    $('#play').on('click', function() {
      master.args[0].bang();
      return master.play();
    });
    $('#pause').on('click', function() {
      return master.pause();
    });
    if ((typeof timbre !== "undefined" && timbre !== null ? timbre.env : void 0) !== 'webkit') {
      return $('#desc-for-moz').show();
    }
    $('#desc-for-webkit').show();
    $('#upload').show();
    loadAudio = function(file) {
      var synth;
      synth = loadAudio.synth = T('audio');
      synth.onloadeddata = function() {
        $('#dialog-play').attr({
          disabled: false
        });
        $('#dialog-time').attr({
          disabled: false
        });
        $('#dialog-submit').attr({
          disabled: false
        });
        return $('#dialog-title').text('再生位置を選択して下さい');
      };
      synth.onerror = function() {
        return showAlert('音楽の読み込みに失敗しました。');
      };
      synth.set({
        src: file
      }).load();
      $('#dialog-time').val(0);
      $('#dialog-time-label').text('0:00');
      $('#dialog-play').attr({
        disabled: true
      });
      $('#dialog-time').attr({
        disabled: true
      });
      $('#dialog-submit').attr({
        disabled: true
      });
      $('#dialog-title').text('読み込み中です...');
      return $('#dialog').modal('show');
    };
    $('#dialog-time').on('change', function() {
      var min, sec, time, val;
      val = $(this).val();
      time = (loadAudio.synth.duration * (val / 1000)) | 0;
      loadAudio.synth.startTime = time;
      loadAudio.synth.endTime = time + (IMAGE_SIZE * IMAGE_SIZE / SAMPLERATE) * 1000;
      loadAudio.synth.currentTime = time;
      time = (time * 0.001) | 0;
      min = (time / 60) | 0;
      sec = ('00' + (time % 60)).substr(-2);
      return $('#dialog-time-label').text("" + min + ":" + sec);
    });
    dialogTimer = T('interval', function() {
      if (loadAudio.synth.currentTime >= loadAudio.synth.endTime) {
        return $('#dialog-play').click();
      }
    });
    $('#dialog-submit').on('click', function() {
      var buffer;
      $('#dialog').modal('hide');
      buffer = loadAudio.synth.slice(loadAudio.synth.startTime, loadAudio.synth.endTime);
      return drawImageWithAudio(buffer._.buffer);
    });
    $('#dialog-play').on('click', function() {
      if (dialogTimer.isOff) {
        dialogTimer.on();
        $('i', this).removeClass('icon-play').addClass('icon-pause');
        return loadAudio.synth.set({
          currentTime: loadAudio.synth.startTime
        }).play();
      } else {
        dialogTimer.off();
        $('i', this).removeClass('icon-pause').addClass('icon-play');
        return loadAudio.synth.pause();
      }
    });
    $('#dialog').on('hidden', function() {
      if (dialogTimer.isOn) {
        return $('#dialog-play').click();
      }
    });
    drawImageWithAudio = function(buffer) {
      var data, i, i0, i1, i2, x, _i, _len;
      buffer = stretch(buffer);
      buffer = new Uint16Array((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = buffer.length; _i < _len; _i++) {
          x = buffer[_i];
          _results.push((x + 1) * 32);
        }
        return _results;
      })());
      data = preview.imageData.data;
      for (i = _i = 0, _len = buffer.length; _i < _len; i = ++_i) {
        x = buffer[i];
        i0 = (x >> 4) & 0x03;
        i1 = (x >> 2) & 0x03;
        i2 = (x >> 0) & 0x03;
        data[i * 4 + 0] = (data[i * 4 + 0] & 0xfc) | i0;
        data[i * 4 + 1] = (data[i * 4 + 1] & 0xfc) | i1;
        data[i * 4 + 2] = (data[i * 4 + 2] & 0xfc) | i2;
      }
      preview.context.putImageData(preview.imageData, 0, 0, 0, 0, IMAGE_SIZE, IMAGE_SIZE);
      preview.elem.src = preview.toDataURL();
      return done.loadAudio = true;
    };
    stretch = function(wave) {
      var dv, dx, i, i0, i1, len;
      dx = SAMPLERATE / timbre.samplerate;
      len = (wave.length * dx + 0.5) | 0;
      return new Float32Array((function() {
        var _i, _ref, _results;
        _results = [];
        for (i = _i = 0, _ref = IMAGE_SIZE * IMAGE_SIZE; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
          i0 = (i / len) * wave.length;
          i1 = i0 | 0;
          dv = i0 - i1;
          _results.push(wave[i1] * (1.0 - dv) + (wave[i1 + 1] || 0) * dv);
        }
        return _results;
      })());
    };
    isUploaded = false;
    upload_url = null;
    $('#upload').on('click', function() {
      if (isUploaded) {
        return showAlert('処理中です。');
      }
      if (!done.loadImage) {
        return showAlert('画像ファイルを指定してください。');
      }
      if (!done.loadAudio) {
        return showAlert('音声ファイルを指定してください。');
      }
      $(this).attr({
        disabled: true
      });
      return $.get('/get_upload_url', function(url) {
        upload_url = url;
        return $('#upload-dialog').modal('show');
      });
    });
    return $('#upload-dialog').on('shown', function() {
      var blob, data, formData, x;
      if (upload_url) {
        isUploaded = true;
        data = preview.toDataURL('image/png');
        data = atob(data.replace(/^.*,/, ''));
        data = new Uint8Array((function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = data.length; _i < _len; _i++) {
            x = data[_i];
            _results.push(x.charCodeAt(0));
          }
          return _results;
        })());
        blob = new Blob([data.buffer], {
          type: 'image/png'
        });
        formData = new FormData;
        formData.append('file', blob);
        $.ajax({
          url: upload_url,
          data: formData,
          processData: false,
          contentType: false,
          type: 'POST',
          success: function(gazou_id) {
            return location.href = "/" + gazou_id;
          }
        });
      }
      return upload_url = null;
    });
  });

}).call(this);
