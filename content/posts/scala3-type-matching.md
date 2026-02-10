---
title: "Scala 3 Type-Level Programming: Pattern Matching on Types"
date: 2024-01-15
draft: true
tags: ["scala", "scala3", "type-level"]
---

Scala 3 introduces powerful new capabilities for type-level programming. One of the most exciting features is the ability to **pattern match directly on types**. In this post, we'll explore this through hands-on exercises.

## Match Types: The Basics

In Scala 3, you can define types that compute other types based on pattern matching. Here's a simple example:

```scala
type Elem[X] = X match
  case String      => Char
  case Array[t]    => t
  case Iterable[t] => t
```

This defines `Elem[X]` as a type that extracts the element type from various container types.

## Exercise 1: Your First Match Type

Let's start simple. Implement a type `IsString[T]` that evaluates to `true` if `T` is `String`, and `false` otherwise.

**Your task:** Replace `???` with your implementation.

{{< scastie scala="3.3.1" >}}
// Implement IsString: should be true for String, false otherwise
type IsString[T] = ???

// ─────────────────────────────────────────────────────────
// Tests - these must compile for your solution to be correct
// ─────────────────────────────────────────────────────────

summon[IsString[String] =:= true]
summon[IsString[Int] =:= false]
summon[IsString[List[String]] =:= false]

@main def run = println("Exercise 1 passed!")
{{< /scastie >}}

<details>
<summary>💡 Hint</summary>

Use a match type with two cases: one for `String` and a catch-all for everything else.

```scala
type IsString[T] = T match
  case ??? => true
  case ??? => false
```

</details>

## Exercise 2: Working with Tuples

Scala 3 has powerful tuple types. Let's implement a type that extracts the first element of a tuple.

**Your task:** Implement `Head[T]` that returns the type of the first element of a tuple.

{{< scastie scala="3.3.1" >}}
// Implement Head: extracts the first element type from a tuple
type Head[T <: NonEmptyTuple] = ???

// ─────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────

summon[Head[(Int, String, Boolean)] =:= Int]
summon[Head[(String, Int)] =:= String]
summon[Head[Tuple1[Double]] =:= Double]

@main def run = println("Exercise 2 passed!")
{{< /scastie >}}

<details>
<summary>💡 Hint</summary>

A non-empty tuple can be decomposed as `h *: t` where `h` is the head and `t` is the tail.

</details>

## Exercise 3: Recursive Type-Level Programming

Now for something more challenging! Implement `Take[T, N]` that returns a tuple containing the first `N` elements of tuple `T`.

**Your task:** Implement a recursive match type.

{{< scastie scala="3.3.1" >}}
import scala.compiletime.ops.int.*

// Implement Take: returns the first N elements of tuple T
type Take[T <: Tuple, N <: Int] = ???

// ─────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────

summon[Take[(Int, String, Boolean), 0] =:= EmptyTuple]
summon[Take[(Int, String, Boolean), 1] =:= Tuple1[Int]]
summon[Take[(Int, String, Boolean), 2] =:= (Int, String)]
summon[Take[(Int, String, Boolean), 3] =:= (Int, String, Boolean)]
summon[Take[EmptyTuple, 0] =:= EmptyTuple]

@main def run = println("Exercise 3 passed!")
{{< /scastie >}}

<details>
<summary>💡 Hint 1</summary>

You'll need to handle three cases:
1. `N` is 0 → return `EmptyTuple`
2. `T` is empty → return `EmptyTuple`
3. Otherwise → take the head and recursively take `N-1` from the tail

</details>

<details>
<summary>💡 Hint 2</summary>

The structure looks like:

```scala
type Take[T <: Tuple, N <: Int] = N match
  case 0 => EmptyTuple
  case _ => T match
    case EmptyTuple => EmptyTuple
    case h *: t => h *: Take[t, N - 1]
```

</details>

## What We Learned

- **Match types** allow computing types through pattern matching
- **Tuple types** in Scala 3 can be decomposed with `h *: t` patterns
- **Recursive match types** enable powerful type-level computations
- The `summon[A =:= B]` pattern is a great way to test type equalities at compile time

## Going Further

The Scala 3 standard library includes many tuple operations like `Tuple.Head`, `Tuple.Tail`, `Tuple.Concat`, etc. Understanding how they work under the hood helps you write your own type-level utilities.

Check out the [Scala 3 reference documentation on Match Types](https://docs.scala-lang.org/scala3/reference/new-types/match-types.html) for more details.
