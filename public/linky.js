function update_tables(elem, def, callback) {
  select = $('#'+elem.id.replace('database', 'from'));
  spinner = $('#'+elem.id.replace('database', 'spinner'));
  database = $(elem).val();

  select.children().remove();
  if (database != "") {
    spinner.show();
    $.getJSON("/tables/"+database, function(data) {
      $('<option></option>').appendTo(select);
      $.each(data, function(i, name) {
        option = $('<option>'+name+'</option>')
        if (name == def) {
          option.attr('selected', true);
        }
        option.appendTo(select);
      });
      if (callback != undefined) {
        callback.call();
      }
      spinner.hide();
    });
  }
}

function update_columns(elem) {
  input = $('#'+elem.id.replace('from', 'columns'));
  spinner = $('#'+elem.id.replace('from', 'spinner'));
  database = $('#'+elem.id.replace('from', 'database')).val();
  table = $(elem).val();

  if (database != "" && table != "") {
    spinner.show();
    $.getJSON("/columns/"+database+"/"+table, function(data) {
      input.autocomplete(data, { multiple: true });
      spinner.hide();
    });
  }
  else {
    input.autocomplete([]);
  }
}

function update_records(which) {
  $('#query_spinner').show();
  $.ajax({
    type: 'GET',
    url: '/candidates/'+which,
    dataType: 'html',
    success: function(data) { set_results(data); }
  });
}

function set_results(data) {
  $('#results').html(data);
  $('#query_spinner').hide();
  $('#results .editable').editable(function(value) { update_records(value); }, { style: "inherit", width: '40' });
}
