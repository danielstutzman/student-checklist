(function () {
  $(document).ready(function() {
    var attempts = $.parseJSON(attempts_json);
    var all_initials = $.parseJSON(all_initials_json);
    var all_task_ids = $.parseJSON(all_task_ids_json);

    var hash = {};
    for (var i = 0; i < attempts.length; i++) {
      var attempt = attempts[i];

      if (hash[attempt.task_id] === undefined) {
        hash[attempt.task_id] = {};
      }
      if (hash[attempt.task_id][attempt.initials] === undefined) {
        hash[attempt.task_id][attempt.initials] = {};
      }
      hash[attempt.task_id][attempt.initials] = attempt;
    }
    var task_id_to_initials_to_attempt = hash;

    for (var i = 0; i < all_task_ids.length; i++) {
      var task_id = all_task_ids[i];
      var initials_to_attempt = task_id_to_initials_to_attempt[task_id] || {};

      var $div = $('#task-' + task_id);
      var html = '';
      for (var j = 0; j < all_initials.length; j++) {
        var initials = all_initials[j];
        var attempt = initials_to_attempt[initials] || { status: 'unstarted'};
        var class_ = 'attempt ' + attempt.status;
        html += "<div id='task-" + task_id + "-" + initials + "' class='" +
          class_ + "' data-status='" + attempt.status + "'>" + "</div>";
      }
      $div.html(html);
    }

    var default_selected_attempt = $([]);
    var selected_attempt = $([]);
    var attempt_to_change = $([]);
    $('.task > .attempt').mousedown(function(event) {
      attempt_to_change = $(event.target);
      var offset = attempt_to_change.offset();
      var shifted = { top: offset.top - 5, left: offset.left - 10 };
      $('#attempt-dropdown').show();
      $('#attempt-dropdown').offset(shifted);
      var old_status = attempt_to_change.attr('data-status');
      default_selected_attempt =
        $('#attempt-dropdown > .attempt[data-status="' + old_status + '"]');
      $('#attempt-dropdown > .attempt').removeClass('selected');
      selected_attempt = default_selected_attempt;
      selected_attempt.addClass('selected');
      event.preventDefault();
    });
    $('#attempt-dropdown > .attempt').mouseover(function(event) {
      $(selected_attempt).removeClass('selected');
      selected_attempt = $(event.target);
      selected_attempt.addClass('selected');
    });
    $('#attempt-dropdown').mouseleave(function(event) {
      $(selected_attempt).removeClass('selected');
      selected_attempt = default_selected_attempt;
      $(selected_attempt).addClass('selected');
    });
    $(document).mouseup(function(event) {
      $('#attempt-dropdown').hide();
      var old_status = default_selected_attempt.attr('data-status');
      var new_status = selected_attempt.attr('data-status');
      if (new_status !== old_status) {
        var post_data = {
          attempt_id: attempt_to_change.attr('id'),
          new_status: new_status
        };
        attempt_to_change.removeClass(old_status);
        attempt_to_change.addClass('updating');
        $.post('/update_attempt', post_data, function(data) {
          if (data == 'OK') {
            attempt_to_change.removeClass('updating');
            attempt_to_change.addClass(new_status);
            attempt_to_change.attr('data-status', new_status);
          }
        });
      }
    });
  }); // end ready
})();
