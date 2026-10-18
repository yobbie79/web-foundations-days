# School Database Design

## Tables

### Students

The students table stores each student's ID, name, and email address. The ID is the primary key, while the email is unique so that two students cannot register using the same email address.

### Courses

The courses table stores the available courses. Each course has a unique ID and a course name. The ID is the primary key.

### Enrolments

The enrolments table records which students take which courses. It contains a student ID, a course ID, and a grade. The student ID and course ID are foreign keys referencing the students and courses tables. A unique constraint on these two columns prevents duplicate enrolments.

## Relationships

A student can enrol in several courses, making the relationship between students and courses many-to-many. A course can also have several students.

The enrolments table resolves this relationship by connecting each student to a course. It also stores the grade for that particular enrolment. Without this table, it would be difficult to represent the relationship without repeating information or storing multiple course IDs in one column.

Each student can have many enrolment records, and each course can have many enrolment records. These are one-to-many relationships between students and enrolments, and between courses and enrolments.

## Indexing

I would add an index on `enrolments(course_id)` because the system frequently retrieves students enrolled in a particular course and counts enrolments per course. The index can improve these queries as the number of enrolments grows. The unique constraint on `(student_id, course_id)` already creates an index that helps prevent duplicate enrolments.

Example:

```sql
CREATE INDEX idx_enrolments_course_id
ON enrolments(course_id);