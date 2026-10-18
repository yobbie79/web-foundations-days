-- Day 6 Assignment: School Database
-- Web Foundations

-- 1. Create the students table
CREATE TABLE students (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
);

-- 2. Create the courses table
CREATE TABLE courses (
    id INTEGER PRIMARY KEY,
    course_name TEXT NOT NULL UNIQUE
);

-- 3. Create the enrolments table
CREATE TABLE enrolments (
    id INTEGER PRIMARY KEY,
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    grade TEXT,

    FOREIGN KEY (student_id)
        REFERENCES students(id)
        ON DELETE CASCADE,

    FOREIGN KEY (course_id)
        REFERENCES courses(id)
        ON DELETE CASCADE,

    UNIQUE (student_id, course_id)
);

-- 4. Insert sample students
INSERT INTO students (id, name, email) VALUES
(1, 'Amina Hassan', 'amina.hassan@example.com'),
(2, 'Brian Mutisya', 'brian.mutisya@example.com'),
(3, 'Wanjiku Mwangi', 'wanjiku.mwangi@example.com'),
(4, 'Kevin Otieno', 'kevin.otieno@example.com');

-- 5. Insert sample courses
INSERT INTO courses (id, course_name) VALUES
(1, 'Database Systems'),
(2, 'Web Development'),
(3, 'Computer Networks');

-- 6. Insert sample enrolments
INSERT INTO enrolments (id, student_id, course_id, grade) VALUES
(1, 1, 1, 'A'),
(2, 1, 2, 'B'),
(3, 2, 1, 'B'),
(4, 2, 3, 'A'),
(5, 3, 2, 'A');

-- 7. Query: All courses taken by one student, identified by name
SELECT courses.course_name
FROM students
JOIN enrolments ON enrolments.student_id = students.id
JOIN courses ON courses.id = enrolments.course_id
WHERE students.name = 'Amina Hassan';

-- 8. Query: All students enrolled in one course
SELECT students.name
FROM students
JOIN enrolments ON enrolments.student_id = students.id
JOIN courses ON courses.id = enrolments.course_id
WHERE courses.course_name = 'Database Systems';

-- 9. Query: Number of students enrolled in each course
SELECT
    courses.course_name,
    COUNT(enrolments.student_id) AS student_count
FROM courses
LEFT JOIN enrolments ON enrolments.course_id = courses.id
GROUP BY courses.id, courses.course_name;

-- 10. Query: Students who have no enrolments
SELECT students.name
FROM students
LEFT JOIN enrolments ON enrolments.student_id = students.id
WHERE enrolments.id IS NULL;

-- 11. Query: Update one enrolment's grade
UPDATE enrolments
SET grade = 'A'
WHERE student_id = 2
  AND course_id = 1;

-- 12. Display enrolments to verify the grade update
SELECT
    students.name,
    courses.course_name,
    enrolments.grade
FROM enrolments
JOIN students ON students.id = enrolments.student_id
JOIN courses ON courses.id = enrolments.course_id
ORDER BY students.name, courses.course_name;