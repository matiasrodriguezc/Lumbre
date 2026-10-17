// Safari corre esto en la página antes de abrir la Share Extension (NSExtensionJavaScriptPreprocessingFile).
// Devuelve solo la URL, el título y el texto seleccionado: la extensión los trata como datos, nunca como instrucciones.
var GetPageInfo = function() {};

GetPageInfo.prototype = {
    run: function(parameters) {
        var selection = "";
        try {
            selection = window.getSelection ? String(window.getSelection()) : "";
        } catch (e) {
            selection = "";
        }
        parameters.completionFunction({
            "url": document.URL,
            "title": document.title,
            "selection": selection.substring(0, 5000)
        });
    },
    finalize: function(parameters) {}
};

var ExtensionPreprocessingJS = new GetPageInfo;
