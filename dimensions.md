# How to model multidimensional signals

This is a proposal how we might describe multiple dimensions within a new streaming protocol

## Points

Points have at least 2 dimensions. The coordinates of each dimension might be equidistant are not. 

### Time 

One special dimension is the time which is mandatory.

\pagebreak

## Non Equidistant Points
![Non equidistant 2 dimensional points](images/non_equidistant_points.png)

For non equidistant dimensions, each point has an absolute coordinate for this dimension

\pagebreak

## Equidistant Points
![Equidistant 2 dimensional points](images/equidistant_points.png)

For equidistant dimensions, coordinates of this dimension are described by an absolute start
value and a relative delta between two points and. 

We use equidistant representation to greatly reduce the amount of data to be transferred, stored and processed.

\pagebreak


## Where HBM comes from

### Measured Data and Meta Information

HBM Streaming Protocol differentiates between meta information, and measured data.
The meta information describes a stream or signal and tells how to interprete the measured data of a signal.

For both, there is a header telling the signal id, the data belongs to. If the data is related to the stream or device, the signal id is 0.

#### Stream Specific Meta Information

Everything concerning the whole device or the stream. Examples:

* Available Signals
* Device status information

#### Signal Specific Meta Information

Everything describing the signal. Examples:

* Endianness of the binary data transferred.
* Signal name
* Signal unit information


### Shortcomings of HBM Streaming Protocol

The existing HBM Streaming Protocol emphasized on two dimensional signals.
The first idea was a signal from a sensor that measures a quantity over time.
Then we recognized that there are synchronous and asynchronous signals. Synchronous signals deliver values with a fixed data rate.
Asynchronous signals deliver values at any time without a fixed rate (CAN bus).

After specifying the HBM Streaming Protocol we recognized, that limiting to 2 dimensions was short sighted. There are sensors that deliver more than two dimensions.

Furthermore there are signal types, like for example a spectrum, where one "value" is not just a single point but a collection of several points.

We had to add something to support anything that did not fit in original scheme. Those additions resulted in so called patterns. 
There are several patterns for representing the different kinds of signals.


\pagebreak

## Time

The time is mandatory for each signal. It can be equidistant or non-equidistant.


### Equidistant Time
To calculate the absolute time for an equidistant time, There needs to be an absolute start value and a delta time.
Both can be delivered by a separate, signal specific, meta information. 

- For a signal with values equidistant in time, the delta is mandatory.
- The absolute time always belongs to the next following value
- The device might deliver the absolute time before delivering the first value point.
- The device might deliver the absolute time whenever its clock is being set (resynchronization).
- If the device does not possess a clock, there might be no absolute time at all.



~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "absolute": <time object>
    "delta": <time object>
  ]  
}
~~~~

-`"absolute"`: The absolute timestamp for the next value point.
-`"delta"`: The time difference between two value points

### Non Equidistant Time
For a signal with values non-equidistant in time there is no meta information about time. 
Time is delivered always as absolute time stamp in each value point.

Signals with non-equidistant time deliver an absolute time with each value.

\pagebreak


## Simple Point or Series of Points

A measured value might be described completely as single point (i.e. the measured strain at a point in time).
Other measured values consist of a series of several points (i.e. a spectum that contains several points over a frequency with an amplitude).

To map a series of points that belong together, a signal might deliver an array of points.
The number of points in the array is expressed by a meta information of the signal.

Composed signals tell their array size in the meta information describing the signal.

The signal-related meta information looks like this:

~~~~ {.javascript}
{
  "method": "signal",
  "params" : 
    {
      "endian": <string>,
      "data": 
      {
    	"arraySize: <number>
      },
    }
  }
}
~~~~

- arraySize: Number of points in each value series of the signal



\pagebreak

## Describing Multiple Value Dimensions

This is an idea how to describe any value of the mentioned signals in one generic way.
The second dimension carrying the values in the HBM streaming protocol is replaced with a value that has several dimensions.

There is a signal-related meta information that describes all value dimensions of the signal:

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
- delta: (A value according to valueType) If this parameter does exist, the values of this dimension are equidistant. There will be no absolute value for this dimension in the delivered data blocks. 
  The absolute coordinate of the dimension has to be calculated using an absolute start value, 
  the delta and the number of points delivered. If this parameter is missing for a dimension, each delivered point in measured value data blocks will carry a absolute value for the dimension.  
  The delta might be negative. 0 is invalid!

### Dimension Specific Meta Information

There might be meta information that refers to a specific value dimension of a signal.
To do so the header of the meta information has to contain signal id (as in HBM Streaming Protocol) and dimension id.

\pagebreak

### Absolute Values

To calculate the absolute coordinate of equidistant value dimensions. There needs to be an absolute start value.
This can be delivered by a separate signal-related meta information. 

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




## Examples

### A Voltage Sensor

The signal has 1 value dimension. Synchronous output rate is 100 Hz

