$(document).ready(function() {
    $('#btnUrl').click(function() {
        if (ga) {
            ga('send', 'event', 'btnUrl', 'click', $('#url').val());
        }
    });

    $('#file1').click(function() {
        if (ga) {
            ga('send', 'event', 'file1', 'click');
        }
    });
});