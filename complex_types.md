---
title: "How to Model Complex Signals"
author: Draft
abstract: This is a proposal how we might describe signals of any complexity.
  Some techniques mentioned here are based on the HBM Streaming Protocol
  Until we have a complete specification of the new streaming protocol,
  [please refer here](https://github.com/HBM/streaming-spec/blob/master/streaming.md).
---


# Measured Data and Meta Information

HBM Streaming Protocol differentiates between meta information and measured data.
The meta information describes a stream or signal and tells how to interprete the measured data of a signal.

For both there is a header telling the signal id the measured data or meta information belongs to. If the data is related to the stream or device the signal id is 0.
In addition, this header contains length information. If the content is not understood,
the parser can step to the next header and proceed with processing. This is usefull if the stream contains information, the client is not aware of.

## Stream Specific Meta Information

Everything concerning the whole device or the stream. Examples:

* Available Signals
* Device status information

## Signal Specific Meta Information

Everything describing the signal. Examples:

* Endianness of the binary data transferred.
* Signal name
* Signal unit information


\pagebreak

# Data Types

We support the following base value types:

* int8
* uint8
* int16
* uint16
* int32
* uint32
* int64
* uint64
* real32
* real64
* complex32
* complex64
* time (a 64 bit quantity that contains an absolute time given a specific time family)

In addition we might have known compound value types that are combinations of those base value types.
There might be implicit knowledge about how to handle those known compound value types. If one is not able to handle a type, the underlying length information can be used to skip the package.
Currently there are no such value types.

The following section describe some compound data types, that be can made by combining base data types.

## Array

An array of values of the same type. The number of elements is fixed.

~~~~ {.javascript}
{
  "array": {
    "count": 50,
    <member description>
  }
}
~~~~

- `array/count`: Number of elements in the array. It does neither tell about the size of data nor the number of values within each element.


## Struct

A combination of named members which may be of different types.

~~~~ {.javascript}
{
  "struct": [
    {
      "name" : <member name>
      <member description>
    },
      ...
    {
      "name" : <member name>
      <member description>
    }
  ]
}
~~~~

- `name`: Each struct member has a name.
- `<member description>`: The type of each struct member. The type can be a base type (e.g. uint32), or one f the compound types (e.g. array, struct, spectrum, histogram...)

## A Spectrum {#Spectrum}

### Spectrum As a Compound Value Type

Spectral values over a range in the spectral domain.

~~~~ {.javascript}
{
  "dataType": "spectrum",
  "spectrum" : {
    "count" : 100
    "value" : {
      "dataType" : "double",
      "unit" : <unit object>
    },
    "domain" : {
      "dataType" : "double",
      "unit" : <unit object>,
      "rule" : "linear",
      "linear" : {
		"delta": 10.0,
		"start" : 1000.0
      }
    },
  }
}
~~~~

In this example the spectral domain follows an implicit rule. 

- `spectrum`: A compound value type describing a spectrum
- `count`: Number of points in the spectrum
- `value`: Describing the spectral values (i.e. amplitude, attenuation)
- `domain`: Describing the range in the spectral domain (i.e. frequency)

### Generic Alternative

Here we combine array, struct and base types. There are no compound value types, only a combination of the mentioned types!

In addition we introduce the functiontype which helps the client to inteprete the data.

~~~~ {.javascript}
{
  "functionType": "spectrum",
  "array": {
    "count": 100,
    "struct": [
      {
        "name": "amplitude",
        "dataType": "double",
        "unit": "dB",
        "rule": "explicit"
      },
      {
        "name": "frequency",
        "dataType": "double",
        "unit": "Hz",
        "rule": "linear",
        "linear": {
          "delta": 10.0,
          "start": 1000.0
        }
      }
    ]
  }
}
~~~~

- `functionType`: Depending on the type, the client expects a specified structure.
- `array/count`: The number of points in each spectrum
- struct member `amplitude`: Describes the measured values (i.e. amplitude, attenuation).
- struct member `frequency`: Describes the range in the spectral domain (i.e. frequency)

Only struct member `amplitude` is explicit, hence this is the data to be transferred.

## Histogram {#Histogram}

### Histogram As a Compound Value Type


~~~~ {.javascript}
{
  "dataType": "histogram",
  "histogram": {
    "classes": {
      "count": 50,
      "dataType": "uint64",
      "rule" : "linear",
      "linear" : {
		"delta": 1.0,
		"start": 50.0
	  }
    },
  },
}
~~~~

- `histogram`: An compound value type describing the histogram
- `classes`: The distribution classes are desribed here. This equals very much the linear implicit axis rule!
- `classes/count`: Number of distributaion classes
- `classes/dataType`: Type of counters
- `classes/rule`: This histogram follows an implicit linear rule. Other rules are also possible.
- `classes/linear/delta`: Width of each distribution class
- `classes/linear/start`: First distribution class starts here

### Generic Alternative

Here we combine array, struct and base types. There are no compound value types, only a combination of the mentioned types!

In addition there is a functiontype which helps the client to inteprete the data.

~~~~ {.javascript}
{
  "functionType": "histogram",
  "array": {
    "count": 50,
    "struct": [
    {
      "name": "count",
      "dataType": "uint64",
      "rule": "explicit"
    },
    {
      "name": "class",
      "dataType": "double",
      "unit": "Hz",
      "rule": "linear",
      "linear" : {
        "delta": 1.0,
        "start": 50.0
      }
    }
    ]
  }
}
~~~~

- `functionType`: Depending on the type, the client expects a specified structure.
- `array/count`: The number of classes in each histogram
- struct member `count`: Value of the counter
- struct member `class`: Class

Only struct member `count` is explicit, hence this is the data to be transferred.



\pagebreak


# Implicit Rules

A value might follow a specific rule. We do not need to transfer each value, just some start information and the rule to calculate any other value that follows.
We use implicit rules to greatly reduce the amount of data to be transferred, stored and processed.

There are several kinds of rules. To calculate the absolute value , the rule has to be applied.

All implicit rules are described by a signal specific meta information.


## Linear Rule {#Linear_Rule}
For equidistant value we use the linear rule.

It is described by an absolute start value and a relative delta between two neighboring values.

![Equidistant 2 dimensional points](images/equidistant_points.png)

There are cases, where the axis is an array of values with fixed length (i.e. the frequency of a spectrum).
Here we add a value count. Each array of values start with the start value.

A linear axis is described as follows:

~~~~ {.javascript}
{
  "rule": "linear",
  "linear": {
    "start": <value>,
    "delta": <value>,
  },
}
~~~~

- `rule`: Type of implicit rule
- `linear`: Properties of the implicit linear rule
- `linear/start`: the first value
- `linear/delta`: The difference between two values


## constant Rule
The rule is simple: There is a start value. The value equals the start value until a new start value is posted.

~~~~ {.javascript}
{
  "rule": "constant",
  "constant": {
    "start": <value>,
  },
}
~~~~

\pagebreak

## cpb Rule
Octave-band and fractional-octave band spectrum (CPB comes from Constant Percentage Bandwidth).
Definitions come from CEI IEC 1260-1: Electroacoustics - Octave-band and fractonal-octave-band filters.


~~~~ {.javascript}
{
  "rule": "cpb"
  "cpb" {
    "basesystem": 10,
    "firstband": 2,
    "numberfractions": 3
  }
}
~~~~

- `rule`: Type of implicit rule
- `cpb`: Details for the rule of type CPB
- `cpb/basesystem` : logarithm base used in the CPB (either 2 or 10)
- `cpb/firstband` : Index of the first band of the spectrum (Band 0 is 1 Hz and firstband may be negative)
- `cpb/numberfractions` : Number of fractions per octave. Possible values 1 - 24




\pagebreak

## logarithmic Rule
Logarithmic scale based on a specified factor


~~~~ {.javascript}
{
  "rule": "logarithimc"
  "logarithimc" {
    "firstvalue": 1.0,
    "logarithmicfactor": 2.0
  }
}
~~~~

- `rule`: Type of implicit rule
- `logarithmic`: Details for the rule of type logarithmic
- `logarithmic/firstvalue` : The first value.
- `logarithmic/logarithmicfactor` : Multiply by this factor to get the next value.



\pagebreak

## logiso Rule
Logarithmic scale based on the "ISO 3" preferred numbers.


~~~~ {.javascript}
{
  "rule": "logiso"
  "logiso" {
    "firstband": 2,
    "numberfractions": 3
  }
}
~~~~

- `rule`: Type of implicit rule
- `logiso`: Details for the rule of type logiso
- `logiso/firstband` : Index of the first band of the spectrum (Band 0 is 1 Hz and firstband may be negative)
- `logiso/numberfractions` : Number of fractions per decade. Possible values: 10, 20, 40, 80



\pagebreak


# Explicit Rule
![2 dimensional points](images/non_equidistant_points.png)

When there is no implicit rule defined, each value has an absolute coordinate for this axis.
There is no rule how to calculate the absolute value. We call it an explicit rule.

~~~~ {.javascript}
{
  "rule": "explicit"
}
~~~~

Explicit rule does not have any further parameters.

\pagebreak


# Time

The time is mandatory for each signal. It is not part of the signal value.
It can follow an implicit rule (most likely equidistant or linear) or may be explicit.

## Time Stamp format

We are going to use the B&K time stamping format. 

It uses a so called family time base, which is the base frequency of the time stamp counter. Absolute time stamps are 64 bits ticks since 1970 (unix epoch).

The family time base frequency is determined as follows: 
2^k * 3^l * 5^m * 7^n Hz

Where k, l, m and n range from 0 to 255.


## Linear Time
Equidistant time is described as a [linear implicit rule](#Linear_Rule).
To calculate the absolute time for linear time, There needs to
be an absolute start time and a delta time.
Both can be delivered by a separate, signal specific, meta information.

- The delta is mandatory.
- The absolute time always belongs to the next following value
- The device might deliver the absolute time before delivering the first value point.
- If the device does not possess a clock, there might be no absolute time at all.
- The device might deliver the absolute time whenever its clock is being set (resynchronization).
- It might deliver a new absolute time after a pause or any other abberation in the equidistant time


~~~~ {.javascript}
{
  "method": "time",
  "params": {
    "rule": "linear",
    "linear": {
      "start": <value>,
      "delta": <value>,
    },
    "unit": <unit object>,
    "dataType": <string>,
}
~~~~

- `method`: Type of meta information
- `rule`: type of axis
- `unit`: Unit of the axis
- `linear/start`: The absolute timestamp for the next value point.
- `linear/delta`: The time difference between two value points

## Explicit Time
Time is delivered as absolute time stamp for each value.

~~~~ {.javascript}
{
  "method": "time",
  "params": {
    "rule": "explicit",
    "unit": <unit object>,
    "dataType": "time"
  }
}
~~~~

- `method`: Type of meta information

\pagebreak


## How to Interprete Measured Data

After the meta information describing the signal has been received, delivered measured data blocks are to be interpreted as follows:

- See whether this is more meta information or measured data from a signal.
- Each data block contains all explicit values of a signal.
- Non explicit Values are calculated according their rule (i.e. constant, linear).
- Theoretically a signal might contain no explicit value at all. There won't be any component value to be transferred. All component values are to calculated using their rules.
- A block may contain many values of this signal. They are arranged value by value.

\pagebreak



# Examples

## A Voltage Sensor

The signal has 1 scalar value. Synchronous output rate is 100 Hz

- The voltage is expressed as a base value type
- The device delivers scaled component value in 32 bit float format
- The time is linear.

The device sends the following signal-specific meta information.


~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "name": "voltage 1",
    "rule": "explicit",
    "dataType": "float",
    "unit": "V",
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "rule": "linear",
    "linear": {
      "start": "high noon, 1st january 2019"
      "delta": "10 ms"
    },
    "dataType": "time"
  ]
}
~~~~

Data block has the value of this signal encoded float. No time stamps.

## A CAN Decoder

The signal has a simple scalar value.

- The value is expressed as a base value type
- The value is explicit.
- The time is explicit.

The device sends the following signal-specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "name": "decoder 6",
    "rule": "explicit",
    "dataType": "u32",
    "unit": "decoder unit"
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "rule": "explicit",
    "dataType": "time"
  }
}
~~~~

