// Copyright 2023 Leedehai
// Use of this code is governed by a MIT license in the LICENSE.txt file.
// Current version: 0.7.2. Please see physics-manual.pdf for user docs.

// Returns whether a Content object holds an integer. The caller is responsible
// for ensuring the input argument is a Content object.
#let __content_holds_number(content) = {
  return content.func() == text and regex("^\d+$") in content.text
}

// Given a Content generated from lr(), return the array of sub Content objects.
// Example: "[1,a_1,(1,1),n+1]" => "1", "a_1", "(1,1)", "n+1"
#let __extract_array_contents(content) = {
  assert(type(content) == "content", message: "expecting a content type input")
  if content.func() != math.lr { return none }
  // A Content object made by lr() definitely has a "body" field, and a
  // "children" field underneath it. It holds an array of Content objects,
  // starting with a Content holding "(" and ending with a Content holding ")".
  let children = content.at("body").at("children")

  let result_elements = ()  // array of Content objects

  // Skip the delimiters at the two ends.
  let inner_children = children.slice(1, children.len() - 1)
  // "a_1", "(1,1)" are all recognized as one AST node, respectively,
  // because they are syntactically meaningful in Typst. However, things like
  // "a+b", "a*b" are recognized as 3 nodes, respectively, because in Typst's
  // view they are just plain sequences of symbols. We need to join the symbols.
  let current_element_pieces = ()  // array of Content objects
  for i in range(inner_children.len()) {
    let e = inner_children.at(i)
    if e == [ ] or e == [] { continue; }
    if e != [,] { current_element_pieces.push(e) }
    if e == [,] or (i == inner_children.len() - 1) {
      if current_element_pieces.len() > 0 {
        result_elements.push(current_element_pieces.join())
        current_element_pieces = ()
      }
      continue;
    }
  }

  return result_elements;
}