- The voltage is non-equidistant
- The device delivers scaled values in 32 bit float format
- The time is equidistant.

The device sends the folloinwgsignal-specific meta information.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : 
    {
      "endian": "little",
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "valueDimensions",
  "params" : [
      "0": {
        "name": "voltage",
        "valueType": "real32",
        "unit": "V",
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "absolute": "high noon, 1st january 2019"
    "delta": "10 ms"
  ]  
}
~~~~

Following data block has at least one value of this signal as little endian encoded float. No time stamps.

### A CAN Decoder

The signal has 1 value dimension. 

- The value is non-equidistant.
- The time is non-equidistant.

The device sends the following signal-specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params" : 
    {
      "endian": "little",
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "valueDimensions",
  "params" : [
      "0": {
        "name": "decoded",
        "valueType": "u32",
        "unit": "decoder unit",
      }
    ]
  }
}
~~~~

As you can see, there is no time meta information. This is because the time is not equidistant. 
Each value pint has an absolute time stamp and one u32 value, both little endian.

### A Simple Counter

The signal has 1 value dimension

- The count value is equidistant, it runs in one direction
- The device sends an initial absolute value.
- The time is non-equidistant.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : 
    {
      "endian": "little",
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "valueDimensions",
  "params" : [
      0: {
        "name": "count",
        "valueType": "u32",
        "delta": 2
      }
    ]
  }
}
~~~~

Again, there is no time meta information because the time is not equidistant. There is one value dimension with the counter value. This one is equidistant with a step width of 2.
We get a start value of the counter before the first values arrive:

~~~~ {.javascript}
{
  "method": "absoluteValues",
  "params" : [
    0: 0
  ]  
}
~~~~

Data blocks will contain timestamps only. The counter changes by a known amount of 2 only the time of the steps is variable.



### A Rotary Incremental Encoder with start Position

The signal has 1 value dimension

- The angle is equidistant, it can go back and forth
- Absolute start position when crossing a start position. 
- No initial absolute value.
- The time is non-equidistant.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : 
    {
      "endian": "little",
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "valueDimensions",
  "params" : [
      0: {
        "name": "counter",
        "valueType": "i32",
        "delta": 1
      }
    ]
  }
}
~~~~


This is similar to the simple counter. But the 
Again, there is no time meta information because the time is not equidistant. There is one value dimension with the counter value. This one is equidistant with a step width of 2.
Data blocks will contain timestamps only. The counter changes by a known amount of 2 only the time of the steps is variable.

We get a start value of the counter every time when the zero idex is being crossed:

~~~~ {.javascript}
{
  "method": "absoluteValues",
  "params" : [
    0: 0
  ]  
}
~~~~

If the rotation direction changes, we get a new delta. This happens through a partial meta information `valueDimension`:

~~~~ {.javascript}
{
  "method": "valueDimensions",
  "params" : [
      0: {
        "delta": -1
      }
    ]
  }
}
~~~~


### An Optical Spectrum

The signal has 2 value dimensions. A spectrum consists of an array of value points

- The Frequency is equidistant, there is an absolute start value when the frequency sweep begins.
- The amplitude is non-equidistant, hence each Point carries the absolute amplitude only
- Each spectrum consists 1024 points
- The time is non-equidistant. Each complete spectrum has one time stamp.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : 
    {
      "endian": "little",
      "array": 1024
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "valueDimensions",
  "params" : [
      "0": {
        "name": "frequency",
        "valueType": "real32",
        "unit": "f",
        "delta" : "10Hz"
      },
      "1": {
        "name": "amplitude",
        "valueType": "real32",
        "unit": "db",
      }
    ]
  }
}
~~~~

Before each spectrum arrives, we get a absolute start value for the equidistant frequency dimension:

~~~~ {.javascript}
{
  "method": "absoluteValues",
  "params" : [
    0: 100
  ]  
}
~~~~


Data block will contain a absolute time stamp followed by 1024 points withe one value because the 1st dimension is equidistant.



### CPB Spectrum

A CPB (Constant Percentage Bandwidth) spectrum is a logarithmic frequency spectrum where the actual bands are defined by a standard (not exactly logarithmic).
The spectrum is defined by the following values:

- Number of fractions per octave (e.g. 3)
- Id of the first band of the spectrum.
- The logarithmic base of the spectrum (2 or 10)
- Number of bands

The time is non-equidistant.
In this example the spectrum is 5 octaves with 3 fractions per octave, so 15 lines in total.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : 
    {
      "endian": "little",
      "array": 15
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "valueDimensions",
  "params" : {
      "0": {
        "name": "frequency",
        "valueType": "real32",
        "unit": "Hz",
        "indexmapping": "CPB",     (New: B&K calls this "indexmapping" (how does value map to index), could also be called axis type, or rule...)
        "cpb.basesystem": 10,      (New: Specific for CPB)
        "cpb.firstband": 2,   	   (New: Specific for CPB)
        "cpb.numberfractions": 3,  (New: Specific for CPB)
	"length": 15               (New: Matthias has this in the signal method, I would think it belongs here, so put it here as a suggestion)
      },
      "1": {
        "name": "amplitude",
        "valueType": "real32",
        "unit": "db rel 20 uPa",
      }
    }
  }
}
~~~~

