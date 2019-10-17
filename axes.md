# How to model multidimensional signals

This is a proposal how we might describe multiple axes within a new HBK streaming protocol.

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

## Value Types

We use well known base value types like float, double, int32, uint32. In addition we might additional known value types that are combinations of those base value types.
There might be implicit knowledge about how to handle those known complex value types.

### Histogram (#Histogram)

This is an example of such a complex value type. It is used for statistics. It combines several base value types and includes knowledge about there meaning.

~~~~ {.javascript}
{
  "name": "counters",
  "valueType": "histogram",
  "unit": "dB",
  "histogram" : {
    "classes": {
      "count": 50.0,
      "delta": 1.0,
      "start": 50.0,
    },
    "haslowerCounter": true,
    "hashigherCounter": true,
    "hasTotalCounter": true,
  },
}
~~~~

#### Structure

- `histogram`: An object describing the gistogram
- `classes`: The distribution classes are desribed here. This equals very much the linear implicit axis rule!
- `classes/count`: Number of distributaion classes
- `classes/delta`: Width of each distribution class
- `classes/start`: First distribution class starts here
- `haslowerCounter`: Whether everything smaller then starts gets counted (Adds another uint64 to the data block)
- `hashigherCounter`: Whether everything bigger then the upper bound of the last class gets counted (Adds another uint64 to the data block)
- `hasTotalCounter`: Whether there is an overall counter (Adds another uint64 to the data block)

#### Implicit Knowledge

- `haslowerCounter`: Existence of this tells, that there is an additional uint64 counting value
- `hashigherCounter`: Existence of this tells, that there is an additional uint64 counting value
- `hasTotalCounter`: Existence of this tells, that there is an additional uint64 counting value





## Dimensions and Axes

We want to describe not only simple scalar values but more complex ones that are made up from several scalar values.

- Points in a 2 dimensional space are described by 2 scalar values. 
- A spectrum is made up of a number of points. They are an array of points.
- Statistics are contain a number of values that represent counters
- A family (swarm) of spectra is made up of an array of spectra.

In the first case, the components of each value are the dimensions in space.
In the latter cases, the components are not dimensions but have a specific meaning.


### Scalar value or Array of values

An axis of a measured value might hold a single scalar value (i.e. the measured strain at a point in time).
In other cases an axis might consist of an array values with a fixed number of elements (i.e. a spectum that contains several points over a frequency with an amplitude).


\pagebreak


## Implicit Axes

For implicit axes, the component of the value for this axes is described by specidic rules.
We use implicit axes rules to greatly reduce the amount of data to be transferred, stored and processed.

There are several kinds of rules. To calculate the absolute value on an implicit axis, the rule has to beapplied.

All axes are described by a signal specific meta information.



### Linear Axes (#Linear_Axes)
For equidistant axes we use linear axes.

Coordinates of linear axes are described by an absolute start value and
a relative delta between two values. 

![Equidistant 2 dimensional points](images/equidistant_points.png)

There are cases, where the axis is an array of values with fixed length (i.e. the frequency of a spectrum). 
Here we add a value count. Each array of values start with the start value.

A linear axis is described as follows:

~~~~ {.javascript}
{
  "axis" : {
    "axisType": "linear",
    "linear": {
      "start": <value>,
      "delta": <value>,
    },
    "unit": <unit object>,
    "name: <string>,
    "valueType": <string>
    "count": <unsigned integer>
  }
}
~~~~

- `axisType`: Type of axis rule
- `unit`: Unit of the axis (Out of scope of this document)
- `name`: Name of the dimension (i.e. voltage, sound level, time)
- `valueType`: Describes the data type of the dimension (i.e. a number format ("u8", "u32", "s32", "u64", "s64", "real32", "real64"), time (We talked about this in prior sessions), other known types)
- `value`: A value of the `valueType` of the axis.
- `start`: The absolute start value for the axis.
- `delta`: The difference between two values
- `count`: Optional: Number of values for arrays

\pagebreak

### Logarithmic Axes