Each value point has an absolute time stamp and one u32 value.

## A Simple Counter

This is for counting events that happens at any time (explicit rule).

- The value is expressed as a base value type
- The count value is linear with an increment of 2, it runs in one direction
- The device sends an initial absolute value within the meta information describing the signal.
- The time is explicit.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "name": "counter",
    "dataType": "u32",
    "rule" : "linear",
    "linear": {
      "start" : 0,
      "delta" : 2
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "rule": "explicit",
  }
}
~~~~


Value is linear with a step width of 2.

The counter value has a non explicit rule, hence `counter` won't be transferred. Data blocks will contain timestamps only.



## An Absolute Rotary Encoder

- The value is expressed as a base value type
- The angle is explicit, it can go back and forth
- The time is explicit.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "rule": "explicit",
    "name": "angle",
    "dataType": "i32",
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "rule": "explicit",
  }
}
~~~~

Data block will contain a tuple of absolute angle and time stamp. There will be no meta ionformation when direction changes.



## An Incremental Rotary Encoder with start Position

- The value is expressed as a base value type
- The counter representing the angle follows a linear rule, it can go back and forth
- Absolute start position when crossing a start position.
- No initial absolute value.
- The time is explicit.


~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "rule": "linear",
    "linear": {
      "delta": 1,
    },
    "name": "angle",
    "dataType": "i32",
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "rule": "explicit",
  }
}
~~~~


