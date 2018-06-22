#ifndef ANNEX_RANGE_TRANSFORMATION_GROUP_HPP_INCLUDED
#define ANNEX_RANGE_TRANSFORMATION_GROUP_HPP_INCLUDED

#include "annex/ref.hpp"
#include "annex/data/optional/optional.hpp"
#include "annex/range/range.hpp"

namespace annex::range {

namespace functors { struct group; }

template<Variable Proj, Variable Equiv, Saveable Ctx>
    requires
        SameType<position_t<Ctx>, sentinel_t<Ctx>>
        && Invokable<meta::as_const<Proj&>, peek_element_t<Ctx>>
        && Copyable<optional<safe_t<result<meta::as_const<Proj&>, peek_element_t<Ctx>>>>>
        && Equivalence<meta::as_const<Equiv&>, meta::as_const<result<meta::as_const<Proj&>, peek_element_t<Ctx>>&>, result<meta::as_const<Proj&>, peek_element_t<Ctx>>>
struct group_context {
    Proj grouping_projection;
    Equiv grouping_equivalence;
    Ctx grouped_context;

private:
    friend functors::group;
    using criterion_type = safe_t<result<meta::as_const<Proj&>, peek_element_t<Ctx>>>;
    sentinel_t<Ctx> end;

    constexpr group_context(Proj proj, Equiv equiv, Ctx ctx, sentinel_t<Ctx> end)
        : grouping_projection(std::forward<Proj>(proj))
        , grouping_equivalence(std::forward<Equiv>(equiv))
        , grouped_context(std::forward<Ctx>(ctx))
        , end(std::move(end))
    {}

public:
    struct position_type {
    private:
        friend functors::group;
        friend group_context;

        position_t<Ctx> start, stop;
        optional<criterion_type> criterion;

        constexpr position_type(position_t<Ctx> start, position_t<Ctx> stop, optional<criterion_type> criterion)
            : start(std::move(start))
            , stop(std::move(stop))
            , criterion(std::move(criterion))
        {}
    };

    struct sentinel_type: private impl::move_only_position_unless<meta::bool_<Copyable<sentinel_t<Ctx>>>> {
    private:
        friend functors::group;
        friend group_context;
        constexpr sentinel_type() = default;
    };

private:
    constexpr bool equivalent(criterion_type& criterion, position_t<Ctx> const& pos)
    {
        return invoke(as_const(grouping_equivalence), as_const(criterion),
                      invoke(as_const(grouping_projection), range::peek_at(grouped_context, pos)) );
    }

    constexpr position_t<Ctx> next_grouping(criterion_type& criterion, position_t<Ctx> pos)
    {
        range::incr(grouped_context, pos);
        for(; !range::equal_pos(grouped_context, pos, end); range::incr(grouped_context, pos)) {
            if(!equivalent(criterion, pos)) {
                break;
            }
        }

        return pos;
    }

public:
    constexpr bool equal_pos(position_type const& x, position_type const& y)
    { return range::equal_pos(grouped_context, x.start, y.start) && range::equal_pos(grouped_context, x.stop, y.stop); }
    constexpr bool equal_pos(position_type const& x, sentinel_type const&)
    { return range::equal_pos(grouped_context, x.start, end) && range::equal_pos(grouped_context, x.stop, end); }
    constexpr bool equal_pos(sentinel_type const&, sentinel_type const&)
    { return true; }

    constexpr bounded_context<Ctx> at(position_type const& pos)
    { return { grouped_context, pos.start, pos.stop }; }

