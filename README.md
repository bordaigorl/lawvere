# Lawvere

> Programming in categories

Lawvere is a categorical programming language with sketches and effects. It allows you to program morphisms in arbitrary cartesian closed categories, allows you to define locally finitely presentable categories, and allows you to define functors between these categories.

---

## TODO

- Implement more general diagrams and limits/colimits thereof.
- Make example showing extensible data programming, e.g. let-desugaring as a cartesian retract.
- Make a small but not just a few lines "real program".
- allow one to define morphisms via curry/uncurry.
- Think about if diagrams (which are used for e.g. (co)limits) can be
  represented as functors directly (from discrete categories).

---

## Some random notes:

```
((a -> b) * a) -> b


trash : a -> {}
= <{}


List a = Empty {}
       | Cons {head: a, tail: List a}

List a = colim{ empty: {},
}

map : lim{ f: Int -> Int, xs : colim{empty: {}, cons: {head: a, tail: List a}} } -> List Int

{f} * (empty{} + cons{head, tail})


empty{f} + cons{f, head, tail}

F * (1 + X)

A * B * C(X + Y + Z) * D    

distr C

  A * B * D * X
+ A * B * D * Y
+ A * B * D * Z

lim{A:, B:, C: colim{X:, Y:, Z:}, D:}

|
v

colim
{X: lim{A:, B:, D:, C:}
 Y: lim{A:, B:, D:, C:}
 Z: lim{A:, B:, D:, C:}
}

colim
{empty: {f: a -> b, xs: {} }
 cons:  {f: a -> b, xs: {head: a, tail: List a} }
}                                                      -> List Int


>{ empty: empty.
   cons: _ cons.
  }


{f: Int -> Int, cons: {head: a, tail: List a} } -> List a




<{ head: .xs .head .f,
   tail: {f: .f, xs: .xs .tail} map}
 .cons



map(f, xs) =
  case xs of
    [] -> []
    (head:tail) -> cons (f head) (map(f,tail))

---

{f: a -> b, xs: {head: a, tail: List a} } -> {head: _, tail: _}

<{ head: .xs .head .f,
   tail: {f: .f, xs: .xs .tail} map}
 .cons


get : {} -> Int
set : Int -> {}


get <{ current : id, next : incr set } current


extension
  get : {} -> Int

  get : {} -> IO Int


Hask

get : String -> Maybe Int
```

```
<{ m = isEven }
```


```
extension CanFail
  error : String -> Void

absurd : Void -> a = >{}

isEven Int -> Int =
  <{_1 = , _2 = 2}
  divRem
  <{div, isZeroRem = .rem <{ _1 = , _2 = 0} eq}
  @isZeroRem
  >{ true = .div,
     false = "was not even" error absurd }

foo : {m : Int, n : Int} -> Int =
  <{ m = isEven, n = isEven } <{ _1 = .m, _2 = .n } plus


```



```
<{ m = }
```