~~~~ {.javascript}
{
    "axisType": "linear",
    "unit": <unit object>,
    "name: <string>,
    "valueType": <string>
    ...
}
~~~~

- `axisType`: Type of axis rule
- `unit`: Unit of the axis (Out of scope of this document)
- `name`: Name of the dimension (i.e. voltage, sound level, time)
- `valueType`: Describes the data type of the dimension (i.e. a number format ("u8", "u32", "s32", "u64", "s64", "real32", "real64"), time (We talked about this in prior sessions), other known types)


\pagebreak


## Explicit Axes
![Non equidistant 2 dimensional points](images/non_equidistant_points.png)

For explicit axes, each point has an absolute coordinate for this axis.
There is no rule how to calculate the absolute value on the axis.

~~~~ {.javascript}
{
    "axisType": "explicit",
    "unit": <unit object>,
    "name: <string>,
    "valueType": <string>
}
~~~~

- `axisType`: Type of axis rule
- `unit`: Unit of the axis (Out of scope of this document)
- `name`: Name of the dimension (i.e. voltage, sound level, time)
- `valueType`: Describes the data type of the dimension (i.e. a number format ("u8", "u32", "s32", "u64", "s64", "real32", "real64"), time (We talked about this in prior sessions), other known types)


\pagebreak


## Time 

One special axis/dimension is the time which is mandatory. The time is 
mandatory for each signal. It is not part of the signal value.
 It can be equidistant (linear implicit) or non-equidistant (explicit).


