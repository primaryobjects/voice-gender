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

    // Activate tooltips.
    $('body').tooltip({ selector: '[data-toggle=tooltip]' });

    // Setup form submit event.
    $('.submit').click(function() {
        $(this).css('cursor', 'wait');

        // Log event.
        ga('send', 'event', 'buy', $('#lstLicense').val(), 'click');

        $('#m_OrderForm').submit();
        
        return false;
    });

    $('#lstLicense').change(function() {
        // Log event.
        ga('send', 'event', 'license', $(this).val(), 'change');

        onLicense();
    });

    // Initialize intro text.
    var action = getUrlParameter('action');
    if (action == 'register') {
        $('.intro-text').addClass(action).text('Thank you for purchasing a license!');
        $('#license-div').hide();
    }

    // Page initialization.
    onLicense();
});

function onLicense() {
    var element = $('#lstLicense'); // Get select control.
    var selectedValue = element.val(); // Get selected value.
    var selectedText = element.find('option:selected').text() // Get selected text including price.
    var d = 0; // Get any discount.
    var price = selectedText.length ? (selectedText.match(/\$([0-9,.]+)/)[1] - d).toFixed(2) : 0; // Extract price value from text.
    var license = selectedText.length ? selectedText.match(/^([\w]+)/)[1] : ''; // Extract license name by first-word.
    var licenseName = 'Voice Gender App, ' + license; // Setup full license name.
    var code = 'VOICEGENDERAPP' + license.substr(0, 3).toUpperCase(); // Setup product code, using first 3 letters in license, upper-case (PER, BUS).
    
    // Update price, item number, and item name.
    $("#m_OrderForm input[name='amount']").val(price);
    $("#m_OrderForm input[name='a3']").val(price);
    $("#m_OrderForm input[name='item_number']").val(code);
    $("#m_OrderForm input[name='item_name']").val(licenseName);
}

function getUrlParameter(sParam) {
    var sPageURL = decodeURIComponent(window.location.search.substring(1)),
        sURLVariables = sPageURL.split('&'),
        sParameterName,
        i;

    for (i = 0; i < sURLVariables.length; i++) {
        sParameterName = sURLVariables[i].split('=');

        if (sParameterName[0] === sParam) {
            return sParameterName[1] === undefined ? true : sParameterName[1];
        }
    }
}