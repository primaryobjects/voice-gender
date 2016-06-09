$(document).ready(function() {
    $('#btnUrl').click(function() {
        $('#result1').hide();
        $('#result2').show();
    });

    $('#file1').click(function() {
        $('#result1').show();
        $('#result2').hide();       
    });
});