This is similar to the simple counter. Data blocks will contain timestamps only.
`angle` changes by a known amount of 1. Only time stamps are being reansferred.

We get a (partial) meta information with a `start` value of the counter every time the zero index is being crossed:

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "linear" : {
      "start" : 0
    }
  }
}
~~~~

If the rotation direction changes, we get a (partial) meta information with a new `delta` for the linear rule:

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "linear" : {
      "delta": -1
    }
  }
}
~~~~

This type of counter is usefull when having a high counting rate with only few changes of direction. The handling is complicated because there are lots of meta information being send.



## A Spectrum

The signal consists of a spectum

- Each value consists of two elements:
	* Frequency which is implicit linear, it has an absolute start value of 100.
	* Amplitude which is explicit
- The time is explicit. Each complete spectrum has one time stamp.

Above you can find the [signal meta information describing a spectrum](#Spectrum). Just set the `count`to 1024.

### Time Meta Information

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "rule": "explicit",
    "dataType": "time"
  ]
}
~~~~

### Transferred Measured Data

Data block will contain an absolute time stamp followed by 1024 amplitude double values. There will be no frequency values because they are implicit.

## An Optical Spectrum with Peak Values

The signal consists of a spectum and an array of peak values. Number of peaks is fixed 16.
If the number of peaks does change, there will be a meta information telling about the new amount (`count`) of peaks!

