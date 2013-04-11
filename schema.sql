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

--drop table if exists attempts;

create table if not exists attempts (
  id integer primary key autoincrement,
  task_id integer not null,
  user_id integer not null,
  status varchar(20) not null,
  created_at timestamp,
  updated_at timestamp
);
