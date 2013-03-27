--drop table if exists tasks;

create table if not exists tasks (
  id integer primary key autoincrement,
  description varchar(250),
  order_in_assigned_at integer not null,
  assigned_at char(10),
  created_at timestamp,
  updated_at timestamp
);

--drop table if exists students;

create table if not exists students (
  id integer primary key autoincrement,
  first_name varchar(250),
  last_name varchar(250),
  initials char(2),
  created_at timestamp,
  updated_at timestamp
);

--drop table if exists attempts;

create table if not exists attempts (
  id integer primary key autoincrement,
  task_id integer not null,
  student_id integer not null,
  completed boolean not null,
  created_at timestamp,
  updated_at timestamp
);

insert into students (first_name, last_name, initials, created_at, updated_at)
  values ('Daniel', 'Stutzman', 'DS', date('now'), date('now'));
insert into students (first_name, last_name, initials, created_at, updated_at)
  values ('Ben', 'Stutzman', 'BS', date('now'), date('now'));