Meta information describing the signal:

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "name": "Optical Spectrum with Peak Values",
    "struct": [
      {
        "name": "spectrum",
        "functionType": "spectrum",
        "array": {
          "count": 100,
          "struct": [
            {
              "name": "amplitude",
              "dataType": "double",
              "unit": "dB",
              "rule": "explicit"
            },
            {
              "name": "frequency",
              "dataType": "double",
              "unit": "Hz",
              "rule": "linear",
              "linear": {
                "delta": 10,
                "start": 1000
              }
            }
          ]
        }
      },
      {
        "name": "the peak values",
        "array": {
          "count": 16,
          "struct": [
            {
              "name": "frequency",
              "dataType": "double",
              "unit": "Hz"
            },
            {
              "name": "amplitude",
              "dataType": "double",
              "unit": "dB"
            }
          ]
        }
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "rule": "explicit",
    "dataType": "time"
  }
}
~~~~

Data block will contain:

- 1 absolute time stamp
- 1024 spectrum amplitude double values. No spectrum frequncy values because those are implicit.
- 16 amplitude, frequency pairs.





## Statistics {#Statistics}

Statistics consists of N "counters" each covering a value interval. If the measured value is within a counter interval, then that counter is incremented.
For instance the interval from 50 to 99 dB might be covered by 50 counters. Each of these counters then would cover 1 dB.

