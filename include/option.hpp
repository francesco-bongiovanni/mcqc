#ifndef OPTIONAL_H
#define OPTIONAL_H
#include <iostream>
#include <optional>
#include <variant>
#include "type_checks.h"

namespace Option {

    template<typename T>
    using option = std::optional<T>;

    template<typename O, typename T = typename std::remove_reference_t<O>::value_type,
             typename Func, typename Func2,
             typename Ret = std::invoke_result_t<Func2>,
             typename = std::enable_if_t<is_same_kind_v<O, option<T>> && "Only match on option types">,
             typename = std::enable_if_t<CallableWith<Func, T>          && "1st argument not callable with T">,
             typename = std::enable_if_t<CallableWith<Func2>            && "2nd argument not callable with void">,
             typename = std::enable_if_t<std::is_same_v<Ret, std::invoke_result_t<Func, T>> && "Arg function return types must match">>
    constexpr Ret match(O&& o, Func f, Func2 g) {
        if (o.has_value()) {
            return f(o.value());
        }
        return g();
    }

    // None
    template<typename T>
    constexpr inline static option<T> none() {
        return option<T>{};
    }

    // Constructive cons, copies t so t can be referenced again
    template<typename T>
    constexpr inline static option<T> some(T t) {
        return option<T>(t);
    }
}
#endif
