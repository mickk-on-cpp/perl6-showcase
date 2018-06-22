.. type:: template<Variable Proj, Variable Equiv, Saveable Ctx> \
          group_range = bounded_context<group_context<Proj, Equiv, Ctx>>

    :notation:
        .. type:: peek_t = peek_element_t<Ctx>
        .. type:: proj_t = safe_t<result<meta::as_const<Proj&>, peek_t>>

    :additional requirements:
      `SameType\<position_t\<Ctx\>, sentinel_t\<Ctx\>\> <SameType>`

      `Invokable\<meta::as_const\<Proj&\>, peek_t\> <Invokable>`

      `Copyable\<optional\<proj_t\>\> <Copyable>`

      `Equivalence\<meta::as_const\<Equiv&\>, meta::as_const\<proj_t&\>, proj_t\> <Equivalence>`

.. var:: constexpr functors::group group

    .. warning:: |experimental-feature|

    |simple-range-function|

      `template<Variable Proj, Variable Equiv, Saveable Ctx> group_range`

    .. function:: template<ForwardableType Proj, ForwardableType Equiv, MoveConstructible Rng> \
                  constexpr group_range<Proj, Equiv, context_t<Rng>> operator()(Proj&& proj, Equiv&& equiv, Rng rng) const

        :notation:
            .. type:: Ctx = context_t<Rng>
            .. type:: peek_t = peek_element_t<Ctx>
            .. type:: proj_t = safe_t<result<meta::as_const<Proj&>, peek_t>>
            .. var::  auto&& ctx = rng.context

        Create a range over the successive groupings of *rng*. A grouping is a subrange of consecutive elements with
        a common property or aspect called the criterion. For each element of *rng* the criterion can
        be examined with *proj*, and *equiv* is used to establish equivalence of criteria::

            auto classes = group([](auto i) { return i / 3; }, std::equal_to<> {}, ints());

        (See `ints`.)

        In this example the first element of *classes* is the grouping :math:`\left\{ 0, 1, 2 \right\}` because all
        three elements are of the form :math:`0 \times 3 + k \left(0 \le k \lt 3\right)`. It is followed by the
        grouping :math:`\left\{ 3, 4, 5 \right\}` which elements are of the form :math:`1 \times 3 + k`, and so on.

        If the elements of *rng* are sorted with respect to their criteria according to an ordering compatible with
        *equiv*, then the result of `group` is a range over the equivalence classes induced by *proj* and *equiv*.

        .. table:: |equivalents|
            :class: collapsed

            +------------+---------------------------------------------------------------------------------------+
            | Loops      | .. code-block:: C++                                                                   |
            |            |                                                                                       |
            |            |     auto it   = begin(xs);                                                            |
            |            |     auto last = end(xs);                                                              |
            |            |     auto grouping = it;                                                               |
            |            |     for(; it != last;) {                                                              |
            |            |                                                                                       |
            |            |         auto const& current_criterion = proj(*it);                                    |
            |            |                                                                                       |
            |            |         // start of grouping                                                          |
            |            |         for(; it != last && equiv(current_criterion, proj(*it)); ++it) {              |
            |            |             use(*it);                                                                 |
            |            |         }                                                                             |
            |            |         // end of grouping                                                            |
            |            |     }                                                                                 |
            +------------+---------------------------------------------------------------------------------------+
            | D          | .. code-block:: D                                                                     |
            |            |                                                                                       |
            |            |     // only sorted ranges may be grouped                                              |
            |            |     // sorting requires an order (here, rel instead of equiv)                         |
            |            |     // and not just an equivalence                                                    |
            |            |     sort!((lhs, rhs) => rel(proj(lhs), proj(rhs))(xs).groupBy()                       |
            +------------+---------------------------------------------------------------------------------------+
            | Rust       | .. code-block:: rust                                                                  |
            |            |                                                                                       |
            |            |     use itertools::Itertools;                                                         |
            |            |     // no direct way of specifying equiv                                              |
            |            |     xs.group_by(proj)                                                                 |
            +------------+---------------------------------------------------------------------------------------+
            | Haskell    | .. code-block:: haskell                                                               |
            |            |                                                                                       |
            |            |     import Data.List (groupBy)                                                        |
            |            |     import Data.Function (on)                                                         |
            |            |     -- on g f = \x y -> g (f x) (f y)                                                 |
            |            |     groupBy (equiv `on` proj) xs                                                      |
            +------------+---------------------------------------------------------------------------------------+
            | Python     | .. code-block:: python                                                                |
            |            |                                                                                       |
            |            |     # functools.cmp_to_key can be used when a custom comparison is wanted             |
            |            |     itertools.groupby(xs, key=proj)                                                   |
            +------------+---------------------------------------------------------------------------------------+
            | C#         | .. code-block:: C#                                                                    |
            |            |                                                                                       |
            |            |     // no direct way of specifying equiv                                              |
            |            |     xs.GroupBy(proj)                                                                  |
            +------------+---------------------------------------------------------------------------------------+

        :param proj:
          A projection to select the criterion of each *rng* element which will be compared for equivalence.
          Consequently, must satisfy `Invokable\<meta::as_const\<Proj&\>, peek_t\> <Invokable>`.
        :param equiv:
          An equivalence relation over the criteria of the *rng* elements. Consequently, must satisfy
          `Equivalence\<meta::as_const\<Equiv&\>, meta::as_const\<proj_t&\>, proj_t\> <Equivalence>`.
        :param rng: `Saveable` `Range`. Additionally, ``proj_t`` must be a reference type or model `Copyable`.
        :models:
          `Range` with the following |range-properties|:

          +------------+-------------------------------------------------------------------------------------+
          | Element    | a subrange, see below                                                               |
          | types      |                                                                                     |
          +------------+-------------------------------------------------------------------------------------+
          | Traversal  | `BidirectionalContext` if `Ctx` is bidirectional, else `MultipassContext`           |
          +------------+-------------------------------------------------------------------------------------+
          | Saveable   | if and only if `Proj` and `Equiv` model `CopyConstructible`                         |
          |            |                                                                                     |
          +------------+-------------------------------------------------------------------------------------+

          The |range-properties| for the subrange are as follows:

          +------------+-------------------------------------------------------------------------------------+
          | Element    | same as `Ctx`                                                                       |
          | types      |                                                                                     |
          +------------+-------------------------------------------------------------------------------------+
          | Traversal  | same as `Ctx`                                                                       |
          |            |                                                                                     |
          +------------+-------------------------------------------------------------------------------------+
          | Saveable   | yes                                                                                 |
          |            |                                                                                     |
          +------------+-------------------------------------------------------------------------------------+
        :additional construction complexity:
          Linear time with respect to the number of elements of *ctx*.
        :simple context members:
          ``grouping_projection``: *proj*

          ``grouping_equivalence``: *equiv*

          ``grouped_context``: *ctx*

    .. function:: MoveConstructible{Rng} \
                  constexpr group_range<functors::forward, functors::equal_to, context_t<Rng>> operator()(Rng rng) const

        Create a range over the successive groupings of elements of *rng* that compare equal. Equivalent to
        `operator()(functors::forward {}, functors::equal_to {}, std::move(rng)) <operator()>`.

        :param rng: `Saveable` `Range` of `EqualityComparable` elements. Additionally, the elements must be
          references or model `Copyable`.

.. var:: constexpr functors::group_by group_by

    |range-function|

    .. function:: template<ForwardableType Proj, MoveConstructible Rng> \
                  constexpr group_range<Proj, functors::equal_to, context_t<Rng>> operator()(Proj&& proj, Rng rng) const

        A shorter variant of `group` where only the projection is specified, and the resulting projected property or
        aspect of the elements of *rng* is equality compared. Equivalent to `group(std::forward\<Proj\>(proj),
        functors::equal_to {}, std::move(rng)) <group::operator()>`.

