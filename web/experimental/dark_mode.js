(function() {
    var params = new URLSearchParams(window.location.search);
    if (params.get('theme') == 'dark') {
        document.write(
            '<link rel="stylesheet" type="text/css" href="/packages/primer_css/primer_12.1.0_dark.css">' +
            '<link rel="stylesheet" type="text/css" href="styles.css">' +
            '<link rel="stylesheet" type="text/css" href="styles_dark.css">'
        );
    } else {
        document.write(
            '<link rel="stylesheet" type="text/css" href="/packages/primer_css/primer_12.1.0.css">' +
            '<link rel="stylesheet" type="text/css" href="styles.css">' +
            '<link rel="stylesheet" type="text/css" href="styles_light.css">'
        )
    }
})();
