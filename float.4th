\ Floating point arithmetic

( Cheating for now by using forth.jl CODE/END-CODE to
  access Julia's floating point support.  This isn't
  at all portable.  That said, the year is 2016 and most
  CPUs implement these operations - even the trig functions,
  so I don't feel too bad! )

CODE f+
    b = reinterpret(Float64, popPS())
    a = reinterpret(Float64, popPS())
    pushPS(reinterpret(Int64, a+b))
END-CODE

CODE f-
    b = reinterpret(Float64, popPS())
    a = reinterpret(Float64, popPS())
    pushPS(reinterpret(Int64, a-b))
END-CODE

CODE f*
    b = reinterpret(Float64, popPS())
    a = reinterpret(Float64, popPS())
    pushPS(reinterpret(Int64, a*b))
END-CODE

CODE f/
    b = reinterpret(Float64, popPS())
    a = reinterpret(Float64, popPS())
    pushPS(reinterpret(Int64, a/b))
END-CODE

( addr len -- float )
CODE float-parse
    len = popPS()
    addr = popPS()
    val = parse(Float64, getString(addr, len))
    pushPS(reinterpret(Int64, val))
END-CODE

( float -- )
CODE float-print
    print(reinterpret(Float64, popPS()))
END-CODE