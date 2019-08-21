# How to model multidimensional signals

This is a proposal how we might describe multiple dimensions within a new streaming protocol

## Points

Points have at least 2 dimensions. The coordinates of each dimension might be equidistant are not. 


## Non Equidistant Points
![Non equidistant 2 dimensional points](images/non_equidistant_points.png)




For non equidistant dimensions, each point has a absolute coordinate for this dimension


## Equidistant Points
![Equidistant 2 dimensional points](images/equidistant_points.png)




For equidistant dimensions, coordinates of this dimension are described by a relative delta between two points and an absolute start 
value for coordinate within the first point. 

We use equidistant representation to grealy reduce the amount of data to be transferred, stored and processed.


## Where HBM comes from

The existing HBM Streaming Protocol emphasized on two dimensional signals. 
The first idea was a signal from a sensor that measures a quantity over time.
Then we recognized that there are synchronous and asynchronous signals. Synchronous signals deliver values with a fixed data rate.
Asynchronous signals deliver values at any time without a fixed rate (CAN bus).

After specifying the HBM Streaming Protocol we recognized, that limiting to 2 dimensions was short sighted. There are sensors that deliver more than two dimensions.
We had to add something to support those.



## Describing Multiple Dimensions

This is an idea how to describe any of the mentioned signals in the future.

There is a meta information that describes all dimensions of the signal (psuedo code). 

~~~~ {.javascript}
{
  "method": "dimensions",
  "params" : [
      "<dimension id>": {
        "valueType": <string>,
        "unit": <unit object>,
        "delta": <value>
        "min" : <value>,
        "max" : <value>
      }
    ]
  }
}
~~~~


- params: An array of objects each desribing a dimension.
- dimension id: A fixed id or name of the dimension. By using this instead of an array of objects we easyily might resend partial meta information. There might also be following meta information that refer to that dimension id.
- valueType: Describes the data type of the dimension (i.e. a number format ("u32", "s32", "u64", "s64", "real32", "real64"), time (We talked about this in prior sessions), raw data)
- unit: Unit of the dimension (Out of scope of this document)
- delta: (A value according to valueType) If this parameter does exist, the values of this dimension 
  are equidistant. There will be no absolute value for this dimesnsion in the delivered data blocks. 
  The absolute coordinate of the dimension has to be calculated using an absolute start value, 
  the delta and the number of points delivered.
  
  If this parameter is missing for a dimension, each delivered point in measured value data blocks will carry a absolute value for the dimension.
  
  The value might be negative. 0 is invalid!
- min: (A value according to valueType) Optional parameter
- max: (A value according to valueType) Optional parameter

## Absolute Values

To calculate the abolute coordinate of the dimensions. There needs to be an absolute start value.
This will be delivered by a separate meta information. 

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

## How to Interprete Measured Data

After the dimension details were send, delivered measured data blocks are to be interpreted as follows:

- Each data block contains complete points
- Each point is a tuple with one value for every non-equidistant dimension
- Theoretically a signal might contain equidistant dimensions only. There won't be no measured data to be transferred. We would deliver just data blocks without any data payload.

Coordinates of equidistant dimensions are calculated using the last absolute start values the delta and the number of points since then.
When there was no absolute start value yet the absolute start value is 0.


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


