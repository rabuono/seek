var fetch_ajax_path;

function handleOntologyTermsJSONResponse(json) {
    $j.each(json, function(key,term){
        //make a new term
        addNewTermRow();

        //get the last row and its inputs
        var row = $j('table#new-terms tr.sample-cv-term').last();
        var inputs = $j(row).find('td input');

        //inputs 0,1,2 are label, iri, and parent_iri
        $j(inputs[0]).val(term.label);
        $j(inputs[1]).val(term.iri);
        $j(inputs[2]).val(term.parent_iri);
    });
}

function addNewTermRow() {
    var newTerm = $j('#new-term-row tbody').clone().html();

    var index = 0;
    $j('#new-terms tr.sample-cv-term').each(function () {
        var newIndex = parseInt($j(this).data('index'));
        if (newIndex > index) {
            index = newIndex;
        }
    });
    index++;

    newTerm = newTerm.replace(/--index--/g, index);
    $j('#add-term-button-row').before($j(newTerm));
}

function clearAllTerms() {
    $j('#new-terms tr.sample-cv-term input.destroy-attribute').each(function() {
        if (!$j(this).is(':checked')) {
            $j(this).attr('checked',true);
            $j(this).trigger('change');
        }
    });
}

function reportFetchError(json) {
    var error_message = json.errors[0].details;
    $j('div#fetch-error-message').text("An error occurred fetching the terms: "+error_message);
    $j('div#fetch-error-message').show();
}

function initialiseCVForm(fetch_ajax_path) {
    fetch_ajax_path = fetch_ajax_path;

    $j('#add-term').click(function () {
        addNewTermRow();

        //scroll to end
        $j('#controlled-vocab-terms-fixed').scrollTop($j('#controlled-vocab-terms-fixed').prop("scrollHeight"));

        return false;
    });

    $j('#clear-terms').click(function () {
       if (confirm('Are you sure you wish to remove all the current terms?')) {
           clearAllTerms();
       }
    });

    CVTerms = {
        removeTerm: function () {
            var row = $j(this).parents('.sample-cv-term');
            if ($j(this).is(':checked')) {
                if (row.hasClass('success')) { // If it is a new attribute, just delete from the form - doesn't exist yet.
                    row.remove();
                    //SampleTypes.recalculatePositions();
                } else {
                    row.addClass('danger');
                    // This selects all the fields in the row, except the magic "_destroy" checkbox and the hidden ID field
                    $j(':input:not(.destroy-attribute):not([type=hidden])', row).prop('disabled', true);
                }
            }
            else {
                row.removeClass('danger');
                $j(':input:not(.destroy-attribute)', row).prop('disabled', false);
            }
        }
    };

    $j('#new-terms').on('change', '.destroy-attribute', CVTerms.removeTerm);

    $j('select#sample_controlled_vocab_source_ontology').on('change', function() {
        var selected = this.selectedOptions[0];
        if (selected.value == "") {
            $j('#ontology-root-uri').hide();
        }
        else {
            $j('#ontology-root-uri').show();
            var link=$j('a#selected-ols-link');
            link.text(selected.text);
            link.attr('href','https://www.ebi.ac.uk/ols/ontologies/'+selected.value);
        }
    });

    $j('#fetch-ontology-terms-submit').click(function (e) {
        if (!confirm('Are you sure? All current terms will be removed.')) {
            return false;
        }
        $j('div#controlled-vocab-terms').hide();
        $j('div#fetch-error-message').hide();
        $j('#fetch-terms-spinner').spinner('add');
        $j('input#submit-button').prop('disabled',true);

        var ontology_id=$j('select#sample_controlled_vocab_source_ontology').val();
        var root_uri=$j('#sample_controlled_vocab_ols_root_term_uri').val();

        $j.ajax({ url: fetch_ajax_path,
            dataType: "json",
            data:{
                source_ontology_id: ontology_id,
                root_uri: root_uri
            },
            success: function (resp) {
                clearAllTerms();
                handleOntologyTermsJSONResponse((resp));
            },
            error: function (resp) {
                reportFetchError(resp.responseJSON);
            },
            complete: function () {
                $j('#fetch-terms-spinner').spinner('remove');
                $j('div#controlled-vocab-terms').show();
                $j('input#submit-button').prop('disabled',false);
                //scroll to end
                $j('#controlled-vocab-terms-fixed').scrollTop($j('#controlled-vocab-terms-fixed').prop("scrollHeight"));
            }
        })
        return false;
    });

    //make sure the page is updated if there is already an ontology
    $j('select#sample_controlled_vocab_source_ontology').trigger('change');
}