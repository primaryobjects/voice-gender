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

    $(document).keyup(function(event) {
        // Support enter key on url field.
        if ($("#url").is(":focus") && (event.keyCode === 13)) {
            $("#btnUrl").click();
        }
    });
});