(function () {
  $(document).ready(function() {
    if (typeof(attempts_json) !== 'undefined') {
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
        var firstLetterToLocked =
          { 'A': true, 'C': true, 'I': true, 'G': true };
        var locked = firstLetterToLocked[task_id.charAt(0)] &&
          $div.hasClass('inline-task');
        html += "<div id='task-" + task_id + "-" + initials + "' class='" +
          class_ + "' data-status='" + attempt.status + "'" +
          " data-locked='" + locked + "'>" + "</div>";
      }
      $div.html(html);
    }

    var default_selected_attempt = $([]);
    var selected_attempt = $([]);
    var attempt_to_change = $([]);
    var status_to_explanation = {
      unstarted:  '(not started)',
      incomplete: '(in progress)',
      question:   '(stuck on something)',
      complete:   '(done)',
      locked:     '(must complete externally)'
    };
    var is_clicking_on_attempt = false;
    $('.attempt').mousedown(function(event) {
      attempt_to_change = $(event.target);
      is_clicking_on_attempt = true;
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
      $('#attempt-dropdown .explanation').text(
        status_to_explanation[old_status]);

      var locked = (attempt_to_change.attr('data-locked') == 'true');
      if (locked) {
        $('#attempt-dropdown .attempt.locked').show();
        $('#attempt-dropdown .attempt.complete').hide();
      } else {
        $('#attempt-dropdown .attempt.locked').hide();
        $('#attempt-dropdown .attempt.complete').show();
      }

      event.preventDefault();
    });
    $('#attempt-dropdown > .attempt').mouseover(function(event) {
      $(selected_attempt).removeClass('selected');
      selected_attempt = $(event.target);
      selected_attempt.addClass('selected');
      $('#attempt-dropdown .explanation').text(
        status_to_explanation[selected_attempt.attr('data-status')]);
    });
    $('#attempt-dropdown').mouseleave(function(event) {
      $(selected_attempt).removeClass('selected');
      selected_attempt = default_selected_attempt;
      $(selected_attempt).addClass('selected');
      $('#attempt-dropdown .explanation').text(
        status_to_explanation[default_selected_attempt.attr('data-status')]);
    });

    var change_attempt_status = function(attempt_to_change, new_status) {
      var old_status = attempt_to_change.attr('data-status');
      var taskTypeToLockExplanation = {
        'A': 'Instructor will take attendance; mark box as red speech bubble if you came in late and were overlooked.',
        'C': 'Challenges are considered complete when all test cases pass.',
        'I': 'This task can only be set complete by the instructor.',
        'G': 'To complete this challenge, get all tests passing from ruby run_tests.rb, then commit and push from GitX.'
      };
      if (new_status == 'locked') {
        var type = attempt_to_change.attr('id').split('-')[1].charAt(0);
        var message = taskTypeToLockExplanation[type];
        if (message) {
          window.alert(message);
        }
      } else if (new_status !== old_status) {
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
    };

    $(document).mouseup(function(event) {
      if (is_clicking_on_attempt) {
        $('#attempt-dropdown').hide();
        var new_status = selected_attempt.attr('data-status');
        change_attempt_status(attempt_to_change, new_status);
        is_clicking_on_attempt = false;
      }
    });

    var comet_io = new CometIO().connect();
    comet_io.on("refresh_all", function(params) {
      window.location.reload();
    });
    comet_io.on("update_attempt", function(params) {
      var attempt_id = params['attempt_id'];
      var new_status = params['new_status'];
      var $attempt = $('#' + attempt_id);
      var old_status = $attempt.attr('data-status');
      $attempt.removeClass(old_status);
      $attempt.addClass(new_status);
      $attempt.attr('data-status', new_status);
    });
    comet_io.on("move_highlight", function(params) {
      // it only makes sense to follow along if the user
      // is actually on the same page
      if (params['path'] == window.location.pathname.split('?')[0]) {
        $('.desc.current').removeClass('current');
        var newCurrentDesc = $('.desc').eq(params['num_desc']);
        newCurrentDesc.addClass('current');
        newCurrentDesc.scrollintoview();
      }
    });

    $('.desc a').click(function(event) {
      var attempt = $(event.target).closest('.desc').find('.attempt');
      if (attempt.attr('data-status') === 'unstarted') {
        change_attempt_status(attempt, 'incomplete');
      }
      return true;
    });

    $('.desc a.show-more').click(function(event) {
      var more = $(event.target).closest('.desc').find('.more');
      if (more.is(':hidden')) {
        more.show();
      } else {
        more.hide();
      }
      event.preventDefault();
      return false;
    });

    $('.desc a.github-challenge').click(function(event) {
      alert("To start this challenge:\n1. Start a Terminal window\n2. Run git pull to obtain the latest code\n3. cd to the exercise number\n4. Create a student_code.rb file.\n5. Run ruby run_tests.rb and see what the tests need to pass.")
      event.preventDefault();
      return false;
    });

    if ($('html.is-user-admin').length) {
      var numDescHighlighted = 0;
      var SEND_HIGHLIGHT_MOVE_DELAY_MILLIS = 1000;
      var sendHighlightMoveTimeoutID = null;
      var getCurrentTimeHHMM = function() {
        var date = new Date();
        return ((date.getHours() < 10) ? "0" : "") + date.getHours() + ":" +
               ((date.getMinutes() < 10) ? "0" : "") + date.getMinutes();
      };
      var sendHighlightMove = function(numDesc) {
        $.post("/move_highlight",
          {
            num_desc: numDescHighlighted,
            path: window.location.pathname.split('?')[0],
          },
          function(responseText) {
            var newCurrentDesc = $('.desc').eq(numDescHighlighted);
            if (newCurrentDesc.children(".highlight-time").length == 0) {
              newCurrentDesc.prepend(
                "<div class='highlight-time'>" + responseText + "</div>");
            }
          }
        );
      };
      var changeNumDescHighlighted = function(delta) {
        if (numDescHighlighted + delta >= 0) {
          $('.desc.current').removeClass('current');
          numDescHighlighted += delta;
          var newCurrentDesc = $('.desc').eq(numDescHighlighted);
          newCurrentDesc.addClass('current');
          newCurrentDesc.scrollintoview({ duration: 0 }); // instant
          window.clearTimeout(sendHighlightMoveTimeoutID);
          sendHighlightMoveTimeoutID = window.setTimeout(
            sendHighlightMove, SEND_HIGHLIGHT_MOVE_DELAY_MILLIS);
        }
      };
      changeNumDescHighlighted(0); // highlight current .desc

      var KEY_UP_KEY_CODE   = 38;
      var KEY_DOWN_KEY_CODE = 40;
      $(document).keydown(function(e){
        if (e.keyCode == KEY_UP_KEY_CODE) {
          changeNumDescHighlighted(-1);
          event.preventDefault();
          return false;
        } else if (e.keyCode == KEY_DOWN_KEY_CODE) {
          changeNumDescHighlighted(1);
          event.preventDefault();
          return false;
        } else {
          return true;
        }
      });
    }

    } // end if attempts_json defined
  }); // end document.ready
})();
