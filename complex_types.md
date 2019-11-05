# How to Model Complex Signals

This is a proposal how we might describe signals of any complexity.

## Where HBM comes from

### Measured Data and Meta Information

HBM Streaming Protocol differentiates between meta information and measured data.
The meta information describes a stream or signal and tells how to interprete the measured data of a signal.

For both there is a header telling the signal id the data belongs to. If the data is related to the stream or device the signal id is 0.
In addition, this header contains length information. If the content is not understood, 
the parser can step to the next header and proceed with processing. This is usefull if the stream contains information, the client is not aware of.

For more details please see the HBM Streaming Protocol specification.

#### Stream Specific Meta Information

Everything concerning the whole device or the stream. Examples:

* Available Signals
* Device status information

#### Signal Specific Meta Information

Everything describing the signal. Examples:

* Endianness of the binary data transferred.
* Signal name
* Signal unit information

### Examples
#### A Voltage Sensor

Synchronous output rate is 100 Hz. Signal is scaled on the device and is delivered as float.

The following signal related meta information will be send before delivering any measured data:

~~~~ {.javascript}
{
  "method": "data",
  "params" : {
    "pattern": "V",
    "endian": "little",
    "valueType": "real32",
  }
}
~~~~

- `pattern`="V": No timestamps, values only. This pattern is used only for synchronous values.

Signal related, after subscribing a synchronous signal there will be an absolute time for the first measured value we deliver for this signal.

~~~~ {.javascript}
{
  "method": "time",
  "params": {
    "stamp": <absolute time stamp of first value>
  }
}
~~~~

The following signal related meta information tells the time difference between two values.

~~~~ {.javascript}
{
  "method": "signalRate",
  "params": {
    "delta": <10ms time difference>
  }
}
~~~~


Data block has the measured value of this signal as 4 byte float. No time stamps.

#### A CAN Decoder

This is a signal that is asynchronous in time. There will be no time and signal rate meta information.

~~~~ {.javascript}
{
  "method": "data",
  "params" : {
    "pattern": "TV",
    "endian": "little",
    "valueType": "u32",
  }
}
~~~~

- `pattern`="TV": One timestamp per value, first comes the timestamp, then the value. This pattern is used for asynrchonous values.


Each value point has an absolute time stamp and one u32 value.

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

We use well known base value types like float, double, int32, uint32. In addition we might have known value types that are combinations of those base value types.
There might be implicit knowledge about how to handle those known complex value types. If one is not able to handle a type, the underlying length information can be used to skip the package.

### Array

An array of values of the same type. The number of elements is fixed.

~~~~ {.javascript}
{
  "valueTpe": "array",
  "array" : {
    "count" : <unsigned int>
    "valueType" : <string>,
  }
}
~~~~

- `array/count`: Number of elements in the array


### Struct

A combination of named members which may be of different Types.

~~~~ {.javascript}
{
  "valueTpe": "struct",
  "struct": {
    { 
      <member name 1> : { < value description 1> },
      ...
      <member name n> : { < value description n> }
    }
  }
}
~~~~

- `<member name 1>...<member name n>`: Each struct member has a name. 

### Spectrum

Spectral values over a spectral range. The axis with the spectral range follows an implicit rule

~~~~ {.javascript}
{
  "name": "spectrum name"
  "valueTpe": "spectrum",
  "spectrum" : {
    "value" : {
      "valueType" : "double",
      "unit" : <unit object>
    },
    "range" : {
      "valueType" : "double",
      "unit" : <unit object>,
      "implicitRule" : "linear",
      "linear" : {
		"delta": 10.0,
		"start" : 1000.0
      }
    },
    "count" : 100
  }  
}
~~~~

- `spectrum`: An object describing a spectrum
- `value`: Describing the spectral values
- `range`: Describing the spectral range
- `count`: Number of points in the spectrum


### Histogram {#Histogram}

This is an example of such a complex value type. It is used for statistics.

