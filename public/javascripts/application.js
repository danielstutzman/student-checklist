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
        var attempt = initials_to_attempt[initials] || {};
        var class_ = 'attempt ';
        class_ += attempt.completed ? 'completed ' : 'incomplete ';
        var x_or_not = attempt.completed ? 'X' : '-';
        html += "<div id='task-" + task_id + "-" + initials + "' class='" +
          class_ + "'>" + x_or_not + "</div>";
      }
      $div.html(html);
    }

    var default_selected_attempt = null;
    var selected_attempt = null;
    $('.task .attempt').mousedown(function(event) {
      var offset = $(event.target).offset();
      var shifted = { top: offset.top - 5, left: offset.left - 5 };
      $('#attempt-dropdown').show();
      $('#attempt-dropdown').offset(shifted);
      default_selected_attempt =
        $('#attempt-dropdown > .attempt.selected')[0];
      event.preventDefault();
    });
    $('#attempt-dropdown > .attempt').mouseover(function(event) {
      if (selected_attempt !== null) {
        $(selected_attempt).removeClass('selected');
      }
      $(event.target).addClass('selected');
      selected_attempt = event.target;
    });
    $('#attempt-dropdown > .attempt').mouseout(function(event) {
      if (selected_attempt !== null) {
        $(selected_attempt).removeClass('selected');
      }
      selected_attempt = default_selected_attempt;
      $(selected_attempt).addClass('selected');
    });
    $(document).mouseup(function(event) {
      $('#attempt-dropdown').hide();
      console.log(selected_attempt.getAttribute('data-type'));
    });
  }); // end ready
})();
