var term_popover_template = '<div class="popover" role="tooltip"><div class="arrow"></div>'+
'<h3 class="popover-title"></h3><div class="popover-content"></div></div>'

var term_popover_title = "<button type='button' class='close'>&times;</button>" +
"<span class='popover-title-text'>Label this term</span>";

var selected_popover_title = "<button type='button' class='close'>&times;</button>"+
"<span class='popover-title-text'>Should this be a term?</span>";

var term_popover_text = "<select class='label-options form-control'>";
var selected_popover_text = "<select class='label-options form-control'>";
var first_labels = ["AggregationState", "ChemicalComponent", "ConcentrationMeasure",
                    "Material", "MaterialRole", "PhaseComponent", "PhaseSystem", 
                    "Algorithm", "AlgorithmStep", "Assumption", "Expression", "Model",
                    "ModelImages", "Parameters", "Substitutions", "CoordinateSystem", 
                    "DimensionAxis", "Object", "Shape", "Equipment", "EquipmentParts",
                    "EquipmentSpecs", "EquipmentType", "OperatingParameters", "ProcessClass", 
                    "ProcessStep", "Processes", "Properties", "PropertyClass", "PropertyInstance", 
                    "RateConstant", "Reaction", "ReactionClass", "ReactionSet", "Address", 
                    "Affiliation", "Concepts", "Name","Person", "Sources", "Cyclic", "Substance", 
                    "SubstanceClass", "Dimension", "Value"];
for(var i = 0; i < first_labels.length; i++) {
    term_popover_text= term_popover_text + "<option>" + first_labels[i] + "</option>";
    selected_popover_text = selected_popover_text + "<option>" + first_labels[i] + "</option>";
}
term_popover_text+="</select> <button type='button' class='reject-btn btn btn-danger'>Yes</button>";
selected_popover_text+="</select> <button type='button' class='approve-btn btn btn-success'>Yes</button>";

var sentence_popover_template = "<div class='popover' role='tooltip'><div class='arrow'></div>" +
"<button type='button' class='btn submit btn-default'>Submit</div>"

$(".sentence").mouseup(function(e) {
    if( e.target === this) {
        var spans = $(".selected");
        var term = spans.first().justtext();
        spans.replaceWith(term);
        var selection = get_selected_text();
        if(selection.length >= 3) {
            var spn = "<span class='selected " +
            "' rel='popover' data-toggle='popover'>" +
            selection + "</span>"
            $(".term").popover("hide");
            $(".selected").popover("hide");
            $(this).html(replace_all(selection, spn, $(this).html()));
            $(this).find(".selected").popover({
                selector: "[rel=popover]",
                placement: "top",
                html: true,
                trigger: "manual",
                container: ".selected",
                title: selected_popover_title,
                content: selected_popover_text
            }).popover("show");
        }
    }
});

$("body").on("click", ".selected .close", function () {
    var spans = $(".selected");
    var term = spans.first().justtext();
    spans.replaceWith(term);
    $(".selected").popover("hide");
    $(".popover").remove();
});

$("body").on("click", ".term .close", function () {
    var span = $(this).parent().parent().parent();
    var label = $(this).parent().parent().find("option:selected").last().text();
    span.attr("label", label)
        .popover("hide");
    $(".popover").remove();
});

$(".sentence").on("click", ".approve-btn", function() {
    $(".selected").popover("hide");
    var sentence = $(this).parent().parent().parent().parent();
    var span = sentence.children(".selected");
    var label = $(this).parent().find("option:selected").last().text();
    span.popover("destroy")
        .removeClass("selected")
        .addClass("term")
        .attr("label", label);
    sentence.find(".term").popover({
        selector: "[rel=popover]",
        placement: "top",
        html: true,
        trigger: "manual",
        container: ".term",
        template: term_popover_template,
        title: term_popover_title,
        content: term_popover_text
    });
});

$("body").on("change", ".label-options", function(e){
    if (e.target === this) {
        $(this).nextAll(".label-options").remove();
        var select = $(this);
        $.get("/labels", {parent: $(this).find("option:selected").text()}, function(response) {
            var children = $.parseJSON(response);
            if (children.length > 0) {
                var next_label = "<select class='label-options form-control'>";
                for (var i = 0; i < children.length; i++) {
                    next_label = next_label + "<option>" + children[i] + "</option>";
                }
                next_label = next_label + "</select>";
                console.log(next_label);
                select.after(next_label);
            }
        });
    }
});

$(".sentence").popover({
    container: ".sentence",
    placement: "right",
    trigger: "manual",
    title: "send",
    delay: {hide: 2000},
    template: sentence_popover_template
});

$(".sentence").not(".term, .selected").click(function(e) {
    window.currentSentence = event.target;
    $(window.currentSentence).popover("show");

    $(window.currentSentence).mouseleave( function() {
        setTimeout(function () {
            $('.sentence').popover('hide');
            $(".sentence").children(".popover").remove();
        }, 2000);
    });
});

$("body").on("click", ".submit", function(e) {
    var sentence = $(this).parent().parent();
    $(".popover").remove();
    var json = sentence.into_json();
    $.post("submit", json, function(response) {
        console.log(response);
    });
});

$(".term").popover({
    selector: "[rel=popover]",
    placement: "top",
    html: true,
    trigger: "manual",
    container: ".term",
    template: term_popover_template,
    title: term_popover_title,
    content: term_popover_text
});

$(".sentence").on("click", ".term", function(e) {
    if (e.target === this) {
        window.currentTerm = $(this);
        $(".term, .selected").not($(this)).popover("hide");
        $(".popover").remove();
        $(this).popover("show");
    }
});

$("body").on("click", ".reject-btn", function() {
    var term = window.currentTerm.justtext();
    window.currentTerm.replaceWith(term);
    $(".term").popover("hide");
    $(".popover").remove();
})

function get_selected_text() {
    if(window.getSelection){
        return window.getSelection().toString();
    }
    else if(document.getSelection){
        return document.getSelection();
    }
    else if(document.selection){
        return document.selection.createRange().text;
    }
}

function escape_regexp(string) {
    return string.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, "\\$1");
}

function replace_all(find, replace, str) {
    return str.replace(new RegExp(escape_regexp(find), 'g'), replace);
}

jQuery.fn.justtext = function() {
    return $(this).clone()
    .children()
    .remove()
    .end()
    .text();
};

jQuery.fn.into_json = function() {
    var text = $(this).text().substring(0, $(this).text().length-7);
    var textArray = text.split(" ");
    var id = $(this).parent().parent().attr("id");
    var index = $(this).index();

    var output = "{ \"sentence\": \"" + text +
    "\", \"doc_id\": \"" + id + "\", \"index\": " +
    index + ", \"terms\": [";
    $(this).children("span").each(function() {
        var term = $(this).justtext();
        var index = textArray.indexOf(term.split(" ")[0]);
        var length = term.split(" ").length;
        var label = $(this).attr("label");

        output += "{\"term\": \"" + term + "\", \"index\": " +
        index + ", \"length\": " + length + ",\"label\": \"" + label + "\"}";
        if (!$(this).is(":nth-last-child(2)")) {
            output += ",";
        }
    });

    output += "]}";
    return output;
}