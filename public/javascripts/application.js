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
  });
})();
