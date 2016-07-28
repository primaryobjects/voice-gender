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
});