--drop table if exists tasks;

create table if not exists tasks (
  id integer primary key autoincrement,
  description varchar(250),
  order_in_assigned_at integer not null,
  assigned_at char(10),
  created_at timestamp,
  updated_at timestamp
);

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

--drop table if exists attempts;

create table if not exists attempts (
  id integer primary key autoincrement,
  task_id integer not null,
  user_id integer not null,
  completed boolean not null,
  created_at timestamp,
  updated_at timestamp
);