Often there also is a lower than lowest and higher than highest counter, and for performance reasons, there might be a total counter.


Example: 50 - 99 dB statistics:
It is made up of a struct containing an [compound value type histogram](#Histogram) with 50 classes (bins) and three additional counters for the lower than, higher than and total count.

### Signal Meta Information

Above we described two alternatives describing the histrogram within the signal meta information:

#### With Special Data Type for Histogram

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "name": "statistic",
    "struct": [
      {
        "name": "histogram",
        "dataType": "histogram",
        "histogram": {
          "classes": {
            "dataType": "uint64",
            "rule": "linear",
            "linear": {
              "delta": 1,
              "start": 50
            },
            "count": 50
          }
        }
      },
      {
        "name": "lowerThanCounter",
        "dataType": "uint64",
        "rule": "explicit"
      },
      {
        "name": "higherThanCounter",
        "dataType": "uint64",
        "rule": "explicit"
      },
      {
        "name": "totalCounter",
        "dataType": "uint64",
        "rule": "explicit"
      }
    ]
  }
}
~~~~



#### Generic Description

~~~~ {.javascript}
{
  "name": "statistic",
  "struct": [
    {
      "name": "histogram",
      "functionType": "histogram",
      "array": {
        "count": 50,
        "struct": [
          {
            "name": "count",
            "dataType": "uint64",
            "rule": "explicit"
          },
          {
            "name": "class",
            "dataType": "double",
            "unit": "Hz",
            "rule": "linear",
            "linear": {
              "delta": 1,
              "start": 50
            }
          }
        ]
      }
    },
    {
      "name": "lowerThanCounter",
      "dataType": "uint64",
      "rule": "explicit"
    },
    {
      "name": "higherThanCounter",
      "dataType": "uint64",
      "rule": "explicit"
    },
    {
      "name": "totalCounter",
      "dataType": "uint64",
      "rule": "explicit"
    }
  ]
}
~~~~

#### Time Meta Information

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "rule": "explicit",
    "dataType": "time"
  ]
}
~~~~

#### Transferred Measured Data

Everything will be in 1 data block:

- 1 absolute time stamp.
- 50 uint64 for the 50 counters,
- 1 uint64 for the higher than counter
- 1 uint64 for the lower than counter
- 1 uint64 for the total counter


## Spectral Statistics

Spectral statistics is a swarm of statistics over an additional axis.
This axis could for instance be a CPB axis, for each CPB band there is a statistic.

Example: 50 - 99 dB spectral statistics on a 1/3 octave CPB:


This is made up from an array of structs containing a histogram, lower than counter, higher than counter and a frequency

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "functionType": "spectralStatistics",
    "array": {
      "count": 15,
      "struct": [
        {
          "name": "frequency",
          "dataType": "double",
          "rule": "explicit"
        },
        {
          "name": "fft",
          "dataType": "spectrum",
          "spectrum": {
            "count": 100,
            "value": {
              "dataType": "double",
              "unit": "db"
            },
            "domain": {
              "dataType": "double",
              "unit": "frequency",
              "rule": "linear",
              "linear": {
                "delta": 10,
                "start": 1000
              }
            }
          }
        }
      ]
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "rule": "explicit",
    "dataType": "time"
  }
}
~~~~


