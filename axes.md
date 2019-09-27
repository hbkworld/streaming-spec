# Points and Axes

Points have at least two axes or dimensions (Both mean the same here). One of which is the time.

## Explicit Axes

An Axis might be explicit. This means that there must be an absolute coordinate for this axis for every point.

## Implicit Axes

An Axis might be implicit. In this case, the absolute coordinate for this axis in each point follows a specific rule.

### Linear

There is a fixed value describing the difference on this axis between two points.
An absolute start value might be given at any time through an additional meta information.

`delta = 0.1`

`coordinate = startValue + delta * point_count_since_last_start`

coordinates:

P1: 0.0
P2: 0.1
P3: 0.2

startValue => 5

P4: 5.0
P5: 5.1

startValue => 10

P6: 10.0
P7: 10.1

### Other Function 

Does this depend on the point count or is there an additonal step parameter?
Examples (log(), ln())

`coordinate = startValue + function(point_count_since_Last_start)`
`coordinate = startValue + function(point_count_since_last_start, stop)



## Arrays of Points

For arrays of points, all axes used have the same number of coordinates.
An axs might be explicit or implicit.

## Start Value

As already stated above, a start value of an axis can by delivered at any time by a meat information.

### Array Start Value

A "measured value" simply conists of an array of points. There are cases an axis has the same start value for each array.
A spectrum is an example for those. Instead of deliviering a meta information with a start value for every array (spectrum).
We define an array start value for the axis.

