{
  const names = {}
  let lastVar = 0
  function normalize(from) {
    if (!(from in names)) {
      const escaped = from.replace(/[^A-Za-z0-9_]/g, '_')
      names[from] = `_${escaped}_${lastVar++}_`
    }
    return names[from]
  }
  const macros = {}
}

Script
  = __ Guayabo
   body:(_ e:(Query / Macro) {return e})*
  __
  { return `// GENERATED C PROGRAM\n${body.filter(Boolean).map(e => `${e};\n`).join('')}` }

Guayabo = p:Pragma _ "manoguayabo"

Macro "Macro definition"
  = MACRO _ name:Name src:$(!END .)* END
  {
    macros[name] = eval(src)
    return null
  }

Pragma
  = PRAGMA

Query
  = Value
  / Insert
  / Call
  / Function
  / Row
  / Return
  / OpenMod

Expr
  = '(' __ e:Query __ ')' { return e }
  / Literal
  / FromExpr
  

OpenMod
  = OPEN _ MODULE _ name:StringLiteral
  { return `#include <${name.slice(1, -1)}>` }

ExprList
  = '()' { return '' }
  / e:Expr t:(__ ',' __ x:Expr {return x})*
  { return [e, ...t].join(', ') }

Value
  = VALUE _ target:TypeName _ AS _ names:NameList
  { return `${target} ${names}` }

Insert
  = INSERT __ expr:Expr __ INTO _ target:FromExpr
  { return `${target} = ${expr}` }
  
Call
  = CALL _ target:FromExpr _ WITH __ args:ExprList
  {
    if (target in macros) {
      return macros[target](...args)
    }
    return `${target}(${args})`
  }
  
Function
  = DECLARE _ FUNCTION _ name:Name
  args:(_ WITH _ e:TypeList {return e})?
  rType:(_ RETURNS _ n:TypeName {return n})?
  _ THEN __ body:(Expr / '(' o:(_ q:Query {return q})* __')' {return o})
  {
    if (!(body instanceof Array)) { body = [body] }
    return `${rType} ${name}() {\n${body?.map(e => `  ${e};\n`).join('')}}`
  }
  
Row
  = DECLARE _ ROW _ name:TypeName _ WITH
  __ '(' __ types:(t:TypeList __ {return t})?  ')'
  { return `struct ${name} { ${types?.map((t, i) => `${t} _${i};`).join('')} } typedef ${name}` }

Return
  = RETURN _ expr:Expr
  { return `return ${expr}` }

// Terminals
NameList
  = e:Name t:(__ ',' __ n:Name {return n})*
  { return [e, ...t] }

TypeList
  = e:TypeName t:(__ ',' __ n:TypeName {return n})*
  { return [e, ...t] }

TypeName
  = p:AT? name:Name
  // Future use
  // generic:('{' t:TypeList '}' {return t})?
  { return `${name}${p ? '*' : ''}` }

FromExpr
  = head:Name
    tail:(_ op:(FROM / IN) _ name:Name {return {name, op} })*
  { return tail.reduce((r, curr) => {
    const op = curr.op == 'in' ? '->' : '.'
    return `${r}${curr.name}${op}`
  }, head) }

Name
  = value:$([_A-Za-z][_A-Za-z0-9]*) { return value }
  / '`' value:$(!'`' .)* '`' { return normalize(value) }
  / DollarExpr

DollarExpr
  = '$' val:$([0-9]+)
  { return Number(val) }

Literal
  = StringLiteral
  / NumberLiteral

StringLiteral
  = '"' value:$(!'"' .)* '"'
  { return `"${value}"` }

NumberLiteral
  = value:$([0-9]+ ('.' [0-9]+)? ('L'i / 'f'i)?)
  { return value }

// Tokens
PRAGMA = '#pragma'
MACRO = '#macro'
END = '#end'
VALUE = 'value'i
SELECT = 'select'i
FROM = 'from'i
IN = 'in'i
AS = 'as'i
INSERT = 'insert'i
INTO = 'into'i
CALL = 'call'i
WITH = 'with'i
THEN = 'then'i
DECLARE = 'declare'i
FUNCTION = 'function'i
ROW = 'row'i
RETURNS = 'returns'i
RETURN = 'return'i
OPEN = 'open'i
MODULE = 'module'i
AT = '@'

Comment "Comment"
  = '--' e:$((![\n\r] .)*) &[\n\r]+
  { return { type: 'comment', value: e.trim() } }

WS "White space" = [ \t\n\r]
__ = (Comment / WS)*
_ = (Comment / WS)+