// A bare-minimum-effort symbolic addition.
#let __bare_minimum_effort_symbolic_add(elements) = {
  assert(type(elements) == "array", message: "expecting an array of content")
  let operands = ()  // array
  for e in elements {
    if not e.has("children") {
      operands.push(e)
      continue
    }

    // The elements is like "a+b" where there are multiple operands ("a", "b").
    let current_operand = ()
    let children = e.at("children")
    for i in range(children.len()) {
      let child = children.at(i)
      if child == [+] {
        operands.push(current_operand.join())
        current_operand = ()
        continue;
      }
      current_operand.push(child)
    }
    operands.push(current_operand.join())
  }

  let num_sum = 0
  let map_id_to_sym = (:)  // dictionary, symbol repr to symbol
  let map_id_to_sym_sum = (:)  // dictionary, symbol repr to number
  for e in operands {
    if __content_holds_number(e) {
      num_sum += int(e.text)
      continue
    }
    let is_num_times_sth = (
      e.has("children") and __content_holds_number(e.at("children").at(0)))
    if is_num_times_sth {
      let leading_num = int(e.at("children").at(0).text)
      let sym = e.at("children").slice(1).join()  // join to one symbol
      let sym_id = repr(sym)  // string
      if sym_id in map_id_to_sym {
        let sym_sum_so_far = map_id_to_sym_sum.at(sym_id)  // number
        map_id_to_sym_sum.insert(sym_id, sym_sum_so_far + leading_num)
      } else {
        map_id_to_sym.insert(sym_id, sym)
        map_id_to_sym_sum.insert(sym_id, leading_num)
      }
    } else {
      let sym = e
      let sym_id = repr(sym)  // string
      if repr(e) in map_id_to_sym {
        let sym_sum_so_far = map_id_to_sym_sum.at(sym_id)  // number
        map_id_to_sym_sum.insert(sym_id, sym_sum_so_far + 1)
      } else {
        map_id_to_sym.insert(sym_id, sym)
        map_id_to_sym_sum.insert(sym_id, 1)
      }
    }
  }

  let expr_terms = ()  // array of Content object
  let sorted_sym_ids = map_id_to_sym.keys().sorted()
  for sym_id in sorted_sym_ids {
    let sym = map_id_to_sym.at(sym_id)
    let sym_sum = map_id_to_sym_sum.at(sym_id)  // number
    if sym_sum == 1 {
      expr_terms.push(sym)
    } else if sym_sum != 0 {
      expr_terms.push([#sym_sum #sym])
    }
  }
  if num_sum != 0 {
    expr_terms.push([#num_sum])  // make a Content object holding the number
  }

  return expr_terms.join([+])
}

// == Braces

#let Set(..sink) = style(styles => {
  let args = sink.pos()  // array
  let expr = if args.len() >= 1 { args.at(0) } else { none }
  let cond = if args.len() >= 2 { args.at(1) } else { none }
  let height = measure($ expr cond $, styles).height;
  let phantom = box(height: height, width: 0pt, inset: 0pt, stroke: none);

  if expr == none {
    if cond == none { ${}$ } else { ${lr(|phantom#h(0pt))#cond}$ }
  } else {
    if cond == none { ${#expr}$ } else { ${#expr lr(|phantom#h(0pt))#cond}$ }
  }
})

#let order(content) = $cal(O)(content)$

#let evaluated(content) = {
  $lr(zwj#content|)$
}
#let eval = evaluated

#let expectationvalue(f) = $lr(angle.l #f angle.r)$
#let expval = expectationvalue

// == Vector notations

#let vecrow(..content) = $lr(( #content.pos().join(",") ))$

#let TT = $sans(upright(T))$

#let vectorbold(a) = $bold(italic(#a))$
#let vb = vectorbold

#let __vectoraccent(a, accent) = {
  let bold_italic(e) = math.bold(math.italic(e))
  if type(a) == "content" and a.func() == math.attach {
    math.attach(
      math.accent(bold_italic(a.base), accent),
      t: if a.has("t") { math.bold(a.t) } else { none },
      b: if a.has("b") { math.bold(a.b) } else { none },
      tl: if a.has("tl") { math.bold(a.tl) } else { none },
      bl: if a.has("bl") { math.bold(a.bl) } else { none },
      tr: if a.has("tr") { math.bold(a.tr) } else { none },
      br: if a.has("br") { math.bold(a.br) } else { none },
    )
  } else {
    math.accent(bold_italic(a), accent)
  }
}
#let vectorarrow(a) = __vectoraccent(a, math.arrow)
#let va = vectorarrow

#let vectorunit(a) = __vectoraccent(a, math.hat)
#let vu = vectorunit

#let gradient = $bold(nabla)$
#let grad = gradient

#let divergence = $bold(nabla)dot.c$
#let div = divergence

#let curl = $bold(nabla)times$

#let laplacian = $nabla^2$

#let dotproduct = $dot$
#let dprod = dotproduct
#let crossproduct = $times$
#let cprod = crossproduct

// == Matrices

#let matrixdet(..sink) = {
  math.mat(..sink, delim:"|")
}
#let mdet = matrixdet

#let diagonalmatrix(..sink) = {
  let (args, kwargs) = (sink.pos(), sink.named())  // array, dictionary
  let delim = if "delim" in kwargs { kwargs.at("delim") } else { "(" }
  let fill = if "fill" in kwargs { kwargs.at("fill") } else { none }

  let arrays = ()  // array of arrays
  let n = args.len()
  for i in range(n) {
    let array = range(n).map((j) => {
      let e = if j == i { args.at(i) } else { fill }
      return e
    })
    arrays.push(array)
  }
  math.mat(delim: delim, ..arrays)
}
#let dmat = diagonalmatrix

#let antidiagonalmatrix(..sink) = {
  let (args, kwargs) = (sink.pos(), sink.named())  // array, dictionary
  let delim = if "delim" in kwargs { kwargs.at("delim") } else { "(" }
  let fill = if "fill" in kwargs { kwargs.at("fill") } else { none }

  let arrays = ()  // array of arrays
  let n = args.len()
  for i in range(n) {
    let array = range(n).map((j) => {
      let complement = n - 1 - i
      let e = if j == complement { args.at(i) } else { fill }
      return e
    })
    arrays.push(array)
  }
  math.mat(delim: delim, ..arrays)
}
#let admat = antidiagonalmatrix

#let identitymatrix(order, delim:"(", fill:none) = {
  let order_num = 1
  if type(order) == "content" and __content_holds_number(order) {
    order_num = int(order.text)
  } else {
    panic("the order shall be an integer, e.g. 2")
  }

  let ones = range(order_num).map((i) => 1)
  diagonalmatrix(..ones, delim: delim, fill: fill)
}
#let imat = identitymatrix

#let zeromatrix(order, delim:"(") = {
  let order_num = 1
  if type(order) == "content" and __content_holds_number(order) {
    order_num = int(order.text)
  } else {
    panic("the order shall be an integer, e.g. 2")
  }

  let ones = range(order_num).map((i) => 0)
  diagonalmatrix(..ones, delim: delim, fill: 0)
}
#let zmat = zeromatrix

