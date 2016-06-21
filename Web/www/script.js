$(document).ready(function() {
    $('#btnUrl').click(function() {
    	ga('send', 'event', 'btnUrl', 'click', $('#url').val());
    });

    $('#file1').click(function() {
    	ga('send', 'event', 'file1', 'click');
    });
});