~~~~ {.javascript}
{
  "name": "histogram name"
  "valueType": "histogram",
  "histogram": {
    "classes": {
      "valueType": "uint64",
      "implicitRule" : "linear",
      "linear" : {
		"delta": 1.0,
		"start": 50.0
	  }
      "count": 50,
    },
  },
}
~~~~

- `histogram`: An object describing the histogram
- `classes`: The distribution classes are desribed here. This equals very much the linear implicit axis rule!
- `classes/valueType`: Type of counter
- `classes/count`: Number of distributaion classes
- `classes/implicitRule`: This histogram follows an implicit linear rule. Other rules are also possible.
- `classes/linear/delta`: Width of each distribution class
- `classes/linear/start`: First distribution class starts here



\pagebreak


## Implicit Rules

A value might follow a specific rule. We do not need to transfer each value, just some start information and the rule to calculate any other value that follows.
We use implicit rules to greatly reduce the amount of data to be transferred, stored and processed.

There are several kinds of rules. To calculate the absolute value , the rule has to be applied.

All implicit rules are described by a signal specific meta information.


### Linear Rule {#Linear_Rule}
For equidistant value we use the linear rule.

It is described by an absolute start value and a relative delta between two neighboring values. 

![Equidistant 2 dimensional points](images/equidistant_points.png)

There are cases, where the axis is an array of values with fixed length (i.e. the frequency of a spectrum). 
Here we add a value count. Each array of values start with the start value.

A linear axis is described as follows:

~~~~ {.javascript}
{
  "implicitRule": "linear",
  "linear": {
    "start": <value>,
    "delta": <value>,
  },
}
~~~~

- `implicitRule`: Type of implicit rule
- `linear`: Properties of the implicit linear rule
- `linear/start`: the first value
- `linear/delta`: The difference between two values


### constant Rule
The rule is simple: There is a start value. The value equals the start value until a new start value is posted.

~~~~ {.javascript}
{
  "implicitRule": "constant",
  "constant": {
    "start": <value>,
  },
}
~~~~

\pagebreak

### cpb Rule


~~~~ {.javascript}
{
  "ruleType": "cpb"
  "cpb" {
    "basesystem": 10,
    "firstband": 2,
    "numberfractions": 3
  }
}
~~~~

- `ruleType`: Type of implicit rule
- `cpb`: Details for the rule of type cpb
- `cpb/basesystem` : logarithm base
- `cpb/firstband` : first band of the spectrum
- `cpb/numberfractions` : Number of fractions per octave



\pagebreak


## Explicit Rule
![2 dimensional points](images/non_equidistant_points.png)

When there is no implicit rule defined, each value has an absolute coordinate for this axis.
There is no rule how to calculate the absolute value. We call it an explicit rule.

\pagebreak


## Time 

The time is mandatory for each signal. It is not part of the signal value.
It can follow an implicit rule (most likely equidistant or linear) or may be explicit.


### Linear Time
Equidistant time is described as a [linear implicit rule](#Linear_Rule).
To calculate the absolute time for linear time, There needs to 
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
    "ruleType": "linear",
    "linear": {
      "start": <value>,
      "delta": <value>,
    },
    "unit": <unit object>,
    "valueType": <string>,
}
~~~~

- `method`: Type of meta information
- `ruleType`: type of axis
- `unit`: Unit of the axis
- `linear/start`: The absolute timestamp for the next value point.
- `linear/delta`: The time difference between two value points

### Explicit Time
Time is delivered as absolute time stamp for each value.

~~~~ {.javascript}
{
  "method": "time",
  "params": {
    "ruleType": "explicit",
    "unit": <unit object>,
    "valueType": "time"
  }
}
~~~~

- `method`: Type of meta information

\pagebreak




\pagebreak


### How to Interprete Measured Data

After the meta information describing the signal is, delivered measured data blocks are to be interpreted as follows:

- See whether this is more meta information or measured data from a signal.
- Each data block contains complete values of a signal. 
- A block may contain many values of this signal. They are arranged value by value.
- Only explicit values are send.
- Values following an implicit rule are calculated according the implicit rule.
- Theoretically a signal might contain no explicit avlue ast all. There won't be any component value to be transferred. All component values are to calculated using the implicit rules.

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

