// school_test_loop.js
function randomString(prefix) {
  return prefix + Math.floor(Math.random() * 1000);
}

while (true) {
  // Insert a class
  var classDoc = { name: randomString("Class"), subject: ["Math", "English", "History", "Physics"][Math.floor(Math.random()*4)] };
  db.classes.insertOne(classDoc);
  print("Inserted class:", tojson(classDoc));

  // Insert a student
  var studentDoc = { name: randomString("Student"), year: 2022 + Math.floor(Math.random() * 4), classId: classDoc._id };
  db.students.insertOne(studentDoc);
  print("Inserted student:", tojson(studentDoc));

  // Update a random student
  var s = db.students.findOne();
  if (s) {
    db.students.updateOne({ _id: s._id }, { $set: { year: s.year + 1 } });
    print("Updated student:", s.name);
  }

  // Delete a random class
  var c = db.classes.findOne();
  if (c) {
    db.students.deleteMany({ classId: c._id });
    db.classes.deleteOne({ _id: c._id });
    print("Deleted class:", c.name);
  }

  // Sleep for 2 seconds (simulate delay)
  sleep(2000);
}