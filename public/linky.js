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

var status_check_id = null;
function check_worker_status() {
  $.getJSON('/status', function(data) {
    if (data.status == 'done') {
      clearInterval(status_check_id);
      update_records(data.first_id);
    }

    if (data.status == 'error') {
      clearInterval(status_check_id);
      $('#results').html(data.exception);
      $('#query_spinner').hide();
    }
  });
}

function wait_for_worker() {
  status_check_id = setInterval(check_worker_status, 1000);
}

function update_records(which) {
  if (typeof(which) == "undefined") {
    which = 'first';
  }

  $('#query_spinner').show();
  $.ajax({
    type: 'GET',
    url: '/candidates/'+which,
    dataType: 'html',
    success: function(data) {
      if (data == "working") {
        // wait for worker to finish
        wait_for_worker();
      }
      else {
        set_results(data);
      }
    }
  });
}

function set_results(data) {
  $('#results').html(data);
  $('#query_spinner').hide();
  $('#results .editable').editable(function(value) { update_records(value); }, { style: "inherit", width: '40' });
}