The signal has 1 scalar value. Synchronous output rate is 100 Hz

- The voltage is expressed as a base value type
- The device delivers scaled component value in 32 bit float format
- The time is linear.

The device sends the following signal-specific meta information.


~~~~ {.javascript}
{
  "method": "signal",
  "params" : [
      "ruleType": "explicit",
      "valueType": "float",
      "unit": "V",
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "ruleType": "linear",
    "linear": {
      "start": "high noon, 1st january 2019"
      "delta": "10 ms"
    },
    "valueType": "time"
  ]  
}
~~~~

Data block has the value of this signal encoded float. No time stamps.

### A CAN Decoder

The signal has a simple scalar value.

- The value is expressed as a base value type
- The value is explicit.
- The time is explicit.

The device sends the following signal-specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params" : [
      "name": "decoded",
      "ruleType": "explicit",       
      "valueType": "u32",
      "unit": "decoder unit"
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "ruleType": "explicit",
    "valueType": "time"
  ]  
}
~~~~

Each value point has an absolute time stamp and one u32 value.

### A Simple Counter

This is for counting events that happens at any time (explicit rule).

- The value is expressed as a base value type
- The count value is linear with an increment of 2, it runs in one direction
- The device sends an initial absolute value.
- The time is explicit.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : [
      "name": "count",
      "valueType": "u32",
      "ruleType" : "linear",
      "linear": {
        "delta": 2
      }     
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "ruleType": "explicit",
  ]  
}
~~~~


Value is linear with a step width of 2.
We get no start value of the value, hence we are starting with 0.

Data blocks will contain timestamps only. The counter changes by a known amount of 2.


### A incremental Rotary Incremental Encoder with start Position

- The value is expressed as a base value type
- The counter representing the angle follows a linear rule, it can go back and forth
- Absolute start position when crossing a start position. 
- No initial absolute value.
- The time is explicit.


~~~~ {.javascript}
{
  "method": "signal",
  "params" : [
      "ruleType": "linear",
      "linear": {
        "delta": 1,
      },
      "name": "counter",
      "valueType": "i32",
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "ruleType": "explicit",
  ]  
}
~~~~



This is similar to the simple counter. Data blocks will contain timestamps only. 
The counter changes by a known amount of 2 only the time of the steps is variable.

We get a (partial) meta information with a start value of the counter every time when the zero index is being crossed:

~~~~ {.javascript}
{
  "method": "signal",
  "params" : [
    "linear" : {
      "start" : 0
    }
  ]  
}
~~~~

If the rotation direction changes, we get a (partial) meta information with a new delta for the linear rule:

~~~~ {.javascript}
{
  "method": "signal",
  "params" : [
      0: {
        "linear" : {
          "delta": -1
        }      
      }
    ]
  }
}
~~~~


### An Absolute Rotary Incremental Encoder

- The value is expressed as a base value type
- The angle is explicit, it can go back and forth
- The time is explicit.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : [
      "ruleType": "explicit",
      "name": "counter",
      "valueType": "i32",
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : [
    "ruleType": "explicit",
  ]  
}
~~~~

Data block will contain a tuple of counter and time stamp. There will be no meta ionformation when direction changes.


### An Optical Spectrum {#Optical_Spectrum}

The signal consists of a spectum

- The value is complex value type of type spectrum. This carries:
	* Frequency which is implicit linear, it has an absolute start value of 100.
	* Amplitude which is explicit
- The time is explicit. Each complete spectrum has one time stamp.

Meta information describing the signal:

~~~~ {.javascript}
{
  "valueTpe": "spectrum",
  "spectrum" : {
    "value" : {
      "valueType" : "double",
      "unit" : "db"
    },
    "range" : {
      "valueType" : "double",
      "unit" : "f",
      "implicitRule" : "linear",
      "linear" : {
        "delta": 10.0,
        "start" : 100.0
      }
    },
    "count" : 1024
  }  
}
~~~~



