--drop table if exists users;

create table if not exists users (
  id                    integer primary key autoincrement,
  first_name            varchar(30),
  last_name             varchar(30),
  initials              char(2),
  google_plus_user_id   varchar(30),
  created_at            timestamp,
  updated_at            timestamp
);

insert into users (
  first_name,
  last_name,
  initials,
  google_plus_user_id,
  created_at,
  updated_at
) values (
  'Daniel',
  'Stutzman',
  'DS',
  '112826277336975923063',
  date('now'),
  date('now')
);

insert into users (
  first_name,
  last_name,
  initials,
  google_plus_user_id,
  created_at,
  updated_at
) values (
  'Ben',
  'Stutzman',
  'BS',
  '12345',
  date('now'),
  date('now')
);

--drop table if exists attempts;

create table if not exists attempts (
  id integer primary key autoincrement,
  task_id integer not null,
  user_id integer not null,
  completed boolean not null,
  created_at timestamp,
  updated_at timestamp
);

insert into attempts (
  task_id,
  user_id,
  completed,
  created_at,
  updated_at
) values (
  1,
  (select id from users where initials = 'DS'),
  't',
  date('now'),
  date('now')
);

insert into attempts (
  task_id,
  user_id,
  completed,
  created_at,
  updated_at
) values (
  1,
  (select id from users where initials = 'BS'),
  't',
  date('now'),
  date('now')
);