Data block will contain an absolute time stamp followed by 15 real32.



### Statistics

Statistics consists of N "counters" each covering a value interval. If the measured value is within a counter interval, then that counter is incremented.
For instance the interval from 50 to 99 db might be covered by 50 counters. Each of these counters then would cover 1 dB.

Often there also is a lower than lowest and higher than highest counter, and for performance reasons, there might be a total counter.


Example: 50 - 99 dB statistics:
Number of counters: 53 (50 normal counters plus a lower, a higher and a total counter).


~~~~ {.javascript}
{
  "method": "signal",
  "params" : 
    {
      "endian": "little",
      "array": 780 (15*52)
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "valueDimensions",
  "params" : {
      "0": {
        "name": "amplitude",
        "valueType": "real32",
        "unit": "dB",
        "indexmapping": "Statistics",     (New: B&K calls this "indexmapping" (how does value map to index), could also be called axis type, or rule...)
        "statistics.lowercounter": true,  (New: Specific for statistics. Indicates whether the lower counter is there)
        "statistics.highercounter": true, (New: Specific for statistics. Indicates whether the higher counter is there)
        "statistics.totalcounter": true,  (New: Specific for statistics. Indicates whether the total counter is there)
        "statistics.firstcounter": 50.0,  (New: Specific for statistics. Indicates the start of the first counter)
        "statistics.counterwidth": 1.0,   (New: Specific for statistics. Indicates the with of all the counters)
	"length": 53                      (New: Includes the optional extra counters)
      },
      "1": {
        "name": "count",
        "valueType": "int32",
        "unit": "",
      }
    }
  }
}
~~~~


Data block will contain a absolute time stamp followed by 53 int32.



### SpectralStatistics

Spectral statistics adds a dimension to the statistics example.
The first axis could for instance be a CPB axis, for each CPB band there is a statistics (which is 2 dimensions).



Example: 50 - 99 dB spectral statistics on a 1/3 octave CPB:


~~~~ {.javascript}
{
  "method": "signal",
  "params" : 
    {
      "endian": "little",
      "array": 53
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "valueDimensions",
  "params" : {
      "0": {
        "name": "frequency",
        "valueType": "real32",
        "unit": "Hz",
        "indexmapping": "CPB",     (New: B&K calls this "indexmapping" (how does value map to index), could also be called axis type, or rule...)
        "cpb.basesystem": 10,      (New: Specific for CPB)
        "cpb.firstband": 2,   	   (New: Specific for CPB)
        "cpb.numberfractions": 3,  (New: Specific for CPB)
	"length": 15               (New: Matthias has this in the signal method, I would think it belongs here, so put it here as a suggestion)
      },
      "1": {
        "name": "amplitude",
        "valueType": "real32",
        "unit": "dB",
        "indexmapping": "Statistics",     (New: B&K calls this "indexmapping" (how does value map to index), could also be called axis type, or rule...)
        "statistics.lowercounter": true,  (New: Specific for statistics. Indicates whether the lower counter is there)
        "statistics.highercounter": true, (New: Specific for statistics. Indicates whether the higher counter is there)
        "statistics.totalcounter": false,  (New: Specific for statistics. Indicates whether the total counter is there)
        "statistics.firstcounter": 50.0,  (New: Specific for statistics. Indicates the start of the first counter)
        "statistics.counterwidth": 1.0,   (New: Specific for statistics. Indicates the with of all the counters)
	"length": 52                      (New: Includes the optional extra counters)
      },
      "2": {
        "name": "count",
        "valueType": "int32",
        "unit": ""
      }
    }
  }
}
~~~~


Data block will contain a absolute time stamp followed by 780 (15 * 52) int32.




### Harmonic Analysis

The result delivered from harmonic analysis done by HBM Genesis/Perception is fairly complex.
One combined value consists of the following :
- a scalar value distortion
- a scalar value fundamental frequency
- a two dimensional array with n arrays of points with frequency, FFT amplitude, FFT phase, where n is the number of dimensions


The approach to describe multiple dimensions described here does not work for this structure because:
- It expects that all dimensions have the same number of values (scalars and arrays, or more general arrays with different number of elements can not be used together).
- There are no sub dimensions (two dimensional array have dimensions within each dimension).

It would be possible to define a special `known type` that describes exatly this format (In this case n has to be constant). 
In this case it would be a signal with one dimension of this type. Streaming client has to have inmplcit kmowledge about the `known type`and how to handle it. 

The time would be non-equidistant. Each value point has on is time stamped and carries the absolute value.
