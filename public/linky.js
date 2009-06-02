function update_tables(elem) {
  select = $('#'+elem.id.replace('database', 'from'));
  spinner = $('#'+elem.id.replace('database', 'spinner'));
  select.children().remove();
  database = $(elem).val();
  if (database != "") {
    spinner.show();
    $.getJSON("/tables/"+database, function(data) {
      $('<option></option>').appendTo(select);
      $.each(data, function(i, name) {
        $('<option>'+name+'</option>').appendTo(select);
      });
      spinner.hide();
    });
  }
}

function update_records(which) {
  $('#query_spinner').show();
  $.ajax({
    type: 'GET',
    url: '/candidates/'+which,
    dataType: 'html',
    success: function(data) {
      $('#results').html(data);
      $('#query_spinner').hide();
    }
  });
}

