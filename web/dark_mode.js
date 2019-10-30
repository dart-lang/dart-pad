(function() {
    var params = new URLSearchParams(window.location.search);
    if (params.get('theme') == 'dark') {
        document.write(
            '<link rel="stylesheet" type="text/css" href="styles/embed/styles_dark.css">'
        );
    } else {
        document.write(
            '<link rel="stylesheet" type="text/css" href="styles/embed/styles_light.css">'
        )
    }
})();
