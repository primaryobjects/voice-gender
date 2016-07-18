$(document).ready(function() {
    $('#btnUrl').click(function() {
        if (typeof(ga) != 'undefined') {
            ga('send', 'event', 'btnUrl', 'click', $('#url').val());
        }
    });

    $('#file1').click(function() {
        if (typeof(ga) != 'undefined') {
            ga('send', 'event', 'file1', 'click');
        }
    });

    $('#btnRecord').click(function() {
        if (!AudioManager.isRecording) {
            AudioManager.start(function() {
                // Start recording from the microphone.
                $('#btnPlay').prop('disabled', true);
                $('#btnUrl').prop('disabled', true);
                $('#url').prop('disabled', true);
                $('#file1').prop('disabled', true);

                $('.fa-microphone').removeClass('fa-microphone').addClass('fa-stop').css('color', 'red');
            });
        }
        else {
            AudioManager.stop(function(audio) {
                // Stop recording and post the WAV to the server as base64 encoded data.
                $('#btnPlay').prop('disabled', false);
                $('#btnUrl').prop('disabled', false);
                $('#url').prop('disabled', false);
                $('#file1').prop('disabled', false);

                $('.fa-stop').removeClass('fa-stop').addClass('fa-microphone').css('color', 'black');

                // Encode the data and post to server.
                var reader = new FileReader();
                reader.readAsDataURL(audio);
                reader.onloadend = function() {
                    base64data = reader.result;

                    // Trigger the change event on the form field to activate the reactive field on the server.
                    $('#audio').val(base64data).change();
                    // Submit the form by triggering the click event on the button.
                    $('#btnProcessRecording').click();
                }
            });
        }
    });

    $('#btnPlay').click(function() {
        if (!AudioManager.media) {
            // Play the recorded data.
            $('.fa-play').removeClass('fa-play').addClass('fa-stop').css('color', '#00dd00');
            AudioManager.play(function() {
                // When the audio ends, change the icon.
                stopPlay();
            });
        }
        else {
            // If the user clicks stop, change the icon.
            stopPlay();
        }
    });

    // Hide the play button initially. Hide hidden form fields.
    $('#btnPlay').prop('disabled', true);
    $('#audio').hide();
    $('#btnProcessRecording').hide();
});

function stopPlay() {
    // Stop playing audio, update the icon.
    $('.fa-stop').removeClass('fa-stop').addClass('fa-play').css('color', 'black');
    AudioManager.stopPlay();            
}