Data block will contain an absolute time stamp followed by 1024 amplitude double values. There will be no frequency values because they are implicit.

### An Optical Spectrum with Peak Values

The signal consists of a spectum and the peak values. Number of peaks is fixed 16. 
If the number of peaks does change, there will be a meta information telling about the new amount of peaks!

Meta information describing the signal:

~~~~ {.javascript}
{
  "valueType" : "struct",
  "struct" : {
    "the spectrum" : {
      "valueType": "spectrum",
      "spectrum" : {
        "value" : {
          "valueType" : "double",
          "unit" : "db"
        },
        "range" : {
          "valueType" : "double",
          "unit" : "f",
          "implicitRule" : "linear",
          "linear" : {
	        "delta": 10.0,
	        "start" : 100.0
          }
        },
        "count" : 1024
      }  
    },
    "the peak values" : {
      "valueType" : "array",
      "array" : {
        "count" : 16,
        "valueType" : "struct",
        "struct" {
          "frequency" : {          
            "valueType" : "double"
            "unit" : "f",
          },
          "amplitude" : {          
            "valueType" : "double"
            "unit" : "db"
          }
        }
      }      
    }
  }  
}
~~~~

Data block will contain:

- 1 absolute time stamp 
- 1024 spectrum amplitude double values. No spectrum frequncy values because those are implicit.
- 16 amplitude, frequency pairs.


### CPB Spectrum

A CPB (Constant Percentage Bandwidth) spectrum is a logarithmic frequency spectrum where the actual bands are defined by a standard (not exactly logarithmic).
The spectrum is defined by the following values:

- Number of fractions per octave (e.g. 3)
- Id of the first band of the spectrum.
- The logarithmic base of the spectrum (2 or 10)
- Number of bands

The time is explicit.


~~~~ {.javascript}
{
  "valueTpe": "spectrum",
  "spectrum" : {
    "value" : {
      "valueType" : "float",
      "unit" : "db rel 20 uPa"
    },
    "range" : {
      "valueType" : "float",
      "unit" : "f",
        "ruleType": "cpb"
        "cpb" {
          "basesystem": 10,
          "firstband": 2,
          "numberfractions": 3,
        },
    },
    "count" : 15
  }  
}
~~~~

Data block will contain an absolute time stamp followed by 15 real32 with the amplitude information.



### Statistics {#Statistics}

Statistics consists of N "counters" each covering a value interval. If the measured value is within a counter interval, then that counter is incremented.
For instance the interval from 50 to 99 db might be covered by 50 counters. Each of these counters then would cover 1 dB.

Often there also is a lower than lowest and higher than highest counter, and for performance reasons, there might be a total counter.


Example: 50 - 99 dB statistics:
It is made up of a struct containing an [complex value type histogram](#Histogram) with 50 classes (bins) and three additional counters for the lower than, higher than and total count.

~~~~ {.javascript}
{
  "name": "statistic",
  "valueType": "struct",
  "struct" : {
    "histogram": {
      "valueType": "histogram",
      "histogram" : {
        "classes": {
          "valueType": "uint64",
          "implicitRule" : "linear",
          "linear" : {
	    "delta": 1.0,
	    "start": 50.0
	  }
          "count": 50.0,
        }
      }
    },
    "lowerThanCounter" {
      "valueType": uint64,
    },
    "higherThanCounter" {
      "valueType": uint64,
    },
    "totalCounter" {
      "valueType": uint64,
    },
  }
}
~~~~



Everything will be in 1 data block:

- 1 absolute time stamp.
- 50 uint64 for the 50 counters, 
- 1 uint64 for the higher than counter
- 1 uint64 for the lower than counter
- 1 uint64 for the total counter


### Spectral Statistics

Spectral statistics is a swarm of statistics over an additional axis.
This axis could for instance be a CPB axis, for each CPB band there is a statistic.

Example: 50 - 99 dB spectral statistics on a 1/3 octave CPB:


This is made up from an array of structs containing a histogram, lower than counter, higher than counter and a frequency

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "name": "spectral statistics",
  "valueTpe": "array",
  "array" : {
    "count" : 15,
    "valueType": "struct",
    "struct" : {
      "frequency": {
        "valueType": "double",
        "implicitRule": "CPB"
        "CPB" {
          "basesystem": 10,
          "firstband": 2,
          "numberfractions": 3,
        },
      },
      "histogram": {
        "valueType": "histogram",
        "histogram" : {
          "classes": {
            "valueType": "uint64",
            "implicitRule" : "linear",
            "linear" : {
              "delta": 1.0,
              "start": 50.0
            },
            "count": 50.0,
          }
        }
      },
      "lowerThanCounter" {
        "valueType": uint64
      },
      "higherThanCounter" {
        "valueType": uint64
      },
    }
  }
}
~~~~

