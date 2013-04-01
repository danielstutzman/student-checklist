(function () {
  $(document).ready(function() {
    var attempts = $.parseJSON(attempts_json);
    var all_initials = $.parseJSON(all_initials_json);

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

    for (task_id in task_id_to_initials_to_attempt) {
      var initials_to_attempt = task_id_to_initials_to_attempt[task_id];
      var $div = $('#task-' + task_id);
      var html = '';
      for (var i = 0; i < all_initials.length; i++) {
        var initials = all_initials[i];
        var attempt = initials_to_attempt[initials];
        if (attempt === undefined) {
          attempt = { 'completed' : false };
        }
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