#let jacobianmatrix(fs, xs, delim:"(") = {
  assert(type(fs) == "array", message: "expecting an array of function names")
  assert(type(xs) == "array", message: "expecting an array of variable names")
  let arrays = ()  // array of arrays
  for f in fs {
    arrays.push(xs.map((x) => math.frac($diff#f$, $diff#x$)))
  }
  math.mat(delim: delim, ..arrays)
}
#let jmat = jacobianmatrix

#let hessianmatrix(fs, xs, delim:"(") = {
  assert(type(fs) == "array", message: "expecting a one-element array")
  assert(fs.len() == 1, message: "expecting only one function name")
  let f = fs.at(0)
  assert(type(xs) == "array", message: "expecting an array of variable names")
  let row_arrays = ()  // array of arrays
  let order = xs.len()
  for r in range(order) {
    let row_array = ()  // array
    let xr = xs.at(r)
    for c in range(order) {
      let xc = xs.at(c)
      row_array.push(math.frac(
        $diff^#order #f$,
        if xr == xc { $diff #xr^2$ } else { $diff #xr diff #xc$ }
      ))
    }
    row_arrays.push(row_array)
  }
  math.mat(delim: delim, ..row_arrays)
}
#let hmat = hessianmatrix

#let xmatrix(m, n, func, delim:"(") = {
  let rows = none
  if type(m) == "content" and __content_holds_number(m) {
    rows = int(m.text)
  } else {
    panic("the first argument shall be an integer, e.g. 2")
  }
  let cols = none
  if type(n) == "content" and __content_holds_number(m) {
    cols = int(n.text)
  } else {
    panic("the second argument shall be an integer, e.g. 2")
  }
  assert(
    type(func) == "function",
    message: "func shall be a function (did you forget to add a preceding '#' before the function name)?"
  )
  let row_arrays = ()  // array of arrays
  for i in range(1, rows + 1) {
    let row_array = ()  // array
    for j in range(1, cols + 1) {
      row_array.push(func(i, j))
    }
    row_arrays.push(row_array)
  }
  math.mat(delim: delim, ..row_arrays)
}
#let xmat = xmatrix

// == Dirac braket notations

#let bra(f) = $lr(angle.l #f|)$
#let ket(f) = $lr(|#f angle.r)$

// Credit: thanks to peng1999@ and szdytom@'s suggestions of measure() and
// phantoms. The hack works until https://github.com/typst/typst/issues/240 is
// addressed by Typst.
#let braket(..sink) = style(styles => {
  let args = sink.pos()  // array
  assert(args.len() == 1 or args.len() == 2, message: "expecting 1 or 2 args")

  let bra = args.at(0)
  let ket = if args.len() >= 2 { args.at(1) } else { bra }

  let height = measure($ bra ket $, styles).height;
  let phantom = box(height: height, width: 0pt, inset: 0pt, stroke: none);
  $ lr(angle.l bra lr(|phantom#h(0pt)) ket angle.r) $
})

// Credit: until https://github.com/typst/typst/issues/240 is addressed by Typst
// we use the same hack as braket().
#let ketbra(..sink) = style(styles => {
  let args = sink.pos()  // array
  assert(args.len() == 1 or args.len() == 2, message: "expecting 1 or 2 args")

  let bra = args.at(0)
  let ket = if args.len() >= 2 { args.at(1) } else { bra }

  let height = measure($ bra ket $, styles).height;
  let phantom = box(height: height, width: 0pt, inset: 0pt, stroke: none);
  $ lr(|bra#h(0pt)phantom angle.r)lr(angle.l phantom#h(0pt)ket|) $
})

#let innerproduct = braket
#let iprod = innerproduct
#let outerproduct = ketbra
#let oprod = outerproduct

// Credit: until https://github.com/typst/typst/issues/240 is addressed by Typst
// we use the same hack as braket().
#let matrixelement(n, M, m) = style(styles => {
  let height = measure($ #n #M #m $, styles).height;
  let phantom = box(height: height, width: 0pt, inset: 0pt, stroke: none);
  $ lr(angle.l #n |#M#h(0pt)phantom| #m angle.r) $
})

#let mel = matrixelement

// == Math functions