Data block will contain a absolute time stamp followed by:
- 15 statistics, each containing:
  * 50 uint64 for the 50 histogram classes, 
  * 1 uint64 for the higher than counter
  * 1 uint64 for the lower than counter


### Run up

This is an array of 15 structs containing a fft and a frequency.
The frequency follows a linear rule.

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "name": "spectral statistics",
  "valueTpe": "array",
  "array" : {
    "count" : 15
    "valueType": "struct",
    "struct" : {
      "frequency": {
        "valueType": "double",
        "implicitRule" : "linear",
        "linear" : {
          "delta": 10.0,
          "start" : 1000.0
        },
      },
      "fft": {
        "valueTpe": "spectrum",
        "spectrum" : {
          "count" : 100,
          "value" : {
            "valueType" : "double",
            "unit" : <unit object>
          },
        "range" : {
          "valueType" : "double",
          "unit" : <unit object>,
          "implicitRule" : "linear",
          "linear" : {
	        "delta": 10.0,
	        "start" : 1000.0
          }
        }
      }
    }      
  }
}
~~~~

Data block will contain an absolute time stamp followed by 15 spectras with 100 calues each.


### Position in 3 dimensional Space

The value is a struct of three double values x, y, and z.

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "name": "position",
  "valueTpe": "struct",
  "struct" : {
    "x" : {
      "valueType" : < value type >,
      "ruleType": "explicit",
      "unit" : < unit object >
    },
    "y" : {
      "valueType" : < value type >,
      "ruleType": "explicit",
      "unit" : < unit object >
    },
    "z" : {
      "valueType" : < value type >,
      "ruleType": "explicit",
      "unit" : < unit object >
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "ruleType": "explicit",
    "valueType": "time",
  }
}
~~~~

We receive 1 data block with one abolute time stamp and a struct with three double values.






### Harmonic Analysis

Matthias: I'm not sure whether I understood the structure correctly. This needs to be clarified.

The result delivered from harmonic analysis done by HBM Genesis/Perception is fairly complex.
One combined value consists of the following:
- a scalar value distortion
- a scalar value fundamental frequency
- an array of ffts each one belonging to the harmonixc frequencies.

Here we define a complex type that is made up struct with some base types and an array of 10 spectras.

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "name": "spectral statistics",
  "valueTpe": "struct",
  "struct" : {
    "distortion" : < double >,
    "fundamental frquency" : < double >
    "harmonics" : {
      "valueType: "array",
      "array" : {
        "count": 10,
        "valueType": "struct",
        "struct" : {
          "frequency" : {
            "valueType": "double"
          },
          "fft" : {          
            "valueType": "spectrum",
            "spectrum" : {
              "count" : 360,
              "value" : {
                "valueType" : "double",
                "unit" : <unit object>
              },
              "range" : {
                "valueType" : "double",
                "unit" : <unit object>,
                "implicitRule" : "linear",
                "linear" : {
                  "delta": 1,
  		          "start" : 0
                }
              }
            }          
          }          
        }        
      }      
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "ruleType": "explicit",
    "valueType": "time",
  }
}
~~~~



Here we get the following values in 1 data block:

- 1 time stamp
- a double value distortion
- a double value fundemantal frequency
- array with 10 structs containing:
  * a double value freuqency 
  * 360 double spectrum values for the amplitude over phase
