# How to model multidimensional signals

This is a proposal how we might describe multiple dimensions within a new streaming protocol

## Points

Points have at least 2 dimensions. The coordinates of each dimension might be equidistant are not. 

### Time 

One special dimension is the time which is mandatory.

\pagebreak

## Non Equidistant Points
![Non equidistant 2 dimensional points](images/non_equidistant_points.png)




For non equidistant dimensions, each point has a absolute coordinate for this dimension

\pagebreak

## Equidistant Points
![Equidistant 2 dimensional points](images/equidistant_points.png)




For equidistant dimensions, coordinates of this dimension are described by a relative delta between two points and an absolute start
value for the next point. 

We use equidistant representation to greatly reduce the amount of data to be transferred, stored and processed.

\pagebreak


## Where HBM comes from

### Measured Data and Meta Information

HBM Streaming Protocol differentiates between meta information, and measured data.
The meta information describes a stream or signal and tells how to interprete the measured data of a signal.

#### Stream Specific Meta Information

Everything concerning the whole device or the stream. Examples:

* Endianness of the binary data transferred.
* Available Signals

#### Signal Specific Meta Information

Everything describing the signal. Examples:

* Signal name
* Signal unit information


### Shortcomings of HBM Streaming Protocol

The existing HBM Streaming Protocol emphasized on two dimensional signals. 
The first idea was a signal from a sensor that measures a quantity over time.
Then we recognized that there are synchronous and asynchronous signals. Synchronous signals deliver values with a fixed data rate.
Asynchronous signals deliver values at any time without a fixed rate (CAN bus).

After specifying the HBM Streaming Protocol we recognized, that limiting to 2 dimensions was short sighted. There are sensors that deliver more than two dimensions.
We had to add something to support anything that did not fit in our scheme. Those additions resulted in so called patterns. 
There are several patterns for representing the different kinds of signals.


\pagebreak

## Time

The time is mandatory for each signal. It can be equidistant or non-equidistant.

### Absolute Time

To calculate the absolute time for an equidistant time, There needs to be an absolute start value.
This can be delivered by a separate, signal specific, meta information. 

- The device might deliver the absolute time before delivering the first data point.
- The device might resend this whenever its clock is being set (resynchronization).
- If the device does not possess a clock, there might be no absolute time at all.

~~~~ {.javascript}
{
  "method": "absoluteTime",
  "params" : [
    "time": <time object>
  ]  
}
~~~~


\pagebreak

## Describing Multiple Value Dimensions

This is an idea how to describe any value of the mentioned signals in one generic way.
The second dimension carrying the values in the HBM streaming protocol is replaced with several value dimensions.

There is a meta information that describes all value dimensions of the signal (psuedo code).


~~~~ {.javascript}
{
  "method": "valueDimensions",
  "params" : [
      "<value dimension id>": {
        "name": <string>,
        "valueType": <string>,
        "unit": <unit object>,
        "delta": <value>
      }
    ]
  }
}
~~~~


- params: An array of objects each desribing a dimension.
- value dimension id: There is a fixed id for each value dimension of a signal.
- name: Name of the dimension (i.e. voltage, sound level, time)
- valueType: Describes the data type of the dimension (i.e. a number format ("u8", "u32", "s32", "u64", "s64", "real32", "real64"), time (We talked about this in prior sessions), other known types)
- unit: Unit of the dimension (Out of scope of this document)
- delta: (A value according to valueType) If this parameter does exist, the values of this dimension .
  are equidistant. There will be no absolute value for this dimesnsion in the delivered data blocks. 
  The absolute coordinate of the dimension has to be calculated using an absolute start value, 
  the delta and the number of points delivered.
  
  If this parameter is missing for a dimension, each delivered point in measured value data blocks will carry a absolute value for the dimension.
  
  The value might be negative. 0 is invalid!

### Dimension Specific Meta Information

There might be meta information that refers to a specific value dimension of a signal.
To do so the header of the meta information has to contain signal id (as in HBM Streaming Protocol) and dimension id.

\pagebreak

### Absolute Values

To calculate the absolute coordinate of equidistant value dimensions. There needs to be an absolute start value.
This can be delivered by a separate meta information. 

- The device might deliver the absolute coordinate before delivering the first data point.
- When using incremental encoders as signal source the absolute start value might be delivered when crossing the start position.
- Absolute value for the time might be resend if the device resynchronized.
- There might be no absolute corrdinate at all. As a result only a relative value can be acquired. In this case absolute start value is 0.

~~~~ {.javascript}
{
  "method": "absoluteValues",
  "params" : [
    "<dimension id>": <value according to valueType>
  ]  
}
~~~~

### Binary Representation

If we expect absolute values to be transferred often, it might be a good idea to transfer it in binary form to save bandwith.
It might also reduce processing time on the client.

HBM Streeaming Protocol does not specify meta information in binary form. This can easily added.



### How to Interprete Measured Data

After the value dimension details were send, delivered measured data blocks are to be interpreted as follows:

- Each data block contains complete points. 
- A block may contain many points. They are arranged point by point.
- Each point is a tuple with one value for every non-equidistant dimension
- Theoretically a signal might contain equidistant dimensions only. There won't be measured data to be transferred. We would deliver just data blocks without any data payload.

Coordinates of equidistant dimensions are calculated using the last absolute start values the delta and the number of points since then.
When there was no absolute start value yet the absolute start value is 0.

\pagebreak



## Simple and Composed Data

A measured value might be described completely by as single point (i.e. the measured strain at a point in time).
Other measured values consist of a sequence of several points (i.e. a spectum that contains several points over a frequency with a value).

To map a sequence of points that belong together, a signal might deliver an array of points.
The number of points in the array is expressed by a meta information of the signal.

\pagebreak

## Examples

### A Voltage Sensor

The signal has 2 dimensions

- The time is equidistant. The device sends an initial absolute value.
- The voltage is non-equidistant

Each point carries the absolute voltage only

### A CAN Decoder

- The time is non-equidistant.
- The value is non-equidistant

Each point carries absolute time and value

### A Simple Counter

The signal has 2 dimensions

- The time is non-equidistant.
- The count value is equidistant, it runs in one directions. The device sends an initial absolute value.

Each point delivers the absolute time only.

### A Rotary Incremental Encoder with start Position

The signal has 2 dimensions

- The time is non-equidistant.
- The angle is equidistant, it can go back and forth and gives an absolute start position when crossing a start position. No initial absolute value.

Each point delivers the absolute time stamp only
When changing the direction, delta meta information is resend for the angle dimension.

### An Optical Sprectrum

The signal has 3 dimensions

- The time is equidistant, there might be a absolute start when the frequency sweep begins.
- The Frequency is equidistant, there is an abolute start when the frequency sweep begins.
- The amplitude is non-equidistant

Each Point carries the absolute amplitude only