    constexpr void incr(position_type& pos)
    {
        if(!range::equal_pos(grouped_context, pos.stop, end)) {
            pos.criterion.emplace(range::peek_at(grouped_context, pos.stop));
            pos.start = std::exchange(pos.stop, next_grouping(*pos.criterion, pos.stop));
        } else {
            pos.start = pos.stop;
        }
    }
};

template<Variable Proj, Variable Equiv, Context Ctx>
    requires
        SameType<position_t<Ctx>, sentinel_t<Ctx>>
        && Invokable<meta::as_const<Proj&>, peek_element_t<Ctx>>
        && Copyable<optional<safe_t<result<meta::as_const<Proj&>, peek_element_t<Ctx>>>>>
        && Equivalence<meta::as_const<Equiv&>, meta::as_const<result<meta::as_const<Proj&>, peek_element_t<Ctx>>&>, result<meta::as_const<Proj&>, peek_element_t<Ctx>>>
        && Saveable<Ctx>
        && BidirectionalContext<Ctx>
struct group_context<Proj, Equiv, Ctx> {
    Proj grouping_projection;
    Equiv grouping_equivalence;
    Ctx grouped_context;

private:
    friend functors::group;
    using criterion_type = safe_t<result<meta::as_const<Proj&>, peek_element_t<Ctx>>>;
    position_t<Ctx> start, end;

    constexpr group_context(Proj proj, Equiv equiv, Ctx ctx, position_t<Ctx> start, position_t<Ctx> end)
        : grouping_projection(std::forward<Proj>(proj))
        , grouping_equivalence(std::forward<Equiv>(equiv))
        , grouped_context(std::forward<Ctx>(ctx))
        , start(std::move(start))
        , end(std::move(end))
    {}

public:
    struct position_type {
    private:
        friend functors::group;
        friend group_context;

        position_t<Ctx> start, stop;
        optional<criterion_type> criterion;

        constexpr position_type(position_t<Ctx> start, position_t<Ctx> stop, optional<criterion_type> criterion)
            : start(std::move(start))
            , stop(std::move(stop))
            , criterion(std::move(criterion))
        {}
    };

private:
    constexpr bool equivalent(criterion_type& criterion, position_t<Ctx> const& pos)
    {
        return invoke(as_const(grouping_equivalence), as_const(criterion),
                      invoke(as_const(grouping_projection), range::peek_at(grouped_context, pos)) );
    }

    constexpr bool equivalent_before(criterion_type const& criterion, position_t<Ctx> const& pos)
    {
        return invoke(as_const(grouping_equivalence), criterion,
                      invoke(as_const(grouping_projection), range::peek_before(grouped_context, pos)) );
    }

    constexpr position_t<Ctx> next_grouping(criterion_type& criterion, position_t<Ctx> pos)
    {
        range::incr(grouped_context, pos);
        for(; !range::equal_pos(grouped_context, pos, end); range::incr(grouped_context, pos)) {
            if(!equivalent(criterion, pos)) {
                break;
            }
        }

        return pos;
    }

    constexpr position_t<Ctx> prev_grouping(criterion_type& criterion, position_t<Ctx> pos)
    {
        range::decr(grouped_context, pos);
        for(; !range::equal_pos(grouped_context, start, pos); range::decr(grouped_context, pos)) {
            if(!equivalent_before(criterion, pos)) {
                break;
            }
        }

        return pos;
    }

public:
    constexpr bool equal_pos(position_type const& x, position_type const& y)
    {
        return range::equal_pos(grouped_context, x.start, y.start) && range::equal_pos(grouped_context, x.stop, y.stop);
    }

    constexpr bounded_context<Ctx> at(position_type const& pos)
    { return { grouped_context, pos.start, pos.stop }; }

    constexpr void incr(position_type& pos)
    {
        if(!range::equal_pos(grouped_context, pos.stop, end)) {
            pos.criterion.emplace(range::peek_at(grouped_context, pos.stop));
            pos.start = std::exchange(pos.stop, next_grouping(*pos.criterion, pos.stop));
        } else {
            pos.start = pos.stop;
        }
    }

