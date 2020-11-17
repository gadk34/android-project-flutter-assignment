# Exercise 1

1. The class that's used to implement the controller pattern is SnappingSheetController.
It allows the developer to control the position of the widget in the "grabbing" property
with the method snapToPosition which takes a SnapPosition as an argument and moves the
widget to this position.

2. a SnappingSheet instance has the property SnapPositions, which takes a list of SnapPosition instances.
Each one of those SnapPositions instances has a property called SnappingCurve which takes an enum from Curves
and controls how the snap would look like.

3. From viewing the libraries' documentations, it seems that an advantage of InkWell is that it excels in looks
and graphics with its support of splash effects, etc, while an advantage of GestureDetector is the wide variety of
gesture detections it supplies, which cover pretty much anything a user could do with their fingers on the screen.