#let sin = math.op("sin")
#let sinh = math.op("sinh")
#let arcsin = math.op("arcsin")
#let asin = math.op("asin")

#let cos = math.op("cos")
#let cosh = math.op("cosh")
#let arccos = math.op("arccos")
#let acos = math.op("acos")

#let tan = math.op("tan")
#let tanh = math.op("tanh")
#let arctan = math.op("arctan")
#let atan = math.op("atan")

#let sec = math.op("sec")
#let sech = math.op("sech")
#let arcsec = math.op("arcsec")
#let asec = math.op("asec")

#let csc = math.op("csc")
#let csch = math.op("csch")
#let arccsc = math.op("arccsc")
#let acsc = math.op("acsc")

#let cot = math.op("cot")
#let coth = math.op("coth")
#let arccot = math.op("arccot")
#let acot = math.op("acot")

#let diag = math.op("diag")

#let trace = math.op("trace")
#let tr = math.op("tr")
#let Trace = math.op("Trace")
#let Tr = math.op("Tr")

#let rank = math.op("rank")
#let erf = math.op("erf")
#let Res = math.op("Res")

#let Re = math.op("Re")
#let Im = math.op("Im")

#let sgn = $op("sgn")$

// == Differentials

#let differential(..sink) = {
  let (args, kwargs) = (sink.pos(), sink.named())  // array, dictionary

  let orders = ()
  let var_num = args.len()
  let default_order = [1]  // a Content holding "1"
  let last = args.at(args.len() - 1)
  if type(last) == "content" {
    if last.func() == math.lr and last.at("body").at("children").at(0) == [\[] {
      var_num -= 1
      orders = __extract_array_contents(last)  // array
    } else if __content_holds_number(last) {
      var_num -= 1
      default_order = last  // treat as a single element
      orders.push(default_order)
    }
  } else if type(last) == "integer" {
    var_num -= 1
    default_order = [#last]  // make it a Content
    orders.push(default_order)
  }

  let dsym = if "d" in kwargs {
    kwargs.at("d")
  } else {
    $upright(d)$
  }

  let prod = if "p" in kwargs {
    kwargs.at("p")
  } else {
    none
  }

  let difference = var_num - orders.len()
  while difference > 0 {
    orders.push(default_order)
    difference -= 1
  }

  let arr = ()
  for i in range(var_num) {
    let (var, order) = (args.at(i), orders.at(i))
    if order != [1] {
      arr.push($dsym^#order#var$)
    } else {
      arr.push($dsym#var$)
    }
  }
  $#arr.join(prod)$
}
#let dd = differential

#let variation = dd.with(d: sym.delta)
#let var = variation

// Do not name it "delta", because it will collide with "delta" in math
// expressions (note in math mode "sym.delta" can be written as "delta").
#let difference = dd.with(d: sym.Delta)

#let __combine_var_order(var, order) = {
  let naive_result = math.attach(var, t: order)
  if type(var) != "content" or var.func() != math.attach {
    return naive_result
  }

  if var.has("b") and (not var.has("t")) {
    // Place the order superscript directly above the subscript, as is
    // the custom is most papers.
    return math.attach(var.base, t: order, b: var.b)
  }

  // Even if var.has("t") is true, we don't take any special action. Let
  // user decide. Say, if they want to wrap var in a "(..)", let they do it.
  return naive_result
}

#let derivative(f, ..sink) = {
  if f == [] { f = none }  // Convert empty content to none

  let (args, kwargs) = (sink.pos(), sink.named())  // array, dictionary
  assert(args.len() > 0, message: "variable name expected")

  let d = if "d" in kwargs { kwargs.at("d") } else { $upright(d)$ }
  let slash = if "s" in kwargs { kwargs.at("s") } else { none }

  let var = args.at(0)
  assert(args.len() >= 1, message: "expecting at least one argument")

  let display(num, denom, slash) = {
    if slash == none {
      $#num/#denom$
    } else {
      let sep = (sym.zwj, slash, sym.zwj).join()
      $#num#sep#denom$
    }
  }

  if args.len() >= 2 {  // i.e. specified the order
    let order = args.at(1)  // Not necessarily representing a number
    let upper = if f == none { $#d^#order$ } else { $#d^#order#f$ }
    let varorder = __combine_var_order(var, order)
    display(upper, $#d#varorder$, slash)
  } else {  // i.e. no order specified
    let upper = if f == none { $#d$ } else { $#d#f$ }
    display(upper, $#d#var$, slash)
  }
}
#let dv = derivative

#let partialderivative(..sink) = {
  let (args, kwargs) = (sink.pos(), sink.named())  // array, dictionary
  assert(args.len() >= 2, message: "expecting one function name and at least one variable name")

  let f = args.at(0)
  if f == [] { f = none }  // Convert empty content to none
  let var_num = args.len() - 1
  let orders = ()
  let default_order = [1]  // a Content holding "1"

  // The last argument might be the order numbers, let's check.
  let last = args.at(args.len() - 1)
  if type(last) == "content" {
    if last.func() == math.lr and last.at("body").at("children").at(0) == [\[] {
      var_num -= 1
      orders = __extract_array_contents(last)  // array
    } else if  __content_holds_number(last) {
      var_num -= 1
      default_order = last
      orders.push(default_order)
    }
  } else if type(last) == "integer" {
    var_num -= 1
    default_order = [#last]  // make it a Content
    orders.push(default_order)
  }

  let difference = var_num - orders.len()
  while difference > 0 {
    orders.push(default_order)
    difference -= 1
  }

  let total_order = none  // any type, could be a number
  if "total" in kwargs {
    total_order = kwargs.at("total")
  } else {
    total_order = __bare_minimum_effort_symbolic_add(orders)
  }

  let lowers = ()
  for i in range(var_num) {
    let var = args.at(1 + i)  // 1st element is the function name, skip
    let order = orders.at(i)
    if order == [1] {
      lowers.push($diff#var$)
    } else {
      let varorder = __combine_var_order(var, order)
      lowers.push($diff#varorder$)
    }
  }

  let upper = if total_order != 1 and total_order != [1] {  // number or Content
    if f == none { $diff^#total_order$ } else { $diff^#total_order#f$ }
  } else {
    if f == none { $diff$ } else { $diff #f$ }
  }

  let display(num, denom, slash) = {
    if slash == none {
      math.frac(num, denom)
    } else {
      let sep = (sym.zwj, slash, sym.zwj).join()
      $#num#sep#denom$
    }
  }

  let slash = if "s" in kwargs { kwargs.at("s") } else { none }
  display(upper, lowers.join(), slash)
}
#let pdv = partialderivative

// == Miscellaneous

// With the default font, the original symbol `planck.reduce` has a slash on the
// letter "h", and it is different from the usual "hbar" symbol, which has a
// horizontal bar on the letter "h".
//
// Here, we manually create a "hbar" symbol by adding the font-independent
// horizontal bar produced by strike() to the current font's Planck symbol, so
// that the new "hbar" symbol and the existing Planck symbol look similar in any
// font (not just "New Computer Modern").
//
// However, strike() causes some side effects in math mode: it shifts the symbol
// downward. This seems like a Typst bug. Therefore, we need to use move() to
// eliminate those side effects so that the symbol behave nicely in math
// expressions.
//
// We also need to use wj (word joiner) to eliminate the unwanted horizontal
// spaces that manifests when using the symbol in math mode.
//
// Credit: Enivex in https://github.com/typst/typst/issues/355 was very helpful.
#let hbar = (sym.wj, move(dy: -0.08em, strike(offset: -0.55em, extent: -0.05em, sym.planck)), sym.wj).join()

#let tensor(T, ..sink) = {
  let args = sink.pos()

  let (uppers, lowers) = ((), ())  // array, array
  let hphantom(s) = { hide(box(height: 0em, s)) }  // Like Latex's \hphantom

  for i in range(args.len()) {
    let arg = args.at(i)
    let tuple = if arg.has("children") == true {
      arg.at("children")
    } else {
      ([+], sym.square)
    }
    assert(type(tuple) == "array", message: "shall be array")

    let pos = tuple.at(0)
    let symbol = if tuple.len() >= 2 {
      tuple.slice(1).join()
    } else {
      sym.square
    }
    if pos == [+] {
      let rendering = $#symbol$
      uppers.push(rendering)
      lowers.push(hphantom(rendering))
    } else {  // Curiously, equality with [-] is always false, so we don't do it
      let rendering = $#symbol$
      uppers.push(hphantom(rendering))
      lowers.push(rendering)
    }
  }

  // Do not use "...^..._...", because the lower indices appear to be placed
  // slightly lower than a normal subscript.
  // Use a phantom with zwj (zero-width word joiner) to vertically align the
  // starting points of the upper and lower indices. Also, we put T inside
  // the first argument of attach(), so that the indices' vertical position
  // auto-adjusts with T's height.
  math.attach((T,hphantom(sym.zwj)).join(), t: uppers.join(), b: lowers.join())
}

#let isotope(element, /*atomic mass*/a: none, /*atomic number*/z: none) = {
  $attach(upright(element), tl: #a, bl: #z)$
}

#let __signal_element(e, W, color) = {
  let style = 0.5pt + color
  if e == "&" {
    return rect(width: W, height: 1em, stroke: none)
  } else if e == "n" {
    return rect(width: 1em, height: W, stroke: (left: style, top: style, right: style))
  } else if e == "u" {
    return rect(width: W, height: 1em, stroke: (left: style, bottom: style, right: style))
  } else if (e == "H" or e == "1") {
    return rect(width: W, height: 1em, stroke: (top: style))
  } else if e == "h" {
    return rect(width: W * 50%, height: 1em, stroke: (top: style))
  } else if e == "^" {
    return rect(width: W * 10%, height: 1em, stroke: (top: style))
  } else if (e == "M" or e == "-") {
    return line(start: (0em, 0.5em), end: (W, 0.5em), stroke: style)
  } else if e == "m" {
    return line(start: (0em, 0.5em), end: (W * 0.5, 0.5em), stroke: style)
  } else if (e == "L" or e == "0") {
    return rect(width: W, height: 1em, stroke: (bottom: style))
  } else if e == "l" {
    return rect(width: W * 50%, height: 1em, stroke: (bottom: style))
  } else if e == "v" {
    return rect(width: W * 10%, height: 1em, stroke: (bottom: style))
  } else if e == "=" {
    return rect(width: W, height: 1em, stroke: (top: style, bottom: style))
  } else if e == "#" {
    return path(stroke: style, closed: false,
      (0em, 0em), (W * 50%, 0em), (0em, 1em), (W, 1em),
      (W * 50%, 1em), (W, 0em), (W * 50%, 0em),
    )
  } else if e == "|" {
    return line(start: (0em, 0em), end: (0em, 1em), stroke: style)
  } else if e == "'" {
    return line(start: (0em, 0em), end: (0em, 0.5em), stroke: style)
  } else if e == "," {
    return line(start: (0em, 0.5em), end: (0em, 1em), stroke: style)
  } else if e == "R" {
    return line(start: (0em, 1em), end: (W, 0em), stroke: style)
  } else if e == "F" {
    return line(start: (0em, 0em), end: (W, 1em), stroke: style)
  } else if e == "<" {
    return path(stroke: style, closed: false, (W, 0em), (0em, 0.5em), (W, 1em))
  } else if e == ">" {
    return path(stroke: style, closed: false, (0em, 0em), (W, 0.5em), (0em, 1em))
  } else if e == "C" {
    return path(stroke: style, closed: false, (0em, 1em), ((W, 0em), (-W * 75%, 0.05em)))
  } else if e == "c" {
    return path(stroke: style, closed: false, (0em, 1em), ((W * 50%, 0em), (-W * 38%, 0.05em)))
  } else if e == "D" {
    return path(stroke: style, closed: false, (0em, 0em), ((W, 1em), (-W * 75%, -0.05em)))
  } else if e == "d" {
    return path(stroke: style, closed: false, (0em, 0em), ((W * 50%, 1em), (-W * 38%, -0.05em)))
  } else if e == "X" {
    return path(stroke: style, closed: false,
      (0em, 0em), (W * 50%, 0.5em), (0em, 1em),
      (W, 0em), (W * 50%, 0.5em), (W, 1em),
    )
  } else {
    return "[" + e + "]"
  }
}

#let signals(str, step: 1em, color: black) = {
  assert(type(str) == "string", message: "input needs to be a string")

  let elements = ()  // array
  let previous = " "
  for e in str {
    if e == " " { continue; }
    if e == "." {
      elements.push(__signal_element(previous, step, color))
    } else {
      elements.push(__signal_element(e, step, color))
      previous = e
    }
  }

  grid(
    columns: (auto,) * elements.len(),
    column-gutter: 0em,
    ..elements,
  )
}

#let BMEsymadd(content) = {
  let elements = __extract_array_contents(content)
  __bare_minimum_effort_symbolic_add(elements)
}

// Add symbol definitions to the corresponding sections. Do not simply append
// them at the end of file.