### Equidistant Time
Equidistant time axes are described as a [linear implicit axis](#CLinear_Axes).
To calculate the absolute time for an equidistant time, There needs to 
be an absolute start time and a delta time. 
Both can be delivered by a separate, signal specific, meta information. 

- The delta is mandatory.
- The absolute time always belongs to the next following value
- The device might deliver the absolute time before delivering the first value point.
- If the device does not possess a clock, there might be no absolute time at all.
- The device might deliver the absolute time whenever its clock is being set (resynchronization).



~~~~ {.javascript}
{
  "method": "time",
  "params": {
    "axisType": "linear",
    "linear": {
      "start": <value>,
      "delta": <value>,
    },
    "unit": <unit object>,
    "valueType": <string>,
}
~~~~

- `method`: Type of meta information
- `axisType`: type of axis
- `unit`: Unit of the axis
- `start`: The absolute timestamp for the next value point.
- `delta`: The time difference between two value points

### Non Equidistant Time
Time is delivered as absolute time stamp for each value.

~~~~ {.javascript}
{
  "method": "time",
  "params": {
    "axisType": "explicit",
    "unit": <unit object>,
    "valueType": "time"
  }
}
~~~~

- `method`: Type of meta information
- `axisType`: type of axis
- `unit`: Unit of the axis

\pagebreak




\pagebreak

## Describing Multiple Axes

This is an idea how to describe any value of the mentioned signals in one generic way.
As mentioned before everything has a time. In addition there is at least one value axis.

There is a signal-related meta information that describes all value axes of the signal:

~~~~ {.javascript}
{
  "method": "axes",
  "name" : <string>,
  "params" : {
      "<axes id>": {
        <an axis rule description>
      }
    }
  }
}
~~~~


- `params`: An array of objects each desribing a dimension.
- `value dimension id`: There is a fixed id for each value dimension of a signal.

### How to Interprete Measured Data

After the value dimension details were send, delivered measured data blocks are to be interpreted as follows:

- Each data block contains complete values. 
- A block may contain many values. They are arranged value by value.
- Only component values of explicit axes are send.
- Component value of implicit xaes are calculated following the axis rule.
- Theoretically a signal might contain implicit axes only. There won't be any component value to be transferred. All component values are to calculated using the axes rules.

\pagebreak


## Groups of Signals

There are cases were several signals are to be combined to a more complex group of signals (See [statistics example](#Statistics)).
Those groups are just describing signals that belong together.

To express the relation between the mentioned signals, the device will give a meta information about the grouping:

~~~~ {.javascript}
{
  "method": "signalGroups" {
    "params": {
      <signal group id>: {
        "name": "group_1"
        "signals": [ 
          < 1st signal id>,
          < 2nd signal id>,
          ...
        ],
      },
    },
  }
~~~~

- `<signal group id>`: A number with the groupt id, unique within the device
- `signals`: An arrays with the unique signal ids of all signals that belong to the group.



## Examples

### A Voltage Sensor

The signal has 1 value axis. Synchronous output rate is 100 Hz

- The voltage is on an explicit axis
- The device delivers scaled component value in 32 bit float format
- The time is equidistant (implicit).

The device sends the followin signal-specific meta information.


~~~~ {.javascript}
{
  "method": "axes",
  "params" : [
      "0": {
        "axisType": "explicit",
        "valueType": "float",
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
    "axisType": "linear",
    "linear": {
      "start": "high noon, 1st january 2019"
      "delta": "10 ms"
    },
    "valueType": "time"
  ]  
}
~~~~

Following data block has at least one value of this signal encoded float. No time stamps.

### A CAN Decoder

The signal has 1 value dimension. 

- The value is explicit.
- The time is explicit.

The device sends the following signal-specific meta information:

~~~~ {.javascript}
{
  "method": "axes",
  "params" : [
      "0": {
        "name": "decoded",
        "axisType": "explicit",       
        "valueType": "u32",
        "unit": "decoder unit",
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "axis": {
      "axisType": "explicit",
      "valueType": "time",
    }
  ]  
}
~~~~

Each value pint has an absolute time stamp and one u32 value.

### A Simple Counter

The signal has 1 value dimension

- The count value is equidistant with an increment of 2, it runs in one direction
- The device sends an initial absolute value.
- The time is non-equidistant.

~~~~ {.javascript}
{
  "method": "axes",
  "params" : [
      0: {
        "name": "count",
        "valueType": "u32",
        "axisType" : "linear",
        "linear": {
          "delta": 2
        },        
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "axisType": "explicit",
  ]  
}
~~~~


There is one axis with the counter value. This one is equidistant with a step width of 2.
We get no start value of the counter, hence we are starting with 0.

Data blocks will contain timestamps only. The counter changes by a known amount of 2.


### A incremental Rotary Incremental Encoder with start Position

The signal has 1 value dimension

- The counter representing the angle is equidistant, it can go back and forth
- Absolute start position when crossing a start position. 
- No initial absolute value.
- The time is non-equidistant.


~~~~ {.javascript}
{
  "method": "axes",
  "params" : [
      0: {
        "axisType": "linear",
        "linear": {
          "delta": 1,
        },
        "name": "counter",
        "valueType": "i32",
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "axisType": "explicit",
  ]  
}
~~~~



This is similar to the simple counter. Data blocks will contain timestamps only. 
The counter changes by a known amount of 2 only the time of the steps is variable.

We get a (partial) meta information with a start value of the counter every time when the zero index is being crossed:

~~~~ {.javascript}
{
  "method": "axes",
  "params" : [
    0: { 
      "start" : 0
    }
  ]  
}
~~~~

If the rotation direction changes, we get a (partial) meta information with a new delta.:

~~~~ {.javascript}
{
  "method": "axes",
  "params" : [
      0: {
        "delta": -1
      }
    ]
  }
}
~~~~


### An Absolute Rotary Incremental Encoder

The signal has 1 value dimension

- The angle is explicit, it can go back and forth
- The time is non-equidistant.

~~~~ {.javascript}
{
  "method": "axes",
  "params" : [
      0: {
        "axisType": "explicit",
        "name": "counter",
        "valueType": "i32",
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "axisType": "explicit",
  ]  
}
~~~~

Data block will contain a tuple of counter and time stamp. There will be no meta ionformation when direction changes.


### An Optical Spectrum (#Spectrum)

The signal has 2 axes. A spectrum consists of an array of value points

- One axis carries the Frequency which equidistant (implicit linear), it has an absolute start value of 100.
- The amplitude is non-equidistant (explicit)
- Every axis consists 1024 values.
- The time is non-equidistant. Each complete spectrum has one time stamp.

~~~~ {.javascript}
{
  "method": "valueDimensions",
  "params" : [
      "0": {      
        "name": "frequency",
        "valueType": "real32",
        "unit": "f",
        "axisType: "linear",
        "linear" : {
          "delta": 10,
          "start": 100
        }
        "count": 1024,
      },
      "1": {
        "name": "amplitude",
        "valueType": "real32",
        "unit": "db",  
        "axisType: "explicit",
        "count": 1024,      
      }
    ]
  }
}
~~~~


Data block will contain an absolute time stamp followed by 1024 frequency values. There will be no amplitude values because thy are implicit.


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
  "method": "valueDimensions",
  "params" : {
      "0": {
        "name": "frequency",
        "valueType": "real32",
        "unit": "Hz",
        "axisType": "CPB"
        "CPB" {
          "basesystem": 10,
          "firstband": 2,
          "numberfractions": 3,
        },
        "count" : 15	    
      },
      "1": {
        "axisType": "explicit"
        "name": "amplitude",
        "valueType": "real32",
        "unit": "db rel 20 uPa",
      }
    }
  }
}
~~~~

Data block will contain an absolute time stamp followed by 15 real32 with the amplitude information.



### Statistics (#Statistics)

Statistics consists of N "counters" each covering a value interval. If the measured value is within a counter interval, then that counter is incremented.
For instance the interval from 50 to 99 db might be covered by 50 counters. Each of these counters then would cover 1 dB.

Often there also is a lower than lowest and higher than highest counter, and for performance reasons, there might be a total counter.


Example: 50 - 99 dB statistics:
Number of counters: 53 (50 normal counters plus a lower, a higher and a total counter).

The complete statistics group contains four signals one carrying the 50 
normal counters and additional signals carrying the lower than counter, higher than counter and total counter


To express the relation between the mentioned signals, the device will give a meta information about the grouping:

~~~~ {.javascript}
{
  "method": "signalGroups" {
    "params": {
      <signal group id>: {
        "name": "statistic_1"
        "signals": [ 
          <signal id of counters signal>,
          <signal id of higher than counter>,
          <signal id of lower than counter>,
          <signal id of total counter>          
        ]
      }
    },
  }
~~~~

meta information for statistic counter signal

~~~~ {.javascript}
{
  "method": "axes",
  "params": {
      "0": {
        "axisType" : "linear",
          "delta" : 1,
          "start": 50,
        "linear" : {
        },
        "name": "statistics counters"
        "valueType": "u32",
        "unit": "dB",
        "count": 50
      },
    }
  }
}
~~~~

meta information for statistics higher than counter

~~~~ {.javascript}
{
  "method": "axes",
  "params" : {
      "0": {
        "name": "statistics higher than counter",
        "valueType": "u32",
        "unit": "dB",
      },
    }
  }
}
~~~~

meta information for statistics lower than counter

~~~~ {.javascript}
{
  "method": "axes",
  "params" : {
      "0": {
        "name": "statistics lower than counter",
        "valueType": "u32",
        "unit": "dB",
      },
    }
  }
}
~~~~

meta information for statistics total count

~~~~ {.javascript}
{
  "method": "axes",
  "params" : {
      "0": {
        "name": "statistics total count",
        "valueType": "u32",
        "unit": "dB",
      },
    }
  }
}
~~~~

There will be 4 separate data blocks that need to be aligned.

* 1 Data block will contain an absolute time stamp followed by 50 uint32 For the 50 counters.
* 3 Data blocks with an absolute timestamp and one u32 counter value.



### Statistics Alternative

This alternative describes the same as the [statistics example](#Statistics) but puts everything into one signal with several axes. There is no signal group.



~~~~ {.javascript}
{
  "method": "axes",
  "params": {
      "0": {
        "name": "statistics counters"
        "valueType": "u32",
        "unit": "dB",
        "count": 50
      },
      "1": {
        "name": "statistics higher than counter",
        "valueType": "u32",
        "unit": "dB",
      },
      "2": {
        "name": "statistics lower than counter",
        "valueType": "u32",
        "unit": "dB",
      },
      "3": {
        "name": "statistics total count",
        "valueType": "u32",
        "unit": "dB",
      },      
    }
  }
}
~~~~

Everything will be in 1 data block:

- 1 absolute time stamp.
- 50 uint32 for the 50 counters, 
- 1 uint32 for the higher than counter
- 1 uint32 for the lower than counter
- 1 uint32 for the total counter


### Statistics Alternative 2

This alternative describes the same as the [statistics example](#Statistics) but puts everything into a known [complex value type  histogram](#Histogram). there is only one axis and no signal group.

~~~~ {.javascript}
{
  "name": "counters",
  "valueType": "histogram",
  "unit": "dB",
  "histogram" : {
    "classes": {
      "count": 50.0,
      "delta": 1.0,
      "start": 50.0,
    },
    "haslowerCounter": true,
    "hashigherCounter": true,
    "hasTotalCounter": true,
  },
}
~~~~



Everything will be in 1 data block:

- 1 absolute time stamp.
- 50 uint32 for the 50 counters, 
- 1 uint32 for the higher than counter
- 1 uint32 for the lower than counter
- 1 uint32 for the total counter


### Position in 3 dimensional space Alternative

This is to be expressed by 3 signals values with one explicit axis.

To express the relation between the mentioned signals, the device will give a meta information about the grouping:

~~~~ {.javascript}
{
  "method": "signalGroups" {
    "params": {
      <signal group id>: {
        "name": "statistic_1"
        "signals": [ 
          <signal id of x signal>,
          <signal id of y signal>,
          <signal id of z signal>,
        ]
      }
    },
  }
~~~~


~~~~ {.javascript}
{
  "method": "axes",
  "params" : [
      "0": {
        "name": "x",
        "axisType": "explicit",       
        "valueType": "double",
        "unit": "m",
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "axes",
  "params" : [
      "0": {
        "name": "y",
        "axisType": "explicit",       
        "valueType": "double",
        "unit": "m",
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "axes",
  "params" : [
      "0": {
        "name": "z",
        "axisType": "explicit",       
        "valueType": "double",
        "unit": "m",
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "axis": {
      "axisType": "explicit",
      "valueType": "time",
    }
  ]  
}
~~~~

We receive 3 data blocks with one abolute time stamp and one double value.



### Position in 3 dimensional space Alternative

Same as above but as one signal with 3 explicit axes:



~~~~ {.javascript}
{
  "method": "axes",
  "params" : [
      "0": {
        "name": "x",
        "axisType": "explicit",       
        "valueType": "double",
        "unit": "m",
      }
      "1": {
        "name": "y",
        "axisType": "explicit",       
        "valueType": "double",
        "unit": "m",
      }
      "2": {
        "name": "z",
        "axisType": "explicit",       
        "valueType": "double",
        "unit": "m",
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "axis": {
      "axisType": "explicit",
      "valueType": "time",
    }
  ]  
}
~~~~

We receive 1 data block with one abolute time stamp and three double values.



### Spectral Statistics

Spectral statistics adds a dimension to the statistics example.
The first axis could for instance be a CPB axis, for each CPB band there is a statistics (which is 2 dimensions).



Example: 50 - 99 dB spectral statistics on a 1/3 octave CPB:


~~~~ {.javascript}
{
  "method": "signal",
  "params" : 
    {
      "endian": "little",
      "count": 15
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "axes",
  "params" : {
      "0": {
        "name": "frequency",
        "valueType": "u32",
        "unit": "Hz",
        "axisType": "CPB",
        "CPB": {
          "basesystem": 10,
          "firstband": 2,
          "numberfractions": 3,
        }
      },
      
      "1": {
        "name": "counters",
        "unit": "dB",
        "valueType": "histogram",
        "histogram" : {
          "classes": {
            "delta": 1.0,
            "start": 50.0,
            "count": 50.0
          },
          "haslowerCounter": true,
          "hashigherCounter": true,
          "hasTotalCounter": true
        },
      }
    }
  }
}
~~~~





Data block will contain a absolute time stamp followed by 795 (15 * 52) uint32.




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