    constexpr void decr(position_type& pos)
    {
        pos.criterion.emplace(range::peek_before(grouped_context, pos.start));
        pos.stop = std::exchange(pos.start, prev_grouping(*pos.criterion, pos.start));
    }
};

/**
 * .. type:: template<Variable Proj, Variable Equiv, Saveable Ctx> \
 *           group_range = bounded_context<group_context<Proj, Equiv, Ctx>>
 *
 *     :notation:
 *         .. type:: peek_t = peek_element_t<Ctx>
 *         .. type:: proj_t = safe_t<result<meta::as_const<Proj&>, peek_t>>
 *
 *     :additional requirements:
 *       `SameType\<position_t\<Ctx\>, sentinel_t\<Ctx\>\> <SameType>`
 *
 *       `Invokable\<meta::as_const\<Proj&\>, peek_t\> <Invokable>`
 *
 *       `Copyable\<optional\<proj_t\>\> <Copyable>`
 *
 *       `Equivalence\<meta::as_const\<Equiv&\>, meta::as_const\<proj_t&\>, proj_t\> <Equivalence>`
 */
template<Variable Proj, Variable Equiv, Saveable Ctx>
using group_range = bounded_context<group_context<Proj, Equiv, Ctx>>;

namespace functors {

/**
 * .. var:: constexpr functors::group group
 *
 *     .. warning:: |experimental-feature|
 *
 *     |simple-range-function|
 *
 *       `template<Variable Proj, Variable Equiv, Saveable Ctx> group_range`
 *
 *     .. function:: template<ForwardableType Proj, ForwardableType Equiv, MoveConstructible Rng> \
 *                   constexpr group_range<Proj, Equiv, context_t<Rng>> operator()(Proj&& proj, Equiv&& equiv, Rng rng) const
 *
 *         :notation:
 *             .. type:: Ctx = context_t<Rng>
 *             .. type:: peek_t = peek_element_t<Ctx>
 *             .. type:: proj_t = safe_t<result<meta::as_const<Proj&>, peek_t>>
 *             .. var::  auto&& ctx = rng.context
 *
 *         Create a range over the successive groupings of *rng*. A grouping is a subrange of consecutive elements with
 *         a common property or aspect called the criterion. For each element of *rng* the criterion can
 *         be examined with *proj*, and *equiv* is used to establish equivalence of criteria::
 *
 *             auto classes = group([](auto i) { return i / 3; }, std::equal_to<> {}, ints());
 *
 *         (See `ints`.)
 *
 *         In this example the first element of *classes* is the grouping :math:`\left\{ 0, 1, 2 \right\}` because all
 *         three elements are of the form :math:`0 \times 3 + k \left(0 \le k \lt 3\right)`. It is followed by the
 *         grouping :math:`\left\{ 3, 4, 5 \right\}` which elements are of the form :math:`1 \times 3 + k`, and so on.
 *
 *         If the elements of *rng* are sorted with respect to their criteria according to an ordering compatible with
 *         *equiv*, then the result of `group` is a range over the equivalence classes induced by *proj* and *equiv*.
 *
 *         .. table:: |equivalents|
 *             :class: collapsed
 *
 *             +------------+---------------------------------------------------------------------------------------+
 *             | Loops      | .. code-block:: C++                                                                   |
 *             |            |                                                                                       |
 *             |            |     auto it   = begin(xs);                                                            |
 *             |            |     auto last = end(xs);                                                              |
 *             |            |     auto grouping = it;                                                               |
 *             |            |     for(; it != last;) {                                                              |
 *             |            |                                                                                       |
 *             |            |         auto const& current_criterion = proj(*it);                                    |
 *             |            |                                                                                       |
 *             |            |         // start of grouping                                                          |
 *             |            |         for(; it != last && equiv(current_criterion, proj(*it)); ++it) {              |
 *             |            |             use(*it);                                                                 |
 *             |            |         }                                                                             |
 *             |            |         // end of grouping                                                            |
 *             |            |     }                                                                                 |
 *             +------------+---------------------------------------------------------------------------------------+
 *             | D          | .. code-block:: D                                                                     |
 *             |            |                                                                                       |
 *             |            |     // only sorted ranges may be grouped                                              |
 *             |            |     // sorting requires an order (here, rel instead of equiv)                         |
 *             |            |     // and not just an equivalence                                                    |
 *             |            |     sort!((lhs, rhs) => rel(proj(lhs), proj(rhs))(xs).groupBy()                       |
 *             +------------+---------------------------------------------------------------------------------------+
 *             | Rust       | .. code-block:: rust                                                                  |
 *             |            |                                                                                       |
 *             |            |     use itertools::Itertools;                                                         |
 *             |            |     // no direct way of specifying equiv                                              |
 *             |            |     xs.group_by(proj)                                                                 |
 *             +------------+---------------------------------------------------------------------------------------+
 *             | Haskell    | .. code-block:: haskell                                                               |
 *             |            |                                                                                       |
 *             |            |     import Data.List (groupBy)                                                        |
 *             |            |     import Data.Function (on)                                                         |
 *             |            |     -- on g f = \x y -> g (f x) (f y)                                                 |
 *             |            |     groupBy (equiv `on` proj) xs                                                      |
 *             +------------+---------------------------------------------------------------------------------------+
 *             | Python     | .. code-block:: python                                                                |
 *             |            |                                                                                       |
 *             |            |     # functools.cmp_to_key can be used when a custom comparison is wanted             |
 *             |            |     itertools.groupby(xs, key=proj)                                                   |
 *             +------------+---------------------------------------------------------------------------------------+
 *             | C#         | .. code-block:: C#                                                                    |
 *             |            |                                                                                       |
 *             |            |     // no direct way of specifying equiv                                              |
 *             |            |     xs.GroupBy(proj)                                                                  |
 *             +------------+---------------------------------------------------------------------------------------+
 *
 *         :param proj:
 *           A projection to select the criterion of each *rng* element which will be compared for equivalence.
 *           Consequently, must satisfy `Invokable\<meta::as_const\<Proj&\>, peek_t\> <Invokable>`.
 *         :param equiv:
 *           An equivalence relation over the criteria of the *rng* elements. Consequently, must satisfy
 *           `Equivalence\<meta::as_const\<Equiv&\>, meta::as_const\<proj_t&\>, proj_t\> <Equivalence>`.
 *         :param rng: `Saveable` `Range`. Additionally, ``proj_t`` must be a reference type or model `Copyable`.
 *         :models:
 *           `Range` with the following |range-properties|:
 *
 *           +------------+-------------------------------------------------------------------------------------+
 *           | Element    | a subrange, see below                                                               |
 *           | types      |                                                                                     |
 *           +------------+-------------------------------------------------------------------------------------+
 *           | Traversal  | `BidirectionalContext` if `Ctx` is bidirectional, else `MultipassContext`           |
 *           +------------+-------------------------------------------------------------------------------------+
 *           | Saveable   | if and only if `Proj` and `Equiv` model `CopyConstructible`                         |
 *           |            |                                                                                     |
 *           +------------+-------------------------------------------------------------------------------------+
 *
 *           The |range-properties| for the subrange are as follows:
 *
 *           +------------+-------------------------------------------------------------------------------------+
 *           | Element    | same as `Ctx`                                                                       |
 *           | types      |                                                                                     |
 *           +------------+-------------------------------------------------------------------------------------+
 *           | Traversal  | same as `Ctx`                                                                       |
 *           |            |                                                                                     |
 *           +------------+-------------------------------------------------------------------------------------+
 *           | Saveable   | yes                                                                                 |
 *           |            |                                                                                     |
 *           +------------+-------------------------------------------------------------------------------------+
 *         :additional construction complexity:
 *           Linear time with respect to the number of elements of *ctx*.
 *         :simple context members:
 *           ``grouping_projection``: *proj*
 *
 *           ``grouping_equivalence``: *equiv*
 *
 *           ``grouped_context``: *ctx*
 *
 *     .. function:: MoveConstructible{Rng} \
 *                   constexpr group_range<functors::forward, functors::equal_to, context_t<Rng>> operator()(Rng rng) const
 *
 *         Create a range over the successive groupings of elements of *rng* that compare equal. Equivalent to
 *         `operator()(functors::forward {}, functors::equal_to {}, std::move(rng)) <operator()>`.
 *
 *         :param rng: `Saveable` `Range` of `EqualityComparable` elements. Additionally, the elements must be
 *           references or model `Copyable`.
 */
struct group: impl::range_function<group> {
    template<ForwardableType Proj, ForwardableType Equiv, MoveConstructible Rng>
    constexpr group_range<Proj, Equiv, context_t<Rng>> operator()(Proj&& proj, Equiv&& equiv, Rng rng) const
        requires Range<Rng>
    {
        auto&& [ctx, from, to] = rng;

        if(range::equal_pos(ctx, from, to)) {
            if constexpr(BidirectionalContext<decltype(ctx)>) {
                return {
                    { std::forward<Proj>(proj), std::forward<Equiv>(equiv), std::move(ctx), from, to },
                    { to, to, {} },
                    { to, std::move(to), {} },
                };
            } else {
                return {
                    { std::forward<Proj>(proj), std::forward<Equiv>(equiv), std::move(ctx), to },
                    { from, from, {} },
                    {},
                };
            }
        }
        auto&& criterion = range::peek_at(ctx, from);
        auto needle = from;
        for(; !range::equal_pos(ctx, needle, to); range::incr(ctx, needle)) {
            if(!annex::invoke(annex::as_const(equiv), criterion,
                              annex::invoke(annex::as_const(proj), range::peek_at(ctx, needle)) )) {
                break;
            }
        }

        if constexpr(BidirectionalContext<decltype(ctx)>) {
            return {
                { std::forward<Proj>(proj), std::forward<Equiv>(equiv), std::move(ctx), from, to },
                { std::move(from), std::move(needle), { std::forward<decltype(criterion)>(criterion) } },
                { to, std::move(to), {} },
            };
        } else {
            return {
                { std::forward<Proj>(proj), std::forward<Equiv>(equiv), std::move(ctx), to },
                { std::move(from), std::move(needle), { std::forward<decltype(criterion)>(criterion) } },
                {},
            };
        }
    }

