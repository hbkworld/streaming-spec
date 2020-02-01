---
title:  HBK Stream Protocol Specification
author: Version 0.0
---


# Overview

The data streaming mechanism is intended to enable client programs to receive
(measurement) data from (measurement) data acquisition devices, further called devices.
The protocol was designed with the following constraints in mind:

-   Use only one socket connection per instance of data acquisition to
    limit the number of open sockets. Multiple data acquisition instances are possible but
    devices may prevent this for performance reasons.

-   Minimize network traffic.

-   Extensible signal description and spurious event notification.

-   Transmit Meta information about the acquired signals to make the
    data acquisition self-contained. This means that it is not necessary to
    gather information via the setup interface to interpret the acquired
    signals.

# Architecture

There are three main components involved. A [transport layer](#transport-layer) and a
[presentation layer](#presentation-layer) allow the interpretation of
data send over the Stream socket by the device. [Command Interface(s)](#command-interfaces)
allow to subscribe or unsubscribe signals to a streaming instance.

# Transport Layer 

The transport layer consists of a header and a variable length
block of data. The header has 32 bit in little endian. The structure of the header is depicted below.

![A single block on transport layer](images/transport.png)

## Signal Info Field

![The Signal Info Field](images/sig_info.png)

### Type

The `Type` sub-field allows to distinguish the type of payload, which can be either
[Signal Data](#signal-data) or [Meta Information](#meta-information):

Signal Data: 0x01

Meta Information: 0x02

### Reserved

This field is reserved for future use and must be set to `00b`.

### Size

Indicates the length in bytes of the data block that follows.

If `Size` equals 0x00, the length of the following data block is
determined by the (optional) `Data Byte Count` field. If content is not understood,
the parser can read over to the next header and proceed with processing. This is useful if the stream contains information the client is not aware of.

## Signal Number

The `Signal Number` field indicates to which signal the following data
block belongs to. It MUST within a single device. Different
devices MAY use the same signal numbers. The `Signal Number` is required
to carry more than one single signal over a single socket connection.

`0` is the `Signal Number` reserved for [Stream Related Meta Information](#stream-related-meta-information).

## Data Byte Count

This field is only present if `Size` equals 0x00. If
so, `Data Byte Count` represents the length in byte of the data block that
follows. This 32 bit word is always transmitted in little endian.

# Presentation Layer

## Terminology

- Measured value: A measured value consists at least of one member. Arrays and structs can be used to combine several members to a compound measured value.
- Member: A member is a base data type carrying some measured information.

## Signal Data

The `Data` section contains signal data (measurement data acquired by the device) related to the
respective `Signal_Number`. [Meta Information](#meta-information) MAY be necessary to interpret Signal Data.

## Meta Information

The `Data` section contains additional ("Meta") information related to
the respective `Signal_Number`. Some [Signal Related
Metainformation](#signal-related-meta-information) is REQUIRED to correctly
interpret the respective [Signal Data](#signal-data). Meta Information
may also carry information about certain events which MAY happen on a
device like changes of the output rate or time resynchronization.

A Meta information block always consists of a Metainfo_Type and a Metainfo_Data block.

![A Meta Information block](images/meta_block.png)

### Metainfo_Type

The Metainfo_Type indicates how data in the Metainfo_Data block is
encoded. This 32 bit word is always transmitted in little endian.


## Data Types

We support the following base data types:

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


### Array

An array of members of the same type. The number of elements is fixed.

~~~~ {.javascript}
{
  "array": {
    "count": 50,
    <member description>
  }
}
~~~~

- `array/count`: Number of elements in the array.
- `<member description>`: Might be a base type, another array or a struct


### Struct

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
- `<member description>`: The type of each struct member. Can be a base type, array, or struct



## Rules

A value might follow a specific rule. We do not need to transfer each value, just some start information and the rule to calculate any other value that follows.
Using rules can greatly reduce the amount of data to be transferred, stored and processed.

There are cases, where we get an array of values with fixed length (i.e. the frequency of a spectrum).
Here we add a value count. Each array of values starts with the start value.

All rules are described by a signal specific meta information.

There are different kinds of rules.

### Linear Rule {#Linear_Rule}
For equidistant value we use the linear rule.

It is described by an absolute start value and a relative delta between two neighboring values.

![Equidistant 2 dimensional points](images/equidistant_points.png)


A linear axis is described as follows:

~~~~ {.javascript}
{
  "rule": "linear",
  "linear": {
    "start": <value>,
    "delta": <value>,
    "count": <value>,
  },
}
~~~~

- `rule`: Type of implicit rule
- `linear`: Properties of the implicit linear rule
- `linear/start`: the first value
- `linear/delta`: The difference between two values
- `linear/count`: The number of values until a rollover to the start value occurs


### constant Rule
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

### cpb Rule
Octave-band and fractional-octave band spectrum (CPB comes from Constant Percentage Bandwidth).
Definitions come from CEI IEC 1260-1: Electroacoustics - Octave-band and fractonal-octave-band filters.


~~~~ {.javascript}
{
  "rule": "cpb"
  "cpb" {
    "basesystem": 10,
    "firstband": 2,
    "numberOfFractions": 3
  }
}
~~~~

- `rule`: Type of implicit rule
- `cpb`: Details for the rule of type CPB
- `cpb/basesystem` : logarithm base used in the CPB (either 2 or 10)
- `cpb/firstband` : Index of the first band of the spectrum (Band 0 is 1 Hz and firstband may be negative)
- `cpb/numberOfFractions` : Number of fractions per octave. Possible values 1 - 24




\pagebreak

### logarithmic Rule
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

### logiso Rule
Logarithmic scale based on the "ISO 3" preferred numbers.


~~~~ {.javascript}
{
  "rule": "logiso"
  "logiso" {
    "firstband": 2,
    "numberOfFractions": 3
  }
}
~~~~

- `rule`: Type of implicit rule
- `logiso`: Details for the rule of type logiso
- `logiso/firstband` : Index of the first band of the spectrum (Band 0 is 1 Hz and firstband may be negative)
- `logiso/numberOfFractions` : Number of fractions per decade. Possible values: 10, 20, 40, 80



### Explicit Rule
![2 dimensional points](images/non_equidistant_points.png)

When there is no rule to calculate values depending on a start value the explicit rule is being used: Each value is transferred.

~~~~ {.javascript}
{
  "rule": "explicit"
}
~~~~

Explicit rule does not have any parameters.

\pagebreak


## Time

The time is mandatory for each signal. It is not part of the signal value.
It can follow an implicit rule (most likely equidistant or linear) or may be explicit.

### Time Stamp format

We are going to use the B&K time stamping format. 

It uses a so called family time base, which is the base frequency of the time stamp counter. Absolute time stamps are 64 bits ticks since 1970 (unix epoch).

The family time base frequency is determined as follows: 
2^k * 3^l * 5^m * 7^n Hz

Where k, l, m and n range from 0 to 255.


### Linear Time
Equidistant time is described as a [linear implicit rule](#Linear_Rule).
To calculate the absolute time for linear time, there needs to
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
      "start": <value>, // Always in ISO8601 format
      "delta": <value>,
    },
    "unit": <unit object>,
    "dataType": "time",
}
~~~~

- `method`: Type of meta information
- `rule`: type of rule
- `unit`: Unit. Could be s, ms, Hz, mHz etc.
- `linear/start`: The absolute timestamp for the next value point.
- `linear/delta`: The time difference between two value points

### Explicit Time
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



## Stream Related Meta Information

Everything concerning the stream ([Signal Number](#signal-number) `= 0` on the transport layer)

### API Version

~~~~ {.javascript}
{
  "method": "apiVersion",
  "params": ["1.0.0"]
}
~~~~

The version follows the [semver scheme](https://semver.org/).

This Meta information is always sent directly after connecting to the
stream socket.


### Init Meta

The Init Meta information provides the Stream ID (required for
[subscribing signals](#command-interfaces)) and a set of
[optional features](#optional-features--meta-information) supported by the device.
This Meta information MUST be send directly after the [Version Meta Information](#api-version).

~~~~ {.javascript}
{
  "method": "init",
  "params": {
    "streamId": <string>,
    "supported": {
      "<feature_name>": <feature_description>
      ...
    },
    "commandInterfaces": {
      "<command_interface_a>": {
        ... // service details
      },
      "<command_interface_b>": {
        ... // service details
      }
	}
  }
}
~~~~

`"streamId"`: A unique ID identifying the stream instance. It is required for
     using the [Command Interface](#command-interfaces).

`"supported"`: An Object which holds all [optional features](#optional-features--meta-information)
     supported by the device. If no optional features are supported, this object MAY be empty.
     The "supported" field's keys always refer to the respective optional feature name.
     E.g. the key "alive" refers to the
     [Alive Meta Information](#alive-meta-information). The field's value MUST
     comply to the respective Feature Value description.

`"commandInterfaces"`: An Object which MUST hold at least one command interface (descriptions)
     provided by the device. A command interface is required to
     [subscribe](#subscribe-signal) or [unsubscribe](#unsubscribe-signal) a signal.
     The key `<command_interface>` MUST be a String which specifies the name of
     the [command interface](#command-interfaces). The associated Object value
     describes the command interface in further detail.

### Error

~~~~ {.javascript}
{
  "method": "error",
  "params": {
      "code": <number>,
      "message": <string>,
      "data": <anything>
    }
}
~~~~

This Meta information is always sent on errors.


`"code"`: A Number that indicates the error type that occurred. This MUST be an integer.

`"message"`: A String providing a short description of the error.

`"data"`: A Primitive or Structured value that contains additional information about the error. This may be omitted.


### Available signals

If connecting to the streaming server, the names of all signals that are currently available will be delivered.
If new signals appear afterwards, those new signals will be introduced by sending an `available` with the new signal names.

~~~~ {.javascript}
{
  "method": "available",
  "params": [<signal name>,...]
}
~~~~

### Unavailable signals

If signals disappear while being connected, there will be an `unavailable` with the names of all signals that disappeared.

~~~~ {.javascript}
{
  "method": "unavailable"
  "params": [<signal name>,...]
}
~~~~


### Subscribe Related Information

The string value of the subscribe key always carries the unique signal name of the signal.
It constitutes the link between the subsrcibed signal name and the `Signal_Number` used on the transport layer.

~~~~ {.javascript}
{
  "method": "subscribe",
  "params": <signal name>
}
~~~~

`"params"`: Signal names of the subscribed signal.



### Unsubscribe Meta Information

The unsubscribe Meta information indicates that there will be send no more data with the same `Signal_Number` upon next subscribe.
This Meta information is emitted after a signal got unsubscribed.
No more data with the same `Signal_Number` MUST be sent after the unsubscribe acknowledgement.


~~~~ {.javascript}
{
  "method": "unsubscribe"
}
~~~~


## Signal Specific Meta Information

### Signal and Time description

A measured value of a signal consist of one or more members. 
All members and there properties are described in a signal related meta information `signal`.
In addition, each signal has time information which is described in a separate `time` meta information.

Here are some examples:

#### A Voltage Sensor

The signal has 1 scalar value. Synchronous output rate is 100 Hz

- Each measured value consists of one member
- This member is a scaled 32 bit float base data type which is explicit
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
      "start": "2007-12-24T18:21:16,3Z"
      "delta": "10 ms"
    },
    "dataType": "time"
    "unit": "???"
  ]
}
~~~~

Each Measured value contains a single float value which is the value of this signal. No time stamps.

~~~~
float
~~~~




#### A CAN Decoder

The signal has a simple scalar member.

- The value is expressed as a base data type
- The member is explicit.
- The time is explicit.

The device sends the following signal-specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "name": "decoder 6",
    "rule": "explicit",
    "dataType": "uint32",
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

Each Measured value has an absolute time stamp and one uint32 member.

~~~~
time stamp (uint64)
uint32
~~~~


#### A Simple Counter

This is for counting events that happens at any time (explicit rule).

- The measured value is expressed as a base data type
- The member `counter` is linear with an increment of 2, it runs in one direction
- The device sends an initial absolute value of `counter` within the meta information describing the signal.
- `time` is explicit.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "name": "counter",
    "dataType": "uint32",
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

`counter` has a linear rule with a step width of 2, hence `counter` won't be transferred.

A measured value is transferred as:

~~~~
time stamp (uint64)
~~~~


#### An Absolute Rotary Encoder

- The measured value is expressed as a base data type
- `angle` is explicit, it can go back and forth
- `time` is explicit.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "name": "angle",
    "rule": "explicit",
    "dataType": "double",
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

A measured value is transferred as: One absolute time stamp the angle.

~~~~
time stamp (uint64)
angle (double)
~~~~



#### An Incremental Rotary Encoder with start Position

- The measured value is expressed as a base data type
- The counter representing the angle follows a linear rule, it can go back and forth
- Absolute start position when crossing a start position.
- No initial absolute value.
- The time is explicit.


~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "name": "angle",
    "rule": "linear",
    "linear": {
      "delta": 1,
    },
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


This is similar to the simple counter. 
`angle` changes by a known amount of 1. Only time stamps are being reansferred.

A measured value is transferred as:

~~~~
time stamp (uint64)
~~~~



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



#### A Spectrum

The signal consists of a spectum

- Each value consists of two elements:
	* Frequency which is implicit linear, it has an absolute start value of 100.
	* Amplitude which is explicit
- The time is explicit. Each complete spectrum has one time stamp.




Spectral values over a range in the spectral domain.
We combine array, struct and base types.

In addition we introduce the `function` object which helps the client to inteprete the data.

~~~~ {.javascript}
{
  "name": "Spectrum",
  "function" : {
    "type": "spectrum"
  },
  "array": {
    "count": 1024,
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

- `function/type`: Depending on the type, the client expects a specified structure.
- `array/count`: The number of points in each spectrum
- struct member `amplitude`: Describes the measured values (i.e. amplitude, attenuation).
- struct member `frequency`: Describes the range in the spectral domain (i.e. frequency)

Only struct member `amplitude` is explicit, hence this is the data to be transferred.



~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "rule": "explicit",
    "dataType": "time"
  ]
}
~~~~

A measured value is transferred as: One absolute time stamp followed by 1024 amplitude double values. There will be no frequency values because they are implicit.


~~~~
time stamp (uint64)
spectrum amplitude 1 (double)
spectrum amplitude 2 (double)
...
spectrum amplitude 1024 (double)
~~~~



#### An Optical Spectrum with Peak Values

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
        "function" : { 
          "type": "spectrum"
        },
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

A measured value is transferred as:

- 1 absolute time stamp
- 1024 spectrum amplitude double values. No spectrum frequncy values because those are implicit.
- 16 amplitude, frequency pairs.


~~~~
time stamp (uint64)
spectrum amplitude 1 (double)
spectrum amplitude 2 (double)
...
spectrum amplitude 1024 (double)

frequency point 1 (double)
amplitude point 1 (double)
frequency point 2 (double)
amplitude point 2 (double)
...
frequency point 16 (double)
amplitude point 16 (double)
~~~~




#### Statistics {#Statistics}

Statistics consists of N "counters" each covering a value interval. If the measured value is within a counter interval, then that counter is incremented.
For instance the interval from 50 to 99 dB might be covered by 50 counters. Each of these counters then would cover 1 dB.

Often there also is a lower than lowest and higher than highest counter, and for performance reasons, there might be a total counter.


Example: 50 - 99 dB statistics:
It is made up of a struct containing an histogram with 50 classes (bins) and three additional counters for the lower than, higher than and total count.


Above we described two alternatives describing the histrogram within the signal meta information:

~~~~ {.javascript}
{
  "name": "Statistic",
  "function" : { 
    "type": "statistic"
  },
  "struct": [
    {
      "name": "histogram",
      "function" : { 
        "type": "histogram"
      },
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

Within there is a object describing a histrogram. It has the following members:
- `function/type`: Depending on the type, the client expects a specified structure.
- `array/count`: The number of classes in each histogram
- struct member `count`: Value of the counter
- struct member `class`: Class

It has its own function description.




~~~~ {.javascript}
{
  "method": "time",
  "params" : {
    "rule": "explicit",
    "dataType": "time"
  ]
}
~~~~

A measured value is transferred as:

- 1 absolute time stamp.
- 50 uint64 for the 50 counters,
- 1 uint64 for the higher than counter
- 1 uint64 for the lower than counter
- 1 uint64 for the total counter

~~~~
time stamp (uint64)
counter 1 (uint64)
counter 2 (uint64)
...
counter 50 (uint64)
higher than counter (uint64)
lower than counter (uint64)
total counter (uint64)
~~~~

#### Run up

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
          "function": {
            "type": "spectrum"
          },
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


A measured value is transferred as: One absolute time stamp followed by 15
frequencies with the corresponding spectra containing 100 amplitude values each.

~~~~
time stamp (uint64)

frequency 1 (double)
amplitude 1 belonging to frequency 1 (double)
amplitude 2 belonging to frequency 1 (double)
...
amplitude 100 belonging to frequency 1 (double)

frequency 2 (double)
amplitude 1 belonging to frequency 2 (double)
amplitude 2 belonging to frequency 2 (double)
...
amplitude 100 belonging to frequency 2 (double)

...

frequency 15 (double)
amplitude 1 belonging to frequency 15 (double)
amplitude 2 belonging to frequency 15 (double)
...
amplitude 100 belonging to frequency 15 (double)
~~~~

#### Point in Cartesian Space

Depending on the the number of dimensions n, 
The value is a struct of n double values. In this example we choose 3 dimensions x, y, and z.

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "name": "coordinate",
    "function" : {
      "type": "cartesianCoordinate"
    },
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

A measured value is transferred as: One abolute time stamp and three double values.

~~~~
time stamp (uint64)
x (double)
y (double)
z (double)
~~~~



#### Harmonic Analysis

The result delivered from harmonic analysis done by HBK Genesis/Perception is fairly complex.
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
    "name": "Harmonic analysis",
    "function": {
      "type": "harmonicAnalysis"
    },
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
        "dataType": "uint32",
        "rule": "explicit"
      },
      {
        "name": "harmonicCount",
        "dataType": "unit32",
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

A measured value is transferred as:

- 1 time stamp as uint64
- a double value distortion
- a double value fundemantal frequency
- a double value with the dc amplitude
- an unsigned integer with the cycle count
- an unsigned integer with the harmonics count
- array with 50 harmonic structs each containing:
  * a double value with the amplitude of the harmonic
  * a double value with the phase of the harmonic
  
  
~~~~
time stamp (uint64)
distortion (double)
fundemantal frequency (double)
dc amplitude (double)
cycle count (unit32)
harmonics count (uint32)
  
harmonic 1
amplitude of harmonic 1 (double)
phase of harmonic 1 (double)
harmonic 2
amplitude of harmonic 2 (double)
phase of harmonic 2 (double)
...
harmonic 50
amplitude of harmonic 50 (double)
phase of harmonic 50 (double)
~~~~
  
  
## Measured Data

After the meta information describing the signal has been received, measured values are to be interpreted as follows:

- The size of a complete measured value derives from the sum of the sizes of all explicit members
- Members are send in the same sequence as in the meta information describing the signal
- Only members with an explicit rule are transferred.
- Non explicit members are calculated according their rule (i.e. constant, linear). They take no room within the transferred measured data blocks.

  
# Command Interfaces


# Optional Features / Meta Information

## Ringbuffer Fill Level

Is send at will. The value of `fill` is a number
between 0 and 100 which indicates the stream`s associated data buffer
fill level. A fill value of 0 means the buffer is empty. A fill value of 100
means the buffer is full and the associated stream (and the associated
socket) will be closed as soon as all previously acquired data has been
send. This meta information is for monitoring purposes only and it is
not guaranteed to get a fill = 100 before buffer overrun.

### Fill Meta Information

~~~~ {.javascript}
{
  "method": "fill",
  "params": [38]
}
~~~~

### Fill Feature Object

If this feature is supported, the [Init Meta information`s](#init-meta)
"supported" field must have an entry named "fill" with this value:

~~~~ {.javascript}
true
~~~~
