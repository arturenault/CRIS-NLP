var term_popover_template = '<div class="popover" role="tooltip"><div class="arrow"></div>'+
'<h3 class="popover-title"></h3><div class="popover-content"></div></div>'

var term_popover_title = "<button type='button' class='close'>&times;</button>" +
"<span class='popover-title-text'>Label this term</span>";

var term_popover_text = "<select class='label-options form-control'>"+
"<option>1</option>"+
"<option>2</option>"+
"<option>3</option>"+
"<option>4</option>"+
"<option>5</option>"+
"</select>"+
"<button type='button' class='reject-btn btn btn-danger'>Not a term?</button>"

var selected_popover_title = "<button type='button' class='close'>&times;</button>"+
"<span class='popover-title-text'>Should this be a term?</span>";

var selected_popover_text = "<select class='label-options form-control'>"+
"<option>1</option>"+
"<option>2</option>"+
"<option>3</option>"+
"<option>4</option>"+
"<option>5</option>"+
"</select>"+
"<button type='button' class='approve-btn btn btn-success'>Yes</button>";

var sentence_popover_template = "<div class='popover' role='tooltip'><div class='arrow'></div>" +
"<button type='button' class='btn submit btn-default'>Submit</div>"

$(".sentence").mouseup(function(e) {
    if( e.target === this) {
        var spans = $(this).children(".selected");
        var term = spans.first().justtext();
        spans.replaceWith(term);
        var selection = get_selected_text();
        if(selection.length >= 3) {
            var spn = "<span class='selected " +
            escape_spaces(selection) +
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

            $(".selected").on("shown.bs.popover", function () {
                $(".close").click(function() {
                    $(".selected").popover("hide");
                    $(".popover").remove();
                });

                $(".approve-btn").click(function() {
                    $(".selected").popover("hide");
                    var span = $(this).parent().parent().parent().parent().children(".selected");
                    span.removeClass("selected");
                    span.addClass("term");
                    $(".popover").remove();
                }); 
            });
        }
    }
});

$("body").on("change", ".label-options", function(e){
    if (e.target === this) {
        $(this).after("<select class='label-options form-control'>"+
            "<option>" + $(this).find("option:selected").text() + "</option>"+
            "<option>2</option>"+
            "<option>3</option>"+
            "<option>4</option>"+
            "<option>5</option>"+
            "</select>");
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

$(".sentence").not(".term, .selected, .popover").click(function() {
    window.currentSentence = event.target;
    $(window.currentSentence).popover("show");

    $(window.currentSentence).mouseleave( function() {
        setTimeout(function () {
            $('.sentence').popover('hide');
            $(".sentence").children(".popover").remove();
        }, 2000);
    });

    $(".submit").click(function() {
        var sentence = $(window.currentSentence);
        var json = sentence.into_json();
        var obj = JSON.parse(json);
        $.post("submit", obj, function(response) {
        });
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

$(".term").click(function(e) {
    if (e.target === this) {
        window.currentTerm = $(this);
        $(".term, .selected").not($(this)).popover("hide");
        $(".popover").remove();
        $(this).popover("show");
    }
})

$(".term").on("shown.bs.popover", function () {
    $(".close").click(function() {
        $(".term").popover("hide");
        $(".popover").remove();
    });

    $(".reject-btn").click(function() {
        var term = window.currentTerm.justtext();
        window.currentTerm.replaceWith(term);
        $(".term").popover("hide");
        $(".popover").remove();
    });

    $(".label-options").change(function(e){
        $(this).after("<select class='label-options form-control'>"+
            "<option>" + $(this).find("option:selected").text() + "</option>"+
            "<option>2</option>"+
            "<option>3</option>"+
            "<option>4</option>"+
            "<option>5</option>"+
            "</select>");
    });
});

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

function escape_spaces(string) {
    return replace_all(" ", "_", string);
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

        output += "{\"term\": \"" + term + "\", \"index\": " +
        index + ", \"length\": " + length + "}";
        if (!$(this).is(":nth-last-child(2)")) {
            output += ",";
        }
    });

    output += "]}";
    return output;
}