    MoveConstructible{Rng}
    constexpr group_range<functors::forward, functors::equal_to, context_t<Rng>> operator()(Rng rng) const
        requires Range<Rng>
    { return (*this)(functors::forward {}, functors::equal_to {}, std::move(rng)); }
};

/**
 * .. var:: constexpr functors::group_by group_by
 *
 *     |range-function|
 *
 *     .. function:: template<ForwardableType Proj, MoveConstructible Rng> \
 *                   constexpr group_range<Proj, functors::equal_to, context_t<Rng>> operator()(Proj&& proj, Rng rng) const
 *
 *         A shorter variant of `group` where only the projection is specified, and the resulting projected property or
 *         aspect of the elements of *rng* is equality compared. Equivalent to `group(std::forward\<Proj\>(proj),
 *         functors::equal_to {}, std::move(rng)) <group::operator()>`.
 */
struct group_by: impl::range_function<group_by> {
    template<ForwardableType Proj, MoveConstructible Rng>
    constexpr group_range<Proj, functors::equal_to, context_t<Rng>> operator()(Proj&& proj, Rng rng) const
        requires Range<Rng>
    { return { std::forward<Proj>(proj), {}, std::move(rng) }; }
};

} // functors

inline constexpr functors::group group {};
inline constexpr functors::group_by group_by {};

namespace result_of {
Types{... Args} using group    = decltype( range::group(std::declval<Args>()...) );
Types{... Args} using group_by = decltype( range::group_by(std::declval<Args>()...) );
} // result_of

} // annex::range

#endif /* ANNEX_RANGE_TRANSFORMATION_GROUP_HPP_INCLUDED */
