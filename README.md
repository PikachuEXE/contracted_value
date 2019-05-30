# ContractedValue

Library for creating contracted immutable(by default) value objects

(Placeholder for badges)

This gem allows creation of value objects which are
- contracted (enforced by `contracts.ruby`(https://github.com/egonSchiele/contracts.ruby)) 
- immutable (enforced by `ice_nine`(https://github.com/dkubb/ice_nine))

See details explanation in below sections


## Installation

Add this line to your application's Gemfile:

```ruby
# `require` can be set to `true` safely without too much side effect
# (except having additional modules & classes defined which could be wasting memory).
# But there is no point requiring it unless in test
# Also maybe add it inside a "group"
gem "contracted_value", require: false
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install contracted_value
```


## Usage

The examples below might contain some of my habbits,  
like including `contracts.ruby` modules in class  
or having code comment as new attribute declaration template  
You **don't** have to do it  


### Attribute Declaration

You can declare with or without contract/default value
But an attribute **cannot** be declared twice

```ruby
# Real world example but namespace is renamed
module ::Geometry
end

module ::Geometry::LocationRange
  class Entry < ::ContractedValue::Value
    include ::Contracts::Core
    include ::Contracts::Builtin

    attribute(
      :latitude,
      contract: Numeric,
    )
    attribute(
      :longitude,
      contract: Numeric,
    )

    attribute(
      :radius_in_meter,
      contract: And[Numeric, Send[:positive?]],
    )

    attribute(
      :latitude,
    ) # => error, declared already
  end
end

location_range = ::Geometry::LocationRange::Entry.new(
  latitude:         22.2,
  longitude:        114.4,
  radius_in_meter:  1234,
)
```


### Attribute Assignment

Only `Hash` and `ContractedValue::Value` can be passed to `.new`

```ruby
module ::Geometry
end

module ::Geometry::Location
  class Entry < ::ContractedValue::Value
    include ::Contracts::Core
    include ::Contracts::Builtin

    attribute(
      :latitude,
      contract: Numeric,
    )
    attribute(
      :longitude,
      contract: Numeric,
    )
  end
end

module ::Geometry::LocationRange
  class Entry < ::ContractedValue::Value
    include ::Contracts::Core
    include ::Contracts::Builtin

    attribute(
      :latitude,
      contract: Numeric,
    )
    attribute(
      :longitude,
      contract: Numeric,
    )

    attribute(
      :radius_in_meter,
      contract: Maybe[And[Numeric, Send[:positive?]]],
      default_value: nil,
    )
  end
end

location = ::Geometry::Location::Entry.new(
  latitude:   22.2,
  longitude:  114.4,
)
location_range = ::Geometry::LocationRange::Entry.new(location)

```


### Input Validation

Input values are validated on object creation (instead of on attribute value access) with 2 validations:
- Value contract
- Value presence

#### Value contract
An attribute can be declared without any contract, and any input value would be pass the validation
But you can pass a contract via `contract` option (must be a `contracts.ruby`(https://github.com/egonSchiele/contracts.ruby) contract)
Passing input value violating an attribute's contract would cause an error

```ruby
class YetAnotherRationalNumber < ::ContractedValue::Value
  include ::Contracts::Core
  include ::Contracts::Builtin

  attribute(
    :numerator,
    contract: ::Integer,
  )
  attribute(
    :denominator,
    contract: And[::Integer, Not[Send[:zero?]]],
  )
end

YetAnotherRationalNumber.new(
  numerator: 1, 
  denominator: 0, 
) # => Error

```

#### Value presence
An attribute declared should be provided a value on object creation, even the input value is `nil`
Otherwise an error is raised
You can pass default value via option `default_value`
The default value will need to confront to the contract passed in `contract` option too


```ruby
# Real world example but namespace is renamed
module ::WhatIsThis
  class Entry < ::ContractedValue::Value
    include ::Contracts::Core
    include ::Contracts::Builtin

    attribute(
      :something_required,
    )
    attribute(
      :something_optional,
      default_value: nil,
    )
    attribute(
      :something_with_error,
      contract: NatPos,
      default_value: 0,
    ) # => error
  end
end

WhatIsThis::Entry.new(
  something_required: 123,
).something_optional # => nil
```


### Object Freezing
All input values are frozen using `ice_nine`(https://github.com/dkubb/ice_nine) by default  
But some objects won't work properly when deeply frozen (rails obviously)  
So you can specify how input value should be frozen (or not frozen) with option `refrigeration_mode`  
Possible values are:
- `:deep` (default)
- `:shallow`
- `:none`

However the value object itself is always frozen  
Any lazy method caching with use of instance var would cause `FrozenError`  
(Many Rails classes use lazy caching heavily so most rails object can't be frozen to work properly)  

```ruby
class SomeDataEntry < ::ContractedValue::Value
  include ::Contracts::Core
  include ::Contracts::Builtin

  attribute(
    :cold_hash,
    contract: ::Hash,
  )
  attribute(
    :cool_hash,
    contract: ::Hash,
    refrigeration_mode: :shallow,
  )
  attribute(
    :warm_hash,
    contract: ::Hash,
    refrigeration_mode: :none,
  )
  
  def cached_hash
    @cached_hash ||= {}
  end
end

entry = SomeDataEntry.new(
  cold_hash: {a: {b: 0}},
  cool_hash: {a: {b: 0}},
  warm_hash: {a: {b: 0}},
)

entry.cold_hash[:a].delete(:b) # => `FrozenError`

entry.cool_hash[:a].delete(:b) # => fine
entry.cool_hash.delete(:a) # => `FrozenError`

entry.warm_hash.delete(:a) # => fine

entry.cached_hash # => `FrozenError`

```


## Related gems
Here is a list of gems which I found and I have tried some of them.  
But eventually I am unsatisfied so I build this gem.  

- [values](https://github.com/tcrayford/values)
- [active_attr](https://github.com/cgriego/active_attr)
- [dry-struct](https://github.com/dry-rb/dry-struct)

### [values](https://github.com/tcrayford/values)
I used to use this a bit  
But I keep having to write the attribute names in `Values.new`,  
then the same attribute names again with `attr_reader` + contract (since I want to use contract)  
Also the input validation happens on attribute value access instead of on object creation  

### [active_attr](https://github.com/cgriego/active_attr)
Got similar issue as `values`  

### [dry-struct](https://github.com/dry-rb/dry-struct)
Seems more suitable for form objects instead of just value objects (for me)  


## Contributing

1. Fork it ( https://github.com/PikachuEXE/contracted_value/fork )
2. Create your branch (Preferred to be prefixed with `feature`/`fix`/other sensible prefixes)
3. Commit your changes (No version related changes will be accepted)
4. Push to the branch on your forked repo
5. Create a new Pull Request
