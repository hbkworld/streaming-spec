---
title:  HBK Stream Protocol Specification
author: Version 0.0
---


# Overview

The data streaming mechanism is intended to enable client programs to receive
data from data acquisition devices, further called devices.
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
block of data. Everything on the transport layer is sent in little endian format.

The header has 32 bit in little endian format. The structure of the header is depicted below.

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
block belongs to. It MUST be unique within a single device. Different
devices MAY use the same signal numbers. The `Signal Number` is required
to differentiate more than one single signal carried over the same stream.

`0` is the `Signal Number` reserved for [Stream Related Meta Information](#stream-related-meta-information).

## Data Byte Count

This field is only present if `Size` equals 0x00. If
so, `Data Byte Count` represents the length in byte of the data block that
follows. This 32 bit word is always transmitted in little endian.

# Presentation Layer

## Terminology

- Signal: A signal is a data source delivering signal values.
- Signal Number: Identifies the signal on the transport layer.
- Signal Id: Identifies the signal on the representation layer.

- Signal Definition: A signal value consists at least of one member. Arrays and structs can be used to combine several members to a compound signal value. The resulting structure is the signal definition.
- Member: A member is a base data type carrying some measured information.
- Signal Value: The members of the signal definition define the complete signal value. It also defines what data is being transferred.
- Time Family: Describes how time stamps are to be interpreted.
- Meta Data
- Function Data

## Notation

We use [camel case](#https://en.wikipedia.org/wiki/Camel_case) for all keywords (example: "johnSmith")


## Signal Data

The `Data` section contains signal data (measurement data acquired by the device) related to the
respective `Signal_Number`. [Meta Information](#meta-information) are necessary to interpret Signal Data.
The signal data might be delivered in big or little endian.

## Meta Information

The `Data` section contains additional ("Meta") information related to
the respective `Signal_Number`. Some [Signal Related Metainformation](#signal-related-meta-information) is REQUIRED to correctly
interpret the respective [Signal Data](#signal-data). Meta Information
may also carry information about certain events which MAY happen on a
device like changes of the output rate or time resynchronization.

A Meta information block always consists of a Metainfo_Type and a Metainfo_Data block.



### Notifications

Since the configuration of a signal may change at any time, updated meta information may be notified at any time. Only the changed parameters will be transferred,
hence only parts of the meta information will be transferred.


![A Meta Information block](images/meta_block.png)

### Metainfo_Type

The Metainfo_Type indicates the protocol of the data in the Metainfo_Data.
This 32 bit word is always transmitted in little endian.

- json is not a binary format, hence there is not endianness
- msgpack uses big endian.

The endianness of the meta information Metainfo_Data block depends on the meta information format.




## Data Types

### Base Data Types

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


### Array

An array of members of the same data type. The number of elements is fixed.

~~~~ {.javascript}
{
  "dataType" : "array",
  "array": {
    "count": <number of elements>,
    <member description>
  }
}
~~~~

- `array/count`: Number of elements in the array.
- `<member description>`: Might be a base data type, another array or a struct

#### Transferred Data

The explicit content of the `count` array mebmers ist transferred.

### Dynamic Array

An array of members of the same data type. The number of elements is dynamic.

~~~~ {.javascript}
{
  "dataType" : "dynamicArray",
  "dynamicArray": {
    <member description>
  }
}
~~~~

- `<member description>`: Might be a base data type, another array or a struct

#### Transferred Data

A uint32 with the number of members followed by the explicit content of the members.

### Struct

A combination of named members which may be of different types.

~~~~ {.javascript}
{
  "dataType" : "struct",
  "struct": [
    {
      <member description>
    },
      ...
    {
      <member description>
    }
  ]
}
~~~~

- `<member description>`: Description of a struct member. Can be a base data type, array, or struct



## Rules

A member might follow a specific rule. We do not need to transfer each value, just some start information and the rule to calculate any other value that follows.
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
  },
}
~~~~

- `rule`: Type of implicit rule
- `linear`: Properties of the implicit linear rule
- `linear/start`: the first value
- `linear/delta`: The difference between two values


### Constant Rule
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






## Stream Related Meta Information

Everything concerning the stream ([Signal Number](#signal-number) `= 0` on the transport layer)

### API Version

~~~~ {.javascript}
{
  "method": "apiVersion",
  "params": {
    "version": "1.0.0"
   }
}
~~~~

The version follows the [semver scheme](https://semver.org/).

This meta information is always sent directly after connecting to the
stream socket.


### Init Meta

The Init Meta Information provides the stream id (required for
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
     comply to the respective feature value description.

`"commandInterfaces"`: An Object which MUST hold at least one command interface (descriptions)
     provided by the device. A command interface is required to
     [subscribe](#subscribe-signal) or [unsubscribe](#unsubscribe-signal) a signal.
     The key `<command_interface>` MUST be a String which specifies the name of
     the [command interface](#command-interfaces). The associated Object value
     describes the command interface in further detail.
     
### Time Meta Information

This gives information about the time on the device.

~~~~ {.javascript}
{
  "method": "time",
  "params": {
    "epoch": <string> // always in ISO8601 format
  }
}
~~~~

- `Epoch`: Start time all time stamps are based on. It is a [TAI (no leap seconds) time](#https://en.wikipedia.org/wiki/International_Atomic_Time) given in ISO8601 format (example: 1970-01-01 for the UNIX epoch)


### Synchronization Meta Information

It carries information about the time synchronization status

~~~~ {.javascript}
{
  "method": "sync",
  "params": {
    {
	  "syncType" : <type of time synchronization>,
	  "<type of time synchronization>" : {
		<object with parameters specific to the syncType (i.e. sync source url or name)>
	  },
	  "quality" : <quality of synchronization>
    }    
  }
}
~~~~


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

If connecting to the streaming server, the ids of all signals that are currently available MUST be delivered.
If new signals appear afterwards, those new signals MUST be introduced by sending an `available` with the new signal names.

~~~~ {.javascript}
{
  "method": "available",
  "params": [<signal id>,...]
}
~~~~

### Unavailable signals

If signals disappear while being connected, there MUST be an `unavailable` with the ids of all signals that disappeared.

~~~~ {.javascript}
{
  "method": "unavailable"
  "params": [<signal id>,...]
}
~~~~


## Signal Specific Meta Information

### Subscribe Related Information

The string value of the subscribe key always carries the unique signal id of the signal.
It constitutes the link between the subsrcibed signal id and the `Signal_Number` used on the transport layer.

~~~~ {.javascript}
{
  "method": "subscribe",
  "params": <signal id>
}
~~~~

`"params"`: Signal ids of the subscribed signal.



### Unsubscribe Meta Information

The unsubscribe Meta information indicates that there MUST NOT be send any data with the same `Signal_Number` upon next subscribe.
This Meta information is emitted after a signal got unsubscribed.
No more data with the same `Signal_Number` MUST be sent after the unsubscribe acknowledgement.


~~~~ {.javascript}
{
  "method": "unsubscribe"
}
~~~~


### Signal Description

Each signal is described in a signal related meta information `signal`.
[There are some example of signal descriptions in a separate chapter](#Examples-for-Signal-Descriptions).

~~~~ {.javascript}
{
  "content": {
    <contains at least one signal member description>
  },
  "time": {
    <time family and rule>
  },
  "data": {
    "endian": "little"|"big"
  }
}
~~~~

#### Signal Content Object

A signal value of a signal consist of one or more members.
All members and their properties are described in the `content` object in the `signal` meta information.
[There are some example of signal descriptions in a separate chapter](#Examples-for-Signal-Descriptions).

Each member... 

- MUST have the property `name`
- MUST have the property `rule`
- MUST have the property `dataType`
- MAY have a `interpretation` object containing optional information about how to interprete the signal

Those properties are described using a signal member object:

~~~~ {.javascript}
{
  "name": <string>,
  "rule": <type of rule as string>,
  "dataType": <data type as string>,
  "interpretation": { <optional> }
}
~~~~

A signal with just one member has just one [base data type](#base-data-types) value. When there are more than one members, [struct](#struct) and [array](#array) are used to describe the structure.

##### Signal Member Interpretation

Contains information that is not necessary for processing the protocol but for further interpretation on the client.
The optional `unit` of the member is to be found there.

~~~~ {.javascript}
{
  "name": <string>,
  "rule": <type of rule as string>,
  "dataType": <data type as string>,
  "interpretation": {
    "unit": <optional unit of the member>,
  }
}
~~~~



#### Signal Data Object

The signal meta information contains an object `data` describing the signal data.

-`"endian"`: Describes the byte endianess of the transferred signal data.

  - "big"; Big endian byte order (network byte order).
  - "little"; Little endian byte order.


#### Time Object

Each signal has a time information which is described in a `time object`.

The time object is mandatory for each signal.
It can follow an implicit rule (most likely equidistant or linear) or may be explicit.

The time object is expressed as follows:

~~~~ {.javascript}
{
  "time": {
    "timeFamily" : {
      "2" : 0..255, // Exponent for prime factor 2
      "3" : 0..255, // Exponent for prime factor 3
      "5" : 0..255, // Exponent for prime factor 5
      "7" : 0..255, // Exponent for prime factor 7
    }
    "rule" : ...
  }
}
~~~~

- `timeFamily`: The time prime factor exponents defining the time family

#### Time Family

A 64 bit counter running with a base frequency is being used to express the time. It has a start time (`epoch`), that is send with the stream related time meta information.
different frequencies, so called time families, can be used to accomodate specific requirements.

The base frequency is expressed using prime factor exponents. It works as follows:

f = 2^primeFactorExponent_2 * 3^primeFactorExponent_3 * 5^primeFactorExponent_5 * 7^primeFactorExponent_7 Hz

This calculates a frequency. If the sign of all prime factor exponents is being inverted, the period time is calculated.

T = 2^-primeFactorExponent_2 * 3^-primeFactorExponent_3 * 5^-primeFactorExponent_5 * 7^-primeFactorExponent_7 s

prime factor exponents range form 0 to 255.

##### Examples

44100 Hz = 2^2 * 3^2 * 5^2 * 7^2

65536 Hz = 2^16 * 3^0 * 5^0 * 7^0

#### Linear Time
Equidistant time is described as a [linear implicit rule](#Linear_Rule).
To calculate the absolute time for linear time, there needs to
be an absolute start time and a delta time.
Both can be delivered by a separate, signal specific, meta information.

- The delta is mandatory.
- The absolute time always belongs to the next following value
- The device MUST deliver the absolute time before delivering the first value point.
- The device MUST deliver the absolute time whenever its clock is being set (resynchronization). A new `start` would be send.
- It MAY deliver a new absolute time after a pause or any other abberation in the equidistant time. A new `start` would be send.


~~~~ {.javascript}
{
  "time" : {
    ...
    "rule": "linear",
    "linear": {      
      "start": uint64,
      "delta": uint64
    }
  }
}
~~~~

- `rule`: type of rule
- `linear/start`: The absolute timestamp for the next value point.
- `linear/delta`: The time difference between two value points

#### Explicit Time
Time is delivered as absolute time stamp for each value.

~~~~ {.javascript}
{
  "time" : {
    ...
    "rule": "explicit"
  }
}
~~~~

### Unit Object

to be done:

- Units can be fairly complex ("V" "kg*m/s^2=N" "Nm") they need to be described. 
- Do we use SI units only? (cd, kg, m, s, A, K, mol) (everything is mertic)
- Should the units be understood to make calcultations using them (2500 g = 2.5 kg)
  
## Measured Data

After the meta information describing the signal has been received, measured values are to be interpreted as follows:

- The size of a complete signal value derives from the sum of the sizes of all explicit members
- Members are send in the same sequence as in the meta information describing the signal
- Only members with an explicit rule are transferred.
- Non explicit members are calculated according their rule (i.e. constant, linear). They take no room within the transferred measured data blocks.

  
# Command Interfaces

to be done

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


# Examples for Signal Descriptions

## A Voltage Sensor

The signal has 1 scalar value. Synchronous output rate is 100 Hz

- Each signal value consists of one member
- This member is a scaled 32 bit float base data type which is explicit
- The time is linear.

The device sends the following `signal` meta information.


~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "time" : {
      "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 },
      "rule": "linear",
      "linear": {
        "start": 6790580007803552000
        "delta": 4294967296
      }
    },
    "content" : {
      "name": "voltage",
      "rule": "explicit",
      "dataType": "float",
      "interpretation": {
        "unit": "V",
      }
    },
    "data": {
      "endian": "little"
    }
  }
}
~~~~

Transferred signal data for one signal value:

A single float value which is the value of this signal. No time stamps.

~~~~
float
~~~~




## A CAN Decoder

The signal has a simple scalar member.

- The value is expressed as a base data type
- The member is explicit.
- The time is explicit.

The device sends the following `signal` meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
	"time" : {
      "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 }
      "rule": "explicit",
    },
    "content" : {
	  "name": "decoder",
	  "rule": "explicit",
	  "dataType": "uint32",
	  "interpretation": {
        "unit": "decoder unit",
      }
    },
    "data": {
      "endian": "little"
	}
  }
}
~~~~


Transferred signal data for one signal value:

~~~~
time stamp (uint64)
uint32
~~~~


## A Simple Counter

This is for counting events that happens at any time (explicit rule).

- The signal value is expressed as a base data type
- The member `counter` is linear with an increment of 2, it runs in one direction
- The device sends an initial absolute value of `counter` within the meta information describing the signal.
- `time` is explicit.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
	"time" : {
      "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 }
      "rule": "explicit",
    },
    "content" : {
      "name": "counter",
      "dataType": "uint32",
      "rule" : "linear",
      "linear": {
        "start" : 0,
        "delta" : 2
      }
    },
    "data": {
      "endian": "little"
	}
  }
}
~~~~

`counter` has a linear rule with a step width of 2, hence `counter` won't be transferred.

Transferred signal data for one signal value:

~~~~
time stamp (uint64)
~~~~


## An Absolute Rotary Encoder

- The signal value is expressed as a base data type
- `angle` is explicit, it can go back and forth
- `time` is explicit.

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
  	"time" : {
      "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 }
      "rule": "explicit",
    },
    "content" : {
      "name": "angle",
      "rule": "explicit",
      "dataType": "double"
    },
    "data": {
      "endian": "little"
    }
  }
}
~~~~

Transferred signal data for one signal value:
One absolute time stamp the angle.

~~~~
time stamp (uint64)
angle (double)
~~~~



## An Incremental Rotary Encoder with start Position

- The signal value is expressed as a base data type
- The counter representing the angle follows a linear rule, it can go back and forth
- Absolute start position when crossing a start position.
- No initial absolute value.
- The `time` is explicit.


~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
   	"time" : {
      "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 }
      "rule": "explicit",
    },
    "content" : {
      "name": "angle",
      "rule": "linear",
      "linear": {
        "delta": 1
      },
      "dataType": "int32"
    },
    "data": {
      "endian": "little"
    }
  }
}
~~~~


This is similar to the simple counter. 
`angle` changes by a known amount of 1. Only time stamps are being transferred.

Transferred signal data for one signal value:

~~~~
time stamp (uint64)
~~~~



We get a (partial) meta information with a `start` value of the counter every time the zero index is being crossed:

~~~~ {.javascript}
{
  "method": "signal",
  "params" : {
    "content" : {
      "linear" : {
        "start" : 0
      }
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


Several amplitude values over the frequency.
We combine array, struct and base data types.

In addition the example shows the `interpretation` object which helps the client to inteprete the data.

~~~~ {.javascript}
{
  "time" : {
    "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 }
    "rule": "explicit",
  },
  "content" : {
    "name": "spectrum",
    "interpretation" : {
      "type": "spectrum"
    },
    "dataType" : "array",
    "array": {
      "count": 1024,
      "dataType" : "struct",
      "struct": [
        {
          "name": "amplitude",
          "dataType": "double",
          "rule": "explicit",
          "interpretation": {
            "unit": "dB"
          },
        },
        {
          "name": "frequency",
          "dataType": "double",
          "rule": "linear",
          "linear": {
            "delta": 10.0,
            "start": 1000.0
          },
          "interpretation": {
            "unit": "Hz"
          }
        }
      ]
    }
  },
  "data": {
    "endian": "little"
  }
}
~~~~

- `interpretation/type`: Depending on the type, the client expects a specified structure.
- `array/count`: The number of points in each spectrum
- struct member `amplitude`: Describes the measured values (i.e. amplitude, attenuation).
- struct member `frequency`: Describes the range in the spectral domain (i.e. frequency)

Only struct member `amplitude` is explicit, hence this is the data to be transferred.


Transferred signal data for one signal value:
One absolute time stamp followed by 1024 amplitude double values. There will be no frequency values because they are implicit.


~~~~
time stamp (uint64)
spectrum amplitude 1 (double)
spectrum amplitude 2 (double)
...
spectrum amplitude 1024 (double)
~~~~



## An Optical Spectrum with Peak Values

The signal consists of a spectum and an array of peak values. Number of peaks is fixed 16.
If the number of peaks does change, there will be a meta information telling about the new amount (`count`) of peaks!

Meta information describing the signal:

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "time" : {
      "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 }
      "rule": "explicit",
    }, 
    "content" : {
      "name": "spectrumWithPeakValues",
      "interpretation" : {
        "type": "spectrumWithPeakValues"
      },
      "struct": [
        {
          "name": "spectrum",
          "interpretation" : { 
            "type": "spectrum"
          },
          "dataType": "array",
          "array": {
            "count": 100,
            "dataType": "struct",
            "struct": [
              {
                "name": "amplitude",
                "dataType": "double",
                "rule": "explicit",
                "interpretation": {
                  "unit": "dB"
                }
              },
              {
                "name": "frequency",
                "dataType": "double",
                "rule": "linear",
                "linear": {
                  "delta": 10,
                  "start": 1000
                },
                "interpretation": {
                  "unit": "Hz"
                }
              }
            ]
          }
        },
        {
          "name": "peakValues",
          "dataType": "array",
          "array": {
            "count": 16,
            "dataType": "struct",
            "struct": [
              {
                "name": "frequency",
                "dataType": "double",
                "rule": "explicit",
                "interpretation": {
                  "unit": "Hz"
                }
              },
              {
                "name": "amplitude",
                "dataType": "double",
                "rule": "explicit",
                "interpretation": {
                  "unit": "dB"
                }
              }
            ]
          }
        }
      ]
    },
    "data": {
      "endian": "little"
    }   
  }
}
~~~~


Transferred signal data for one signal value:

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




## Statistics {#Statistics}

Statistics consists of N "counters" each covering a value interval. If the signal value is within a counter interval, then that counter is incremented.
For instance the interval from 50 to 99 dB might be covered by 50 counters. Each of these counters then would cover 1 dB.

Often there also is a lower than lowest and higher than highest counter, and for performance reasons, there might be a total counter.


Example: 50 - 99 dB statistics:
It is made up of a struct containing an histogram with 50 classes (bins) and three additional counters for the lower than, higher than and total count.

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "time" : {
      "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 }
      "rule": "explicit",
    },
    "content" : {
      "name": "soundLevelStatistics",
      "interpretation" : { 
        "type": "statistic"
      },
      "dataType": "struct",
      "struct": [
        {
          "name": "histogram",
          "interpretation" : { 
            "type": "histogram"
          },
          "dataType": "array",
          "array": {
            "count": 50,
            "dataType": "struct",
            "struct": [
              {
                "name": "count",
                "dataType": "uint64",
                "rule": "explicit"
              },
              {
                "name": "class",
                "dataType": "double",
                "rule": "linear",
                "linear": {
                  "delta": 1,
                  "start": 50
                },
                "interpretation": {
                  "unit": "Hz"
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
    },
    "data": {
      "endian": "little"
    }
  }
}
~~~~

Within there is a object describing a histrogram. It has the following members:
- `interpretation/type`: Depending on the type, the client expects a specified structure.
- `array/count`: The number of classes in each histogram
- struct member `count`: Value of the counter
- struct member `class`: Class

It has its own `interpretation` object.


Transferred signal data for one signal value:

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

## Run up

This is an array of 15 structs containing a FFT and a frequency.
FFT amplitudes and frenqeuncy are explicit.

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "time" : {
      "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 }
      "rule": "explicit",
    },
    "content" : {
      "name": "run up",
      "dataType" : "array",
      "array": {
        "count": 15,
        "dataType" : "struct",
        "struct": [
          {
            "name": "frequency",
            "dataType": "double",
            "rule": "explicit"
          },
          {
            "name": "fft",
            "interpretation": {
              "type": "autoSpectrum"
            },
            "dataType" : "array",
            "array": {
              "count": 100,
              "dataType" : "struct",
              "struct": [
                {
                  "name": "amplitude",
                  "dataType": "double",
                  "rule": "explicit"
                  "interpretation": {
                    "unit": "dB"
                  }
                },
                {
                  "name": "frequency",
                  "dataType": "double",
                  "rule": "linear",
                  "linear": {
                    "delta": 10,
                    "start": 1000
                  },
                  "interpretation": {
                    "unit": "Hz"
                  }
                }
              ]
            }
          }
        ]
      }
    },
    "data": {
      "endian": "little"
    }
  }
}
~~~~


Transferred signal data for one signal value:
One absolute time stamp followed by 15 frequencies with the corresponding spectra containing 100 amplitude values each.

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

## Point in Cartesian Space

Depending on the the number of dimensions n, 
The value is a struct of n double values. In this example we choose 3 dimensions x, y, and z.

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "time" : {
      "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 }
      "rule": "explicit",
    },    
    "content": {
      "name": "coordinate",
      "interpretation" : {
        "type": "cartesianCoordinate"
      },
      "dataType": "struct",
      "struct": [
        {
          "name": "x",
          "dataType": "double",
          "rule": "explicit",
          "interpretation": {
            "unit": "m"
          }
        },
        {
          "name": "y",
          "dataType": "double",
          "rule": "explicit",
          "interpretation": {
            "unit": "m"
          }
        },
        {
          "name": "z",
          "dataType": "double",
          "rule": "explicit",
          "interpretation": {
            "unit": "m"
          }
        }
      ]
    },
    "data": {
      "endian": "little"
    }    
  }
}
~~~~

Transferred signal data for one signal value: One absolute time stamp and three double values.

~~~~
time stamp (uint64)
x (double)
y (double)
z (double)
~~~~



## Harmonic Analysis

The result delivered from harmonic analysis done by HBK Genesis/Perception is fairly complex.
One combined value consists of the following:
- some scalar values
  * distortion: The Total Harmonic Distortion (according to IEC 61000-4-7).
  * fundamental frquency: Average fundamental frequency.
  
          "dataType": "double",* dcAmplitude: The amplitude of the DC component.
  * cycleCount: The number of cycles in the window (according to IEC 61000-4-7)
- a dynamic array of structures with information about the harmonics.
  * amplitude: Amplitude of the n-th harmonics
  * phase: Phase of the n-th harmonics

All elements are explicit.

We'll get the following signal specific meta information:

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "time" : {
      "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 }
      "rule": "explicit",
    },
    "content": {
      "name": "harmonicAnalysis",
      "interpretation": {
        "type": "harmonicAnalysis"
      },
      "dataType": "struct",
      "struct": [
        {
          "name": "distortion",
          "dataType": "double",
          "rule": "explicit"
        },
        {
          "name": "fundamentalFrequency",
          "dataType": "double",
          "rule": "explicit",
          "interpretation": {
            "unit": "Hz"
          }
        },
        {
          "name": "dcAmplitude",
          "dataType": "double",
          "rule": "explicit",
          "interpretation": {
            "unit": "V"
          }
        },
        {
          "name": "cycleCount",
          "dataType": "uint32",
          "rule": "explicit"
        },
        {
          "name": "harmonics",
          "dataType": "dynamicArray",
          "dynamicArray": {
            "struct": [
              {
                "name": "amplitude",
                "dataType": "double",
                "rule": "explicit"
              },
              {
                "name": "phase",
                "dataType": "double",
                "rule": "explicit"
                "interpretation": {
                  "unit": "rad"
                }
              }
            ]
          }
        }
      ]
    },
    "data": {
      "endian": "little"
    }
  }
}
~~~~

Transferred signal data for one signal value:

- 1 time stamp as uint64
- a double value distortion
- a double value fundemantal frequency
- a double value with the dc amplitude
- an unsigned integer with the cycle count
- dynamic array member count n
- dynamic array with n harmonic structs each containing:
  * a double value with the amplitude of the harmonic
  * a double value with the phase of the harmonic
  
  
~~~~
time stamp (uint64)
distortion (double)
fundamental frequency (double)
dc amplitude (double)
cycle count (uint32)

harmonic array member count n (uint32)  
harmonic 1
amplitude of harmonic 1 (double)
phase of harmonic 1 (double)
harmonic 2
amplitude of harmonic 2 (double)
phase of harmonic 2 (double)
...
harmonic n
amplitude of harmonic n (double)
phase of harmonic n (double)
~~~~
  
## Binary data of variable length (Binary Large Object)

This can be used to transfer any binary data of variable length. Each `dynamicArray` will tell about its actual member count.

~~~~ {.javascript}
{
  "method": "signal",
  "params": {
    "time" : {
      "timeFamily" : { "2" : 32, "3" : 0, "5" : 0, "7" : 0 }
      "rule": "explicit"
    },
    "content": {    
      "name": "blob",
      "interpretation": {
        "type": "blob"
      },
      "dataType": "dynamicArray",
      "dynamicArray": {
        "name": "bytes",
        "dataType": uint8,
        "rule": "explicit"
      }
    },
    "data": {
      "endian": "little"
    }
  }
}
~~~~

Transferred signal data for one signal value:

- 1 time stamp as uint64
- dynamic array with n characters

time stamp (uint64)
string length n (uint32)  
n bytes of binary data

# Todo

- More discussion about details concerning [Time Meta Information](#time-meta-information) and [Synchronization Meta Information](#synchronization-meta-information)
