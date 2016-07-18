var AudioManager = {
    isRecording: false,
    audio_context: null,
    recorder: null,
    callback: null,
    media: null,

    start: function(callback) {
        if (!AudioManager.audio_context) {
            // Initialize a new audio context.
            try {
              // webkit shim
              window.AudioContext = window.AudioContext || window.webkitAudioContext;
              navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia;
              window.URL = window.URL || window.webkitURL;
              
              AudioManager.audio_context = new AudioContext;

              AudioManager.callback = callback;
            } catch (e) {
              alert('No web audio support in this browser!');
            }
            
            navigator.getUserMedia({audio: true}, AudioManager.startUserMedia, function(e) {
              console.log('No live audio input: ' + e);
            });
        }
        else {
            // Use existing audio context.
            AudioManager.clear();
            AudioManager.record();
        }
    },

    startUserMedia: function(stream) {
        var input = AudioManager.audio_context.createMediaStreamSource(stream);
        AudioManager.recorder = new Recorder(input);

        AudioManager.record();
    },

    record: function() {
        AudioManager.isRecording = true;
        AudioManager.recorder && AudioManager.recorder.record();

        if (AudioManager.callback) {
            AudioManager.callback();
        }
    },

    stop: function(callback) {
        AudioManager.isRecording = false;
        AudioManager.recorder && AudioManager.recorder.stop();

        AudioManager.recorder.exportWAV(callback);
    },

    clear: function() {
        AudioManager.recorder.clear();
    },

    play: function(callback) {
        AudioManager.recorder.getBuffer(function(buffers) {
            var newSource = AudioManager.audio_context.createBufferSource();
            var newBuffer = AudioManager.audio_context.createBuffer( 2, buffers[0].length, AudioManager.audio_context.sampleRate );
            newBuffer.getChannelData(0).set(buffers[0]);
            newBuffer.getChannelData(1).set(buffers[1]);
            newSource.buffer = newBuffer;

            newSource.connect( AudioManager.audio_context.destination );

            AudioManager.media = newSource;
            AudioManager.media.onended = callback;
            AudioManager.media.start(0);
        });
    },

    stopPlay: function() {
        if (AudioManager.media) {
            AudioManager.media.stop();
            AudioManager.media = null;
        }
    }
};