Data block will contain a absolute time stamp followed by:
- 15 statistics, each containing:
  * 50 uint64 for the 50 histogram classes,
  * 1 uint64 for the higher than counter
  * 1 uint64 for the lower than counter


## Run up

This is an array of 15 structs containing a fft and a frequency.
Fft amplitudes and frenqeuncy are explicit.

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "name": "run up",
    "array": {
      "count": 15,
      "struct": [
        {
          "name": "frequency",
          "dataType": "double",
          "rule": "explicit"
        },
        {
          "name": "fft",
          "dataType": "spectrum",
          "spectrum": {
            "count": 100,
            "value": {
              "dataType": "double",
              "unit": "db"
            },
            "domain": {
              "dataType": "double",
              "unit": "frequency",
              "rule": "linear",
              "linear": {
                "delta": 10,
                "start": 1000
              }
            }
          }
        }
      ]
    }
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "dataType": "time"
    "rule": "explicit",
  }
}
~~~~



Data block will contain an absolute time stamp followed by 15
frequencies with the corresponding spectra containing 100 amplitude values each.


## Position in 3 dimensional Space

The value is a struct of three double values x, y, and z.

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "functionType": "cartesianCoordinate",
    "dataType": "struct",
    "struct": [
      {
        "name": "x",
        "dataType": "double",
        "rule": "explicit",
        "unit": "m"
      },
      {
        "name": "y",
        "dataType": "double",
        "rule": "explicit",
        "unit": "m"
      },
      {
        "name": "z",
        "dataType": "double",
        "rule": "explicit",
        "unit": "m"
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "dataType": "time",
    "rule": "explicit",
  }
}
~~~~

We receive 1 data block with one abolute time stamp and a struct with three double values.






## Harmonic Analysis

The result delivered from harmonic analysis done by HBM Genesis/Perception is fairly complex.
One combined value consists of the following:
- some scalar values
  * distortion: The Total Harmonic Distortion (according to IEC 61000-4-7).
  * fundamental frquency: Average fundamental frequency.
  * dcAmplitude: The amplitude of the DC component.
  * cycleCount: The number of cycles in the window (according to IEC 61000-4-7)
  * harmonicCount: The number of harmonic orders (0 ... (MAX_HARMONIC_ORDERS = 50)).
- an array of structures with information about the heamonics.
  * amplitude: Amplitude of the n-th hramonics
  * phase: Phase of the n-th hramonics

All elements are explicit.

Right now we have arrays of fxed size only. Hence we always get 50 elements
event if the count is much smaller.

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "functionType": "spectralAnalysis",
    "struct": [
      {
        "name": "distortion",
        "dataType": "double",
        "rule": "explicit"
      },
      {
        "name": "fundamentalFrequency",
        "dataType": "double",
        "rule": "explicit"
        "unit": "Hz"
      },
      {
        "name": "dcAmplitude",
        "dataType": "double",
        "rule": "explicit",
        "unit": "V"
      },
      {
        "name": "cycleCount",
        "dataType": "double",
        "rule": "explicit"
      },
      {
        "name": "harmonicCount",
        "dataType": "double",
        "rule": "explicit"
      },
      {
        "name": "harmonics",
        "array": {
          "count": 50,
          "struct": [
            {
              "name": "amplitude",
              "rule": "explicit"
            },
            {
              "name": "phase",
              "unit": "rad",
              "rule": "explicit"
            }
          ]
        }
      }
    ]
  }
}
~~~~

~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "dataType": "time",
    "rule": "explicit",
  }
}
~~~~

Here we get the following values in 1 data block:

- 1 time stamp as uint64
- a double value distortion
- a double value fundemantal frequency
- a double value with the dc amplitude
- an unsigned integer with the cycle count
- an unsigned integer with the harmonics count
- array with 50 harmonic structs each containing:
  * a double value with the amplitude of the harmonic
  * a double value with the phase of